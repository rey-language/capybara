# Capy packaging

Capy release archives use the layout required by docs/CONTRACT.md:

~~~text
capy-v<version>-<target>/
├── bin/capy
└── libexec/toolchain/
    ├── bin/rey
    ├── bin/runtime/librey_rt.a
    └── std/src/
~~~

Only `bin/rey` is required. Older Rey 0.3.0 archives may also contain
`bin/rey.bin` (the native engine behind a wrapper) and `bin/rey-v0` (the Rust
reference implementation); Capy carries them through when present but never
invokes `rey-v0`.

Supported targets are darwin-arm64, darwin-x86_64, linux-x86_64, and
linux-aarch64. The Rey 0.3.0 archives call the Darwin targets macos-arm64 and
macos-x86_64; scripts/fetch-toolchain.sh maps those release names.

Build and package from the repository root:

~~~sh
bash scripts/fetch-toolchain.sh
bash scripts/build.sh
bash scripts/package.sh darwin-arm64
~~~

Set CAPY_VERSION to select a Capy version and REY_VERSION to select the pinned
Rey toolchain version. Set REY_ARCHIVE to use a local Rey release archive.
scripts/package.sh writes a tar.gz archive and a matching .sha256 file under
build/dist.

After all four archives exist, run:

~~~sh
bash scripts/release-manifest.sh 0.1.0 build/dist
bash scripts/render-brew.sh 0.1.0 build/dist build/capy.rb
~~~

release-manifest.sh writes latest.toml (the endpoint used by capy update),
and render-brew.sh fills every Homebrew SHA and writes build/capy.rb.

The Homebrew formula is intended for rey-language/homebrew-tap. The npm
assembler creates build/npm/@capybara platform packages and the CLI package,
then prints publish commands. It does not publish them.

The release workflow builds the four target archives, attaches the archives,
checksums, latest.toml, the rendered Homebrew formula, and install.sh to the
GitHub release, and publishes the npm packages when NPM_TOKEN is configured.
Copying the formula into the tap remains a manual step until tap automation is
connected. Set NPM_TOKEN and HOMEBREW_TAP_TOKEN as repository secrets to enable
those publication paths.
