# Capybara Beta — Build Contract

This document is the single source of truth for the beta implementation. Every
workstream must code against these interfaces. Do not rename shared types or
functions without updating this file first.

## Mission

`capy` is the front door to the Rey toolchain. The beta bundles a pinned Rey
release (compiler, runtime and standard library) and provides:

```
capy init
capy run
capy build
capy check
capy test
capy clean
capy doctor
capy install
capy update
```

It also ships an autoupdater (`capy update --self`) and packaging for Homebrew
and npm (`@capybara/cli`).

## Hard constraints for this build phase

- Write Rey source only in `src/`.
- Do not run `rey`, do not compile, do not run tests, do not run `capy`.
- Do not run `git add` or `git commit`.
- Do not edit files owned by another workstream.
- Keep the code conservative: no closures, no generics, no async, no threads.
- Every statement ends with `;`.
- Prefer explicit local types. The compiler's type checker is a stub, so
  annotations are documentation but also help the code generator.
- Use `loop { ... break; }` rather than `while true`.
- Use `HashMap.delete(key)`; there is no `remove`.
- `pub const` is not supported. Expose constants as functions.

## Repository layout

```
capybara/
├── capy.toml                  # capy's own project manifest
├── src/
│   ├── main.rey               # entry point
│   └── capy/
│       ├── app.rey            # context + dispatch
│       ├── types.rey          # shared structs
│       ├── version.rey        # version/url constants
│       ├── output.rey         # info/success/warn/error
│       ├── util.rey           # paths, shell quoting, process helpers
│       ├── manifest.rey       # capy.toml + capy.lock
│       ├── project.rey        # project root + paths
│       ├── toolchain.rey      # bundled rey discovery/invocation
│       ├── installer.rey      # ~/.rey -> ~/.capy migration + links
│       ├── deps.rey           # package registry + vendoring
│       └── commands/
│           ├── init.rey
│           ├── run.rey
│           ├── build.rey
│           ├── check.rey
│           ├── test.rey
│           ├── clean.rey
│           ├── doctor.rey
│           ├── install.rey
│           ├── update.rey
│           ├── self_update.rey
│           └── target.rey      # run/build/check target resolution
├── docs/
├── packaging/
├── scripts/
└── .github/workflows/
```

## Shared types — `src/capy/types.rey`

```rey
pub struct ExecResult {
    pub code: int,
    pub stdout: string,
    pub stderr: string,
}

pub struct Toolchain {
    pub found: bool,
    pub root: string,      // e.g. ~/.capy/toolchains/0.3.1
    pub rey: string,       // <root>/bin/rey
    pub runtime: string,   // <root>/bin/runtime
    pub std: string,       // <root>/std/src
    pub version: string,
    pub error: string,
}

pub struct Manifest {
    pub found: bool,
    pub path: string,
    pub root: string,
    pub name: string,
    pub version: string,
    pub entry: string,     // default "src/main.rey"
    pub error: string,
    pub dependencies: HashMap<string, string>,
}

pub struct Context {
    pub cwd: string,
    pub home: string,
    pub capyHome: string,
    pub exePath: string,
    pub exeDir: string,
    pub verbose: bool,

    // Flattened toolchain fields to avoid nested-struct codegen risk.
    pub tcFound: bool,
    pub tcRoot: string,
    pub tcRey: string,
    pub tcRuntime: string,
    pub tcStd: string,
    pub tcVersion: string,
    pub tcError: string,
}
```

Constructors (all fields must be set):

```rey
pub func emptyExec(): ExecResult
pub func emptyManifest(): Manifest
pub func emptyToolchain(): Toolchain
pub func emptyContext(): Context
```

## Version — `src/capy/version.rey`

```rey
pub func capyVersion(): string        // "0.1.1"
pub func reyVersion(): string         // "0.3.1"
pub func registryUrl(): string        // https://github.com/rey-language/packages.git
pub func registryRepo(): string       // rey-language/packages
pub func updateManifestUrl(): string  // github.com/.../releases/latest/download/latest.toml
pub func releasesBase(): string       // https://github.com/rey-language/capybara/releases/download
```

## Output — `src/capy/output.rey`

```rey
pub func info(msg: string): void      // "==> msg"
pub func success(msg: string): void   // "✓ msg"
pub func warn(msg: string): void      // "warning: msg" to stderr
pub func error(msg: string): void     // "error: msg" to stderr
pub func plain(msg: string): void
pub func verbose(ctx: Context, msg: string): void
```

No color codes in the beta. Respect `NO_COLOR` by doing nothing.

