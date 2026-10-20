# Release and packaging

This document records the Capybara beta packaging contract and release
pipeline.

Capy `0.1.1` pins Rey `0.3.1`. Release readiness requires fetching the matching
Rey assets, building and packaging Capy on each target, and validating the
packaged installer. Metadata checks alone do not establish readiness.

## Fetch, build, and package

The release process is organized around three stages:

1. Fetch the pinned Rey `0.3.1` compiler, runtime, and standard library. The
   upstream runtime archive is LLVM 21 bitcode, so `scripts/build-runtime.sh`
   rebuilds it from `compat/runtime` as native objects with the platform's
   clang and archiver. This keeps Linux builds compatible with Ubuntu 22.04's
   LLVM 14 toolchain.
2. Build Capybara with that toolchain for a supported platform.
3. Package `capy` and the matching toolchain into a target archive and
   publish the corresponding Homebrew or npm artifacts.

The scripts are `scripts/fetch-toolchain.sh`, `scripts/build.sh`, and
`scripts/package.sh`. After all four target archives exist,
`scripts/release-manifest.sh` writes `latest.toml` and `scripts/render-brew.sh`
renders the Homebrew formula. `install.sh` at the repository root is the
canonical installer; it supports curl-pipe installation and installation from a
local archive. `packaging/install.sh` is a compatibility wrapper around it.
The runtime sources in `compat/runtime` track the Rey 0.3 runtime ABI; update
them when that ABI changes. Set `CAPY_NATIVE_RUNTIME=0` only to keep the runtime
archive from the downloaded toolchain unchanged.

Build and packaging scripts reject a cached compiler whose live version does
not match `src/capy/version.rey`. Packaging also checks the built Capy version
before creating an archive. After changing the pin, fetch the matching
toolchain again; renaming an older toolchain or binary is not sufficient.
The release workflow rejects tags that differ from the source version and
publishes npm packages only after the GitHub release succeeds.

The standalone installer defaults to the latest published Capy release and
reads the bundled Rey version. `capy init` and manifests missing a package
version intentionally start user projects at `0.1.0`, independently of the
Capy CLI version.

## Archive layout and targets

Each release archive is named `capy-v<version>-<target>.tar.gz` and contains:

```text
capy-v<version>-<target>/
├── bin/
│   └── capy
└── libexec/
    └── toolchain/
        ├── bin/rey
        ├── bin/runtime/librey_rt.a
        └── std/src/...
```

Supported target names are:

| Target | Platform |
| --- | --- |
| `darwin-arm64` | macOS, Apple silicon |
| `darwin-x86_64` | macOS, Intel |
| `linux-x86_64` | Linux, x86-64 |
| `linux-aarch64` | Linux, AArch64 |

The archive layout lets Capy discover the compiler at
`<exeDir>/../libexec/toolchain`.

## Homebrew

The formula is `capy` in the `rey-language/homebrew-tap` tap. It installs
`bin/capy` and `libexec/toolchain`, with macOS and Linux formula blocks. Install
and update with:

```sh
brew install rey-language/tap/capy
brew upgrade capy
```

## npm

The top-level package is `@capybara/cli`, with the executable mapping
`capy` to `bin/capy.js`. Platform packages such as
`@capybara/darwin-arm64` are optional dependencies, declare their `os` and
`cpu`, and contain `bin/capy` plus `libexec/toolchain`. The JavaScript launcher
starts the platform binary and forwards arguments and its exit code. There is
no postinstall download.

```sh
npm install --global @capybara/cli
npm install --global @capybara/cli@latest
```

## Credentials and publication

Publishing the npm packages requires `NPM_TOKEN`. Updating the Homebrew tap
requires `HOMEBREW_TAP_TOKEN`. Store these as release-workflow secrets; never
put token values in the repository, package, or logs.

## Autoupdater manifest and checksums

The autoupdater reads `latest.toml` from the latest GitHub release. It
contains the latest version, one archive URL per target, and a SHA-256 value
for each archive:

```toml
version = "0.1.1"
darwin-arm64 = "https://.../capy-v0.1.1-darwin-arm64.tar.gz"
darwin-arm64-sha256 = "..."
darwin-x86_64 = "https://.../capy-v0.1.1-darwin-x86_64.tar.gz"
darwin-x86_64-sha256 = "..."
linux-x86_64 = "https://.../capy-v0.1.1-linux-x86_64.tar.gz"
linux-x86_64-sha256 = "..."
linux-aarch64 = "https://.../capy-v0.1.1-linux-aarch64.tar.gz"
linux-aarch64-sha256 = "..."
```

`capy update --check` fetches the manifest with `curl -fsSL --max-time 4` and
prints current/latest versions. `capy update --self` detects package-manager
installs and directs users to Homebrew or npm. For a standalone install, it
downloads into `~/.capy/cache/`, checks the selected archive with
`shasum -a 256`, extracts it, and replaces the running binary through a
temporary path beside the executable. If the archive has `libexec/toolchain`,
that toolchain is installed at `~/.capy/toolchains/<version>`,
`~/.capy/toolchains/current` is repointed, the bundled
`~/.capy/libexec/toolchain` link is refreshed, and `~/.reyc/std` follows the
new toolchain.

Release artifacts are expected to be immutable. Publish a corrected artifact
under a new version rather than replacing bytes behind an existing URL. The
beta contract defines SHA-256 verification but no signing or signature
verification.

## Installer and shell setup

The canonical installer is `install.sh` at the repository root and is attached
to every GitHub release. It installs to `$CAPY_HOME` (default `~/.capy`),
bootstraps clang/Xcode Command Line Tools when missing, verifies the release
archive with SHA-256, migrates `~/.rey` under the installer migration rules,
creates `~/.reyc/std` when needed, links `rey`/`reyc` in `$CAPY_HOME/bin`, and
adds `$CAPY_HOME/bin` to zsh, bash, and fish profiles before any old
`~/.rey/bin` entry. It finishes by running `capy --version` and `capy doctor`.

On Linux the installer also installs `clang`, `git`, `curl`, `tar`, and
`ca-certificates` through the system package manager when they are missing, and
supports `apt`, `dnf`, `yum`, `zypper`, `pacman`, and `apk`. Set
`CAPY_SKIP_DEPS=1` to skip system package installation, `CAPY_SKIP_PROFILE=1`
to leave shell profiles unchanged, or `CAPY_SKIP_VERIFY=1` to allow a local
archive without a checksum.

`packaging/install.sh` remains as a compatibility wrapper that delegates to the
root installer in a checkout or fetches it from `main`.

## Notarization caveat

The beta packaging contract does not define macOS code signing or notarization.
Do not treat a SHA-256 checksum as a notarization or Gatekeeper approval; the
release process must document a notarization step separately if one is added.
