#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CAPY_VERSION="${CAPY_VERSION:-0.1.1}"
CAPY_VERSION="${CAPY_VERSION#v}"
DIST_DIR="$REPO_ROOT/build/dist"
NPM_ROOT="$REPO_ROOT/build/npm"
CLI_TEMPLATE="$REPO_ROOT/packaging/npm/cli"
PLATFORM_TEMPLATES="$REPO_ROOT/packaging/npm/platforms"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/capybara-npm.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v node >/dev/null 2>&1 || {
    printf 'error: Node.js is required to assemble npm packages\n' >&2
    exit 1
}

update_manifest() {
    local manifest_path="$1"
    node - "$manifest_path" "$CAPY_VERSION" <<'NODE'
const fs = require("node:fs");

const manifestPath = process.argv[2];
const version = process.argv[3];
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
manifest.version = version;
if (manifest.optionalDependencies) {
  for (const name of Object.keys(manifest.optionalDependencies)) {
    manifest.optionalDependencies[name] = version;
  }
}
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
NODE
}

mkdir -p "$NPM_ROOT"
rm -rf "$NPM_ROOT/@capybara"
mkdir -p "$NPM_ROOT/@capybara"

for target in darwin-arm64 darwin-x86_64 linux-x86_64 linux-aarch64; do
    case "$target" in
        darwin-arm64) npm_name="darwin-arm64" ;;
        darwin-x86_64) npm_name="darwin-x64" ;;
        linux-x86_64) npm_name="linux-x64" ;;
        linux-aarch64) npm_name="linux-arm64" ;;
    esac

    archive="$DIST_DIR/capy-v$CAPY_VERSION-$target.tar.gz"
    [[ -f "$archive" ]] || {
        printf 'error: missing release archive: %s\n' "$archive" >&2
        exit 1
    }

    extract_dir="$TMP_DIR/$target"
    mkdir -p "$extract_dir"
    tar -xzf "$archive" -C "$extract_dir"
    release_dir="$extract_dir/capy-v$CAPY_VERSION-$target"
    [[ -d "$release_dir" ]] || {
        printf 'error: archive has an unexpected layout: %s\n' "$archive" >&2
        exit 1
    }
    [[ -f "$release_dir/bin/capy" && -d "$release_dir/libexec/toolchain" ]] || {
        printf 'error: release archive is missing bin/capy or libexec/toolchain: %s\n' "$archive" >&2
        exit 1
    }

    package_dir="$NPM_ROOT/@capybara/$npm_name"
    mkdir -p "$package_dir"
    cp "$PLATFORM_TEMPLATES/$npm_name/package.json" "$package_dir/package.json"
    cp -R "$release_dir/bin" "$package_dir/bin"
    cp -R "$release_dir/libexec" "$package_dir/libexec"
    update_manifest "$package_dir/package.json"
    printf 'Prepared %s\n' "$package_dir"
done

CLI_PACKAGE_DIR="$NPM_ROOT/@capybara/cli"
mkdir -p "$CLI_PACKAGE_DIR"
cp "$CLI_TEMPLATE/package.json" "$CLI_PACKAGE_DIR/package.json"
cp "$CLI_TEMPLATE/README.md" "$CLI_PACKAGE_DIR/README.md"
cp -R "$CLI_TEMPLATE/bin" "$CLI_PACKAGE_DIR/bin"
chmod +x "$CLI_PACKAGE_DIR/bin/capy.js"
update_manifest "$CLI_PACKAGE_DIR/package.json"
printf 'Prepared %s\n' "$CLI_PACKAGE_DIR"

printf '\nPublish the platform packages first, then the CLI package:\n'
for package_name in darwin-arm64 darwin-x64 linux-x64 linux-arm64; do
    printf 'npm publish --access public "%s"\n' "$NPM_ROOT/@capybara/$package_name"
done
printf 'npm publish --access public "%s"\n' "$CLI_PACKAGE_DIR"