## Util — `src/capy/util.rey`

```rey
pub func shellQuote(s: string): string
pub func join(a: string, b: string): string
pub func exists(path: string): bool
pub func isDir(path: string): bool
pub func isFile(path: string): bool
pub func mkdirAll(path: string): void
pub func removeAll(path: string): void
pub func read(path: string): string
pub func write(path: string, content: string): void
pub func copy(src: string, dst: string): void
pub func copyDir(src: string, dst: string): void
pub func list(path: string): Vec<string>
pub func listRecursive(path: string): Vec<string>
pub func basename(path: string): string
pub func dirname(path: string): string
pub func extname(path: string): string
pub func isAbsolute(path: string): bool
pub func absolute(path: string, base: string): string
pub func envOr(key: string, fallback: string): string
pub func runShell(cmd: string): ExecResult
pub func runArgs(program: string, args: Vec<string>): ExecResult
pub func runArgsIn(program: string, args: Vec<string>, cwd: string): ExecResult
pub func splitAtDoubleDash(args: Vec<string>): Vec<Vec<string>>
pub func splitOnce(s: string, sep: string): Vec<string>
pub func contains(s: string, sub: string): bool
pub func startsWith(s: string, prefix: string): bool
pub func joinList(items: Vec<string>, sep: string): string
pub func trimSlash(s: string): string
pub func isEmptyDir(path: string): bool
pub func nowSeconds(): int
```

`runArgs` builds a POSIX shell command with `shellQuote` and calls
`process.runDetailed`. The returned object has `.code`, `.stdout`, `.stderr`.
`splitAtDoubleDash` returns `[before, after]`; if no `--`, `after` is empty.

## Manifest — `src/capy/manifest.rey`

`capy.toml` format:

```toml
[package]
name = "my-app"
version = "0.1.0"
entry = "src/main.rey"

[dependencies]
rey-postgres = "0.1.0"
```

```rey
pub func load(path: string): Manifest
pub func loadAt(root: string): Manifest
pub func write(path: string, name: string, version: string, deps: HashMap<string, string>): void
pub func addDependency(m: Manifest, name: string, spec: string): Manifest
pub func removeDependency(m: Manifest, name: string): Manifest
pub func defaultToml(name: string): string
```

- `loadAt` reads `<root>/capy.toml`.
- Missing file => `found=false`, `error` set, all other fields empty.
- Missing `package.name` => fall back to basename of root.
- Missing `package.version` => `"0.1.0"`.
- Missing `package.entry` => `"src/main.rey"`.
- `write` emits the exact format above, with dependencies sorted by name.
- Use `std::toml::parse` for reading. Write a custom serializer; do not use
  `std::toml::stringify` because it loses sections.

Lockfile — `<project>/capy.lock`:

```toml
[rey-postgres]
version = "0.1.0"
commit = "0123456789abcdef"
source = "rey-language/packages"
```

```rey
pub func lockLoad(root: string): HashMap<string, string>   // keys: "name.version", "name.commit", "name.source"
pub func lockWrite(root: string, m: Manifest, versions: HashMap<string, string>, commits: HashMap<string, string>): void
pub func lockRemove(root: string, name: string): void
```

## Project — `src/capy/project.rey`

```rey
pub func findRoot(start: string): string        // "" when not inside a project
pub func entryPath(m: Manifest): string         // absolute
pub func buildDir(root: string): string         // <root>/build
pub func buildPath(root: string, name: string): string
pub func vendorDir(root: string): string        // <root>/vendor
pub func testsDirs(root: string): Vec<string>   // src, tests (that exist)
pub func projectName(root: string): string      // basename
```

`findRoot` walks upward from `start` until it finds `capy.toml` or reaches `/`.

## Toolchain — `src/capy/toolchain.rey`

```rey
pub func resolve(ctx: Context): Toolchain
pub func require(tc: Toolchain): bool          // prints a clear error when not found
pub func version(tc: Toolchain): string
pub func build(tc: Toolchain, entry: string, output: string): ExecResult
pub func check(tc: Toolchain, entry: string): ExecResult
pub func runScript(tc: Toolchain, entry: string, args: Vec<string>): ExecResult
pub func setEnvFor(tc: Toolchain, ctx: Context): void
```

Discovery order (first valid wins):

1. `$CAPY_TOOLCHAIN` (a directory containing `bin/rey` and `std/src`)
2. `<exeDir>/../libexec/toolchain` (Homebrew/npm/portable layout)
3. `<exeDir>/../vendor/toolchain` (development build)
4. `<exeDir>/toolchain`
5. `~/.capy/toolchains/current` (symlink)
6. `~/.capy/toolchains/<REY_VERSION>`
7. `rey` on `PATH`; derive root from the binary, std from `$REY_STD_PATH` or
   `~/.reyc/std/src`

