# Capybara

Capybara is the `capy` command-line front door to the Rey compiler, runtime,
and standard library. The beta is version `0.1.1` and bundles Rey `0.3.1`.

## Install

The beta installer sets up the complete Rey toolchain for your user account:

```sh
curl -fsSL https://raw.githubusercontent.com/rey-language/capybara/main/install.sh | sh
```

It installs:

- `capy` plus the bundled Rey `0.3.1` compiler, runtime, and standard library
- `clang` on Linux, or Xcode Command Line Tools on macOS, when missing
- `git`, `curl`, and `tar` on Linux when missing
- `~/.capy/bin` on `PATH` in zsh, bash, and fish profiles
- `~/.reyc/std` and `~/.capy/bin/rey` for direct compiler use
- a migrated `~/.rey` home when one already exists

The installer downloads the latest release archive, verifies its SHA-256,
installs under `$CAPY_HOME` (default `~/.capy`), and finishes with `capy doctor`.

Set `CAPY_VERSION=0.1.1` to pin a version, `CAPY_HOME=...` to choose another
location, or `CAPY_ARCHIVE=/path/to/capy.tar.gz` to install a local build.
`CAPY_SKIP_DEPS=1` skips system package installation and
`CAPY_SKIP_PROFILE=1` leaves shell profiles untouched.

Other channels are prepared for the release pipeline:

```sh
brew install rey-language/tap/capy
npm install --global @capybara/cli
```

These require the corresponding tap or npm package to be published first.

Capy supports macOS and glibc-based Linux on x86-64 and aarch64. The installer
needs `curl` and `tar`; everything else it can bootstrap is listed above.

## Quick start

```sh
mkdir hello-capy
cd hello-capy
capy init --name hello-capy
capy run
capy build
```

`capy init` creates `capy.toml`, `src/main.rey`, and `.gitignore`. The default
entry point prints `Hello from Capybara!`.

## Project layout

```text
hello-capy/
├── capy.toml
├── capy.lock       # created when dependencies are locked
├── src/
│   └── main.rey
├── tests/          # optional test sources
├── vendor/         # installed package sources
└── build/          # generated binaries and test executables
```

A minimal `capy.toml` looks like this:

```toml
[package]
name = "hello-capy"
version = "0.1.0"
entry = "src/main.rey"

[dependencies]
```

The entry defaults to `src/main.rey`. Dependencies are installed from the Rey
package registry and vendored into `vendor/<name>/`; the beta import form is
`import vendor::<name>;`. See [Registry](docs/REGISTRY.md).

## Commands

| Command | Purpose |
| --- | --- |
| `capy init` | Create a project in the current directory. |
| `capy run` | Build and run the project entry, or run a `.rey` file directly. |
| `capy build` | Build the project entry or a `.rey` file. |
| `capy check` | Run the parser and type checker without producing a binary. |
| `capy test` | Discover and run `*_test.rey` files under `src/` and `tests/`. |
| `capy clean` | Remove generated build output; `--all` also removes vendored dependencies and the lockfile. |
| `capy doctor` | Inspect the project, bundled toolchain, and required tools. |
| `capy install` | Add or install dependencies from the registry. |
| `capy update` | Refresh dependencies or check/update the `capy` executable. |

See the complete [command reference](docs/COMMANDS.md).

## Toolchain and updates

Capybara prefers its bundled Rey toolchain. It can also use a toolchain selected
by `$CAPY_TOOLCHAIN`, a development toolchain beside the executable, or a
compatible `rey` found on `PATH`. The standalone installer also links `rey` and
`reyc` in `~/.capy/bin` and points `~/.reyc/std` at the bundled standard
library, so the compiler works directly as well as through `capy`. Toolchain
lookup and environment details are in [Architecture](docs/ARCHITECTURE.md).

`capy update --check` checks the latest Capybara version. `capy update --self`
updates the executable when installed from a standalone archive. Homebrew and
npm installs are updated with their package managers. Automatic update checks
are disabled unless `CAPY_UPDATE_CHECK=1` is set; an enabled check runs at most
once per 24 hours and does not fail the command it accompanies.

## Beta limits

- Capybara bundles Rey `0.3.1`; this beta does not select compiler versions per
  project.
- The bundled compiler always optimizes. `--release` is accepted by `run` and
  `build` with a warning; `build --target` is rejected.
- Rey `0.3.1`'s native compiler supports a conservative subset of the language
  and builtins. Capybara ships a compatibility standard library in
  `compat/std/`; its behavior and limits are documented in the
  [build contract](docs/CONTRACT.md#bundled-compatibility-std). The supported
  authoring subset is summarized in the [Rey primer](docs/REY-PRIMER.md).
- Registry packages have one version per package directory. There is no
  registry index, publish command, package signature verification, or yank
  operation in this beta.
- The package contract vendors source and a manifest; it does not define
  package install scripts.

