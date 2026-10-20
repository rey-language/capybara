# Changelog

## 0.1.1 - 2026-10-20

Patch release of Capybara, the `capy` CLI for the Rey programming language.

### Changed

- Bundle Rey 0.3.1 and publish the Capy CLI as version 0.1.1.
- Avoid a second Rey process startup during ordinary toolchain discovery while
  keeping `capy doctor`'s live compiler-version check.

## 0.1.0 - 2026-10-20

First beta of Capybara, the `capy` CLI for the Rey programming language.

### Added

- `capy init`, `run`, `build`, `check`, `test`, `clean`, `doctor`, `install`,
  `update`, `help`, and `version`.
- Bundled Rey 0.3.0 compiler, runtime, and compatibility standard library.
- Rebuild the bundled runtime from maintained C sources as native objects so
  Linux builds do not depend on LLVM bitcode compatibility.
- Vendored dependencies from the Rey package registry, with `capy.lock`,
  `--locked`, `--force`, `--offline`, and `capy update`.
- `~/.rey` to `~/.capy` migration, `~/.reyc/std` setup, and `rey`/`reyc` links.
- Standalone `install.sh` that bootstraps clang/Xcode Command Line Tools and
  basic build tools, verifies release checksums, and configures zsh, bash, and
  fish.
- `capy update --check` and `capy update --self` with SHA-256 verification.
- Release archives for macOS arm64/x64 and Linux x64/arm64, `latest.toml`,
  Homebrew formula rendering, and npm platform packages.
- Homebrew and npm packaging templates.

### Known limits

- The bundled compiler always optimizes; per-project compiler selection and
  cross-target builds are not supported.
- The compatibility standard library covers Capy's imports but not every
  upstream Rey standard-library module.
- Registry packages are single-version directories; there is no registry
  index, signing, or yank operation.