A valid toolchain has `bin/rey`, `bin/runtime/librey_rt.a`, and `std/src`.

Before invoking rey, set:

```
REY_HOME=<toolchain root>
REY_STD_PATH=<toolchain std>
REY_RUNTIME_DIR=<toolchain runtime>
CAPY_HOME=<ctx.capyHome>
```

Invoke `rey` with absolute paths. The compiler derives its project root from
`/src/` in the entry path, so relative paths can resolve imports incorrectly.

`build` calls:

```
rey build <absolute entry> -o <absolute output> --runtime-dir <runtime>
```

`check` calls `rey check <absolute entry>`.

`runScript` calls `rey run <absolute entry> -- <args...>`.

## App — `src/capy/app.rey`

```rey
pub func makeContext(argv: Vec<string>): Context
pub func execute(argv: Vec<string>): int
pub func usage(): string
pub func versionLine(): string
```

`makeContext`:

1. Resolve `cwd`, `HOME`, `CAPY_HOME` (default `~/.capy`), executable path/dir.
2. Call `installer.ensureHome(ctx)`.
3. Resolve the toolchain and copy its fields into the context.
4. Call `installer.ensureStdLink(ctx)`.
5. Return the context.

`execute` parses global flags (`--verbose`, `-v`), dispatches the command to
`<command>.execute(ctx, rest)`, and returns its exit code.

No command: print usage, return 0.
`help`/`--help`/`-h`: print usage (or command help), return 0.
`version`/`--version`/`-V`: print `capy <version> (rey <version>)`, return 0.
Unknown: error + `capy help`, return 1.

Every command module exports:

```rey
pub func execute(ctx: Context, args: Vec<string>): int
```

## Commands

### `init`

`capy init [--name <name>] [--force]`

- Refuse if `capy.toml` exists unless `--force`.
- Name from `--name`, else basename of cwd.
- Create `src/`, `capy.toml`, `src/main.rey`, `.gitignore`.
- Never overwrite an existing `src/main.rey`; error unless `--force`, and even
  then back it up to `src/main.rey.bak`.
- Do not run `git init`.
- Print next steps: `capy run`, `capy build`.

`src/main.rey`:

```rey
func main(): void {
    println("Hello from Capybara!");
}
```

`.gitignore`: `build/`, `vendor/`, `.capy/`, `*.tar.gz`, `.DS_Store`.

### `run`

`capy run [file.rey] [-- args...]`

- Split at `--`.
- If the first positional ends in `.rey`, run that file ad hoc.
- Otherwise use the project entry from `capy.toml`.
- Project mode: ensure `build/`, build to `build/<name>`, then execute the
  output with program args. Do not use `rey run` for project mode; the spec
  wants the binary at `build/<name>`.
- Ad-hoc mode: `rey run <file> -- args`.
- `--release` is accepted but emits a warning: the bundled compiler always
  optimizes; release/target flags are not supported in the beta.
- Return the child exit code.

### `build`

`capy build [file.rey] [-o|--output <path>] [--release]`

- Project mode default output `build/<name>`.
- File mode default output `build/<basename without .rey>`.
- Create parent directory.
- `--release` warns (see above). `--target` is an error.
- On success print `Built <path>`.
- Return compiler exit code.

### `check`

`capy check [file.rey]`

- Project or file mode.
- Only parser/typechecker; no output binary.
- Print `ok` on success.

### `test`

`capy test [--filter <substr>] [--list]`

- Discover `*_test.rey` under `src/` and `tests/`.
- Skip `vendor/`, `build/`, `.capy/`, `node_modules/`.
- For each: build to `build/tests/<name>` then execute.
- Print `ok <path>` or `FAIL <path>` plus captured stderr.
- `--list` only prints discovered paths.
- `--filter` substring match on the path.
- Summary: `N passed, M failed`.
- No tests => `no tests found`, return 0.
- Sequential only.

### `clean`

`capy clean [--all]`

- Remove `<root>/build`.
- `--all` also removes `<root>/vendor` and `<root>/capy.lock`.
- Never remove `~/.capy`.

### `doctor`

`capy doctor [--online]`

Checks and prints:

