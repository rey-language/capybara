# Command reference

Global flags and commands:

```sh
capy [--verbose|-v] <command> [arguments...]
capy help
capy version
```

With no command, `capy` prints usage and exits `0`. `help`, `--help`, and `-h`
print usage (or command help); `version`, `--version`, and `-V` print
`capy <version> (rey <version>)`. Unknown commands print an error and help, then
exit `1`. Command errors return nonzero; the contract does not assign a
separate numeric code to every setup failure.

## `init`

```sh
capy init [--name <name>] [--force]
```

Creates `src/`, `capy.toml`, `src/main.rey`, and `.gitignore` in the current
directory. The package name comes from `--name`, or the current directory's
basename. It does not run `git init`. The generated source prints
`Hello from Capybara!`; the ignore file excludes `build/`, `vendor/`, `.capy/`,
`*.tar.gz`, and `.DS_Store`.

If `capy.toml` exists, initialization refuses unless `--force` is given. An
existing `src/main.rey` is never silently overwritten: without `--force` this
is an error; with `--force` it is backed up as `src/main.rey.bak` first.

Exit status: `0` on success; `1` for a refusal or command error.

```sh
capy init
capy init --name weather-cli
capy init --force
```

## `run`

```sh
capy run [file.rey] [--release] [-- args...]
```

If the first positional argument ends in `.rey`, Capy runs that file directly
through `rey run`. Otherwise it loads the project entry from `capy.toml`,
builds it to `build/<name>`, and runs that executable. Arguments after `--`
are passed to the program. `--release` is accepted but prints a warning: the
bundled compiler already optimizes and does not provide a release mode.

Exit status: returns the child program's exit code. Setup or compiler errors
are nonzero.

```sh
capy run
capy run src/tool.rey -- input.txt
capy run --release
```

## `build`

```sh
capy build [file.rey] [-o|--output <path>] [--release]
```

Builds the project entry or a single Rey file. The default output is
`build/<name>` for a project, or `build/<file-basename>` for file mode. Parent
directories are created as needed. On success, Capy prints `Built <path>`.
`--release` prints the same warning as `run`; it does not change compiler
optimization. `--target` is rejected because beta target selection is not
supported.

Exit status: the compiler's exit code for a build; command/argument errors are
nonzero.

```sh
capy build
capy build src/tool.rey -o build/tool
capy build --release
```

## `check`

```sh
capy check [file.rey]
```

Checks a project entry or a single Rey file with the parser and type checker.
It does not produce a binary. Prints `ok` on success.

Exit status: `0` on success; nonzero on command or compiler error.

```sh
capy check
capy check src/tool.rey
```

## `test`

```sh
capy test [--filter <substr>] [--list]
```

Discovers `*_test.rey` files under existing `src/` and `tests/` directories.
It skips `vendor/`, `build/`, `.capy/`, and `node_modules/`. Each discovered
test is built to `build/tests/<name>` and executed sequentially. The output is
`ok <path>` or `FAIL <path>`; failures include captured stderr, followed by an
`N passed, M failed` summary. `--filter` keeps paths containing the supplied
substring. `--list` prints discovered paths without building or executing
these tests.

Exit status: no tests is a successful result (`0`). The beta contract does not
specify the aggregate exit code for a nonempty suite with failing tests.

```sh
capy test
capy test --filter parser
capy test --list
```

## `clean`

```sh
capy clean [--all]
```

Removes the project `build/` directory. With `--all`, also removes project
`vendor/` and `capy.lock`. It never removes `~/.capy`.

Exit status: `0` on success; nonzero on a command error.

```sh
capy clean
capy clean --all
```

## `doctor`

```sh
capy doctor [--online]
```

Prints checks for the Capy version, project root and manifest (when in a
project), toolchain root and Rey version, standard library and runtime files,
`clang`, `git`, `curl`, `tar`, `shasum` on `PATH`, whether `~/.capy` is
writable, the `~/.reyc/std` target, and whether `which capy` resolves inside
`~/.capy/bin` or to the current executable. `--online` also checks the latest
Capy version.

Exit status: `1` if a critical check fails (toolchain, Rey, std, or runtime);
otherwise `0`.

```sh
capy doctor
capy doctor --online
```

## `install`

```sh
capy install [pkg[@version]] [--locked] [--force] [--offline] [--registry <url|path>]
```

Requires a project manifest. With no package argument, installs all declared
dependencies. With `pkg[@version]`, adds or updates that dependency in
`capy.toml` and installs it. Version selection accepts an exact string or
`*`/empty for any version.

The default registry is `https://github.com/rey-language/packages.git`, cached
at `~/.capy/registry/packages`. A missing cache is cloned shallowly; an
existing cache is updated with `git pull --ff-only` unless `--offline` or
`--locked` is used. `--registry` selects a URL or local path. Packages are
copied to `vendor/<name>/`, with the package's `src/` contents flattened at
that directory's root and its `capy.toml` copied alongside. The beta import
form is `import vendor::<name>;`. Installation writes `capy.lock` with each
package's version, registry commit, and source.

`--locked` verifies that the lock satisfies every dependency and does not
update it. `--force` recopies an existing vendor directory. `--offline`
prevents network access.

Exit status: `0` on success; `1` for a missing manifest or command/install
error.

```sh
capy install
capy install rey-postgres@0.1.0
capy install --locked
capy install --offline --registry ./packages
```

## `update`

```sh
capy update [pkg] [--self] [--check] [--offline]
```

With no `--self` or `--check`, refreshes the registry cache, re-resolves
project dependencies, reinstalls them, and updates the lockfile. Supplying
`pkg` limits dependency updates to that package while still reading the
manifest. `--offline` prevents network access.

`--check` checks and prints the current and latest Capy versions.
`--self` updates the Capy executable. For Homebrew installs it directs the
user to `brew upgrade capy`; for npm installs it directs the user to
`npm i -g @capybara/cli@latest`. Standalone installs download a platform
archive, verify its SHA-256, and replace the executable. See
[Release](RELEASE.md).

Exit status: `0` when the requested update/check succeeds; nonzero on update
or command error. For package-managed installs, `--self` reports that the
package manager should perform the update and returns `1`.

```sh
capy update
capy update rey-postgres
capy update --check
capy update --self
capy update --offline
```
