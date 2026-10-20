# Architecture

Capybara is the `capy` CLI plus a pinned Rey compiler, runtime, and standard
library. This page describes the beta interfaces and layout in
[CONTRACT.md](CONTRACT.md).

## Module map and dependency direction

```text
src/main.rey
  └── capy/app.rey                 context, global flags, dispatch
       ├── capy/commands/*         init, run, build, check, test, clean,
       │                           doctor, install, update, self_update
       ├── capy/types.rey          shared Context, Manifest, Toolchain, results
       ├── capy/project.rey        project root and project paths
       ├── capy/manifest.rey       capy.toml and capy.lock
       ├── capy/deps.rey           registry resolution and vendoring
       ├── capy/toolchain.rey      compiler discovery and invocation
       ├── capy/installer.rey      Capy home migration and compatibility links
       ├── capy/output.rey         user-facing output
       ├── capy/util.rey           paths, filesystem, environment, processes
       └── capy/version.rey        pinned versions and service URLs
```

`main` calls the app entry point. The app constructs one context and dispatches
to a command. Commands use shared project, manifest, dependency, toolchain,
installer, output, and utility modules. Shared modules do not dispatch back to
commands. `types` holds data shared across those boundaries.

## Data shapes

`Context` contains the current directory, home paths, executable path and
directory, verbosity, and flattened resolved toolchain fields (`tcFound`,
`tcRoot`, `tcRey`, `tcRuntime`, `tcStd`, `tcVersion`, `tcError`). The toolchain
fields are flattened to avoid nested-struct code-generation risk.

`Manifest` records whether a manifest was found, its path and root, package
name, version, entry path, an error string, and a map of dependency names to
version specifications. Missing package fields default to the root basename,
`0.1.0`, and `src/main.rey`, respectively.

`Toolchain` records whether it is valid and its root, `bin/rey`, runtime,
standard-library source path, Rey version, and any error. The shared execution
result contains an exit code, stdout, and stderr.

## Toolchain discovery and invocation

The first valid candidate wins:

1. `$CAPY_TOOLCHAIN`, containing `bin/rey` and `std/src`.
2. `<exeDir>/../libexec/toolchain` (packaged Homebrew, npm, or portable layout).
3. `<exeDir>/../vendor/toolchain` (development layout).
4. `<exeDir>/toolchain`.
5. `~/.capy/toolchains/current`.
6. `~/.capy/toolchains/0.3.1`.
7. `rey` on `PATH`, deriving the root from the binary and locating std via
   `$REY_STD_PATH` or `~/.reyc/std/src`.

A valid toolchain has `bin/rey`, `bin/runtime/librey_rt.a`, and `std/src`.
Before invoking the compiler, Capy sets `REY_HOME`, `REY_STD_PATH`,
`REY_RUNTIME_DIR`, and `CAPY_HOME` from the resolved toolchain and context.

The upstream Rey archive stores `librey_rt.a` as LLVM 21 bitcode. Capy's
`scripts/build-runtime.sh` compiles the maintained C sources in
`compat/runtime` into native, non-LTO objects and replaces that archive during
toolchain fetch and before each Capy build. This lets Ubuntu 22.04's clang 14
link the bundled runtime. The runtime source copy follows the Rey 0.3 ABI and
must be reviewed when that ABI changes.

All compiler entry and output paths are absolute. Rey derives a project root
from the first `/src/` segment in an entry path. Avoid placing a checkout
directly at `/src`: in that layout, root detection selects the leading segment
and imports resolve incorrectly. Build invokes `rey build <entry> -o <output>
--runtime-dir <runtime>`; check invokes `rey check <entry>`; ad-hoc script
execution invokes `rey run <entry> -- <args...>`. Project `run` builds to
`build/<name>` and executes that binary.

## Installed and mutable data

Packaged distributions place `capy` at `bin/capy` and the pinned toolchain at
`libexec/toolchain/`. A self-update archive has this layout:

```text
capy-v<version>-<target>/
├── bin/capy
└── libexec/toolchain/
    ├── bin/rey
    ├── bin/runtime/librey_rt.a
    └── std/src/...
```

The mutable user home defaults to `~/.capy` (or `$CAPY_HOME`) and contains
`bin/`, `cache/`, `store/`, `toolchains/`, and `registry/`. The default registry
cache is `~/.capy/registry/packages`. Project build products, package sources,
and the lockfile live under the project root, not in the Capy home.

If needed, `~/.capy/bin/rey` links to the bundled compiler and `reyc` links to
`rey`; an existing `capy` in that directory is not overwritten. The compiler
looks for `~/.reyc/std/src`. If `~/.reyc/std` does not already exist, Capy
links it to `<toolchain-root>/std` (the directory containing `src`). Existing
standard-library links are left in place.

## Legacy home migration

On first setup, if `~/.capy` is absent and `~/.rey` exists, the legacy home is
moved to `~/.capy`. If both homes exist and the migration marker is absent,
missing top-level entries are copied from `~/.rey`, the old directory is
renamed to `~/.rey.bak.<seconds>`, and `~/.rey` becomes a compatibility link to
`~/.capy`. A `.rey-migrated` marker is written in the new home. User data is
not deleted. See [Migration](MIGRATION.md) for layouts and rollback notes.

## Package and update safety

Registry packages in the beta consist of `capy.toml` and Rey source under
`src/`. Installation copies source into `vendor/<name>/`; the beta package
layout does not provide an install-script hook. `capy.lock` records package
version, registry commit hash, and source so an install can be tied to a
specific registry revision. Treat committed package artifacts as immutable;
corrections should use a later registry commit/version. Package signatures and
a registry yank operation are future work, not beta protections.

Self-update downloads the target archive into `~/.capy/cache/`, checks the
SHA-256 value from `release/latest.toml`, extracts it, and replaces the running
binary through a temporary path beside the executable. Bundled toolchains are
installed under `~/.capy/toolchains/<version>` and `current` is repointed.
Homebrew and npm installations are directed to their package managers instead.

## Compiler constraints behind the beta

The Rey `0.3.1` compiler has a stub type checker and code-generation
constraints that shaped this CLI and its own source. Beta implementation code
uses conservative Rey: no closures, generics, async, or threads; explicit local
types; semicolons on statements; and `loop { ... break; }` instead of
`while true`. Shared structs are kept flat to limit nested-struct codegen risk.
`--release` does not select a different optimization mode, and target selection
is unsupported. These are compiler and beta constraints, not project-level
build profiles.