- capy version
- project root and manifest (if inside a project)
- toolchain root, rey version
- std path exists
- runtime `librey_rt.a` exists
- `clang`, `git`, `curl`, `tar`, `shasum` on PATH
- `~/.capy` writable
- `~/.reyc/std` points to a std directory
- `which capy` resolves inside `~/.capy/bin` or the current executable
- with `--online`: latest capy version

Return 1 if any critical check fails (toolchain, rey, std, runtime), else 0.

### `install`

`capy install [pkg[@version]] [--locked] [--force] [--offline] [--registry <url|path>]`

- No manifest => error.
- No positional: install all dependencies from `capy.toml`.
- With positional: add/update the dependency in `capy.toml`, then install.
- Registry cache: `~/.capy/registry/packages`.
  - Default URL from `version.registryUrl()`.
  - Clone with `git clone --depth 1` if missing.
  - `git -C <cache> pull --ff-only` unless `--offline` or `--locked`.
- Package layout in the registry:

```
packages/<name>/capy.toml
packages/<name>/src/...
```

- Vendor into `<project>/vendor/<name>/`:
  - copy the contents of `packages/<name>/src/` to `vendor/<name>/`
    (flatten so `main.rey` sits at the vendor root)
  - copy `packages/<name>/capy.toml` to `vendor/<name>/capy.toml`
- Import convention for the beta is `import vendor::<name>`.
- Version match: exact string, or `*`/empty for any.
- Write `capy.lock` with version, registry commit, source.
- `--locked`: verify lock exists and satisfies every dependency; do not update.
- `--force`: re-copy even if `vendor/<name>` exists.
- Print installed packages and the import line.

### `update`

`capy update [pkg] [--self] [--check] [--offline]`

- Default: update registry cache, re-resolve dependencies, reinstall, update lock.
- `pkg`: only update that package (still re-reads manifest).
- `--self`: call `self_update.perform(ctx)`.
- `--check`: call `self_update.check(ctx)`.
- `--offline`: do not hit the network.

### `self_update`

```rey
pub func check(ctx: Context): int
pub func perform(ctx: Context): int
pub func maybeNotify(ctx: Context): void
```

Update manifest (`release/latest.toml` in the capybara repo):

```toml
version = "0.1.1"
darwin-arm64 = "https://.../capy-v0.1.1-darwin-arm64.tar.gz"
darwin-arm64-sha256 = "..."
darwin-x86_64 = "..."
darwin-x86_64-sha256 = "..."
linux-x86_64 = "..."
linux-x86_64-sha256 = "..."
linux-aarch64 = "..."
linux-aarch64-sha256 = "..."
```

- `check` uses `curl -fsSL --max-time 4` and prints current/latest.
- `perform`:
  - Detect install channel:
    - path contains `/Cellar/` or `/homebrew/` => tell the user to run
      `brew upgrade capy`; return 1.
    - path contains `node_modules` => tell the user to run
      `npm i -g @capybara/cli@latest`; return 1.
  - Download to `~/.capy/cache/`, verify sha256 with `shasum -a 256`.
  - Extract with `tar -xzf`.
  - Replace the running binary atomically: copy to a temp path beside the
    current binary, `mv` over the current path.
  - If the archive contains `libexec/toolchain`, install it under
    `~/.capy/toolchains/<version>`, repoint `~/.capy/toolchains/current`,
    refresh `~/.capy/libexec/toolchain`, and repoint `~/.reyc/std`.
- `maybeNotify`: no-op unless `CAPY_UPDATE_CHECK=1`. When enabled, use a cache
  file `~/.capy/cache/update-check` and check at most once per 24h. Never fail
  the command because of an update check.

## Installer — `src/capy/installer.rey`

```rey
pub func ensureHome(ctx: Context): void
pub func ensureStdLink(ctx: Context): void
pub func ensureBinLinks(ctx: Context): void
pub func migrateReyHome(ctx: Context): void
```

`ensureHome`:

- If `~/.capy` does not exist and `~/.rey` does: move `~/.rey` to `~/.capy`.
  Then create a compatibility symlink `~/.rey -> ~/.capy` and a marker
  `~/.capy/.rey-migrated`.
- If both exist and no marker: copy missing top-level entries from `~/.rey`
  into `~/.capy`, rename `~/.rey` to `~/.rey.bak.<seconds>`, create the
  compatibility symlink, write the marker.
- Create: `~/.capy/bin`, `~/.capy/cache`, `~/.capy/store`,
  `~/.capy/toolchains`, `~/.capy/registry`.
- Never delete user data.

`ensureStdLink`:

- Ensure `~/.reyc` exists.
- If `~/.reyc/std` does not exist, symlink it to `<toolchain root>/std`
  (the directory that contains `src`), because the compiler looks for
  `~/.reyc/std/src`.
- If it already exists, leave it alone (development setups often point it at
  the source tree).

`ensureBinLinks`:

- If `~/.capy/bin/rey` is missing, symlink it to `<toolchain>/bin/rey`.
- If `~/.capy/bin/reyc` is missing, symlink it to `rey`.
- Do not overwrite an existing `~/.capy/bin/capy`.

## Packaging contract

Release archive layout:

```
capy-v<version>-<target>/
├── bin/
│   └── capy
└── libexec/
    └── toolchain/
        ├── bin/rey
        ├── bin/runtime/librey_rt.a
        └── std/src/...
```

Targets: `darwin-arm64`, `darwin-x86_64`, `linux-x86_64`, `linux-aarch64`.

npm:

- `@capybara/cli` with `bin: { "capy": "bin/capy.js" }`.
- Platform packages `@capybara/darwin-arm64` etc. as `optionalDependencies`.
- Each platform package has `os`/`cpu` fields and contains `bin/capy` plus
  `libexec/toolchain`.
- `bin/capy.js` launches the platform binary and forwards args/exit code.
- No postinstall download.

Homebrew:

- Tap `rey-language/homebrew-tap`, formula `capy`.
- Formula installs `bin/capy` and `libexec/toolchain`.
- `depends_on :macos` / Linux support via `on_linux` blocks.

Installer (`install.sh`):

- Supports curl-pipe install and local archive installation.
- Downloads the latest `latest.toml` and verifies the selected archive with
  SHA-256 before extracting it.
- Installs to `$CAPY_HOME` (default `~/.capy`).
- Bootstraps Xcode Command Line Tools (clang) on macOS and installs `clang`,
  `git`, `curl`, `tar`, and `ca-certificates` through the system package
  manager on Linux when they are missing. `CAPY_SKIP_DEPS=1` disables this.
- Migrates `~/.rey` exactly as `installer.rey` does.
- Adds `$CAPY_HOME/bin` to zsh/bash/fish profiles before any old `~/.rey/bin`.
- Creates `~/.reyc/std` and `rey`/`reyc` links in `$CAPY_HOME/bin`.
- Verifies the installation with `capy --version` and `capy doctor`.
- `packaging/install.sh` is a compatibility wrapper around the root installer.

## Style rules for Rey code

- Use `std::fs;` then `fs.read(...)`, or `import std::fs::{read, write};` for
  direct symbols.
- The native compiler exposes `args()`, `exit(code)`, `cwd()` via
  `exec("/bin/pwd -P")`, and process execution via `exec()`. The bundled
  compatibility std wraps the supported builtins; it intentionally omits
  `std::process.args` and `std::process.exit` because module functions with
  those names shadow the builtins. Call the builtins directly from `main`.
- `std::env::getOr("HOME", "")`.
- `HashMap<string, string>` values need `.get(key)` and cast-free assignment
  when the value is typed.
- `Vec<string>` values use `.push`, `.len()`, `[i]`.
- Struct literals must set every field.
- Avoid default parameters in shared APIs; be explicit.
- Keep functions under ~80 lines.
- Prefer early returns over deep nesting.
- No `TODO` comments in shipped code; use `// beta:` notes only for known
  limitations.

## Bundled compatibility std

Rey `0.3.1`'s native compiler does not implement the interpreter's `native*`
builtin surface or the full pure-Rey std. `compat/std/` is a source overlay
that keeps the public modules Capy needs while using only the native compiler's
builtins (`readFile`, `writeFile`, `appendFile`, `fileExists`, `deleteFile`,
`listDir`, `exec`, `args`, `exit`). `scripts/fetch-toolchain.sh` overlays it
onto the extracted toolchain, so release archives and installed projects use
the same working std.

Compatibility-specific behavior:

- `std::toml` parses every value as a string. Use `getString`, `getInt`, or
  `getBool`; Capybara manifests and lockfiles only need strings.
- `std::cli.parseArgs` returns a typed `ParsedArgs` struct instead of `any`.
- `std::process.runDetailed` returns a typed `ExecDetail` struct.
- `std::process.args` and `std::process.exit` are not provided; use the
  builtins directly.
- `std::env` reads through `printenv` and cannot mutate the parent environment.
- Filesystem and process helpers use POSIX shell commands, so `sh`, `mktemp`,
  `rm`, `mv`, and `chmod` must be available (macOS and Linux provide them).

This overlay is a beta bridge until the native compiler and upstream std agree
on one builtin surface.
