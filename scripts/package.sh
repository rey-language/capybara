#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CAPY_VERSION="${CAPY_VERSION:-0.1.1}"
CAPY_VERSION="${CAPY_VERSION#v}"
CAPY_TARGET="${1:-${CAPY_TARGET:-}}"

[[ -f "$REPO_ROOT/build/capy" ]] || {
    printf 'error: build/capy is required; run scripts/build.sh first\n' >&2
    exit 1
}
[[ -n "$CAPY_TARGET" ]] || {
    printf 'error: pass a release target (darwin-arm64, darwin-x86_64, linux-x86_64, linux-aarch64)\n' >&2
    exit 1
}
case "$CAPY_TARGET" in
    darwin-arm64|darwin-x86_64|linux-x86_64|linux-aarch64) ;;
    *)
        printf 'error: unsupported release target: %s\n' "$CAPY_TARGET" >&2
        exit 1
        ;;
esac

TOOLCHAIN_DIR="$REPO_ROOT/vendor/toolchain"
[[ -x "$TOOLCHAIN_DIR/bin/rey" ]] || {
    printf 'error: toolchain is missing an executable bin/rey\n' >&2
    exit 1
}
[[ -f "$TOOLCHAIN_DIR/bin/runtime/librey_rt.a" ]] || {
    printf 'error: toolchain is missing bin/runtime/librey_rt.a\n' >&2
    exit 1
}
[[ -d "$TOOLCHAIN_DIR/std/src" ]] || {
    printf 'error: toolchain is missing std/src\n' >&2
    exit 1
}

PINNED_REY_VERSION="$(sed -n '/func reyVersion()/,/}/s/.*return "\([^"]*\)";.*/\1/p' "$REPO_ROOT/src/capy/version.rey")"
ACTUAL_REY_VERSION="$("$TOOLCHAIN_DIR/bin/rey" --version)"
[[ "$ACTUAL_REY_VERSION" == "rey $PINNED_REY_VERSION" ]] || {
    printf 'error: expected rey %s, got: %s\n' "$PINNED_REY_VERSION" "$ACTUAL_REY_VERSION" >&2
    exit 1
}
# Capy initializes its home even for --version; keep verification isolated.
VERIFY_HOME="$(mktemp -d "${TMPDIR:-/tmp}/capy-package.XXXXXX")"
trap 'rm -rf "$VERIFY_HOME"' EXIT
ACTUAL_CAPY_VERSION="$(HOME="$VERIFY_HOME" CAPY_HOME="$VERIFY_HOME/.capy" "$REPO_ROOT/build/capy" --version)"
[[ "$ACTUAL_CAPY_VERSION" == "capy $CAPY_VERSION (rey $PINNED_REY_VERSION)" ]] || {
    printf 'error: expected capy %s (rey %s), got: %s\n' "$CAPY_VERSION" "$PINNED_REY_VERSION" "$ACTUAL_CAPY_VERSION" >&2
    exit 1
}

DIST_DIR="$REPO_ROOT/build/dist"
PACKAGE_NAME="capy-v$CAPY_VERSION-$CAPY_TARGET"
PACKAGE_DIR="$DIST_DIR/$PACKAGE_NAME"
ARCHIVE="$DIST_DIR/$PACKAGE_NAME.tar.gz"
CHECKSUM_FILE="$ARCHIVE.sha256"
mkdir -p "$DIST_DIR"
rm -rf "$PACKAGE_DIR"
rm -f "$ARCHIVE" "$CHECKSUM_FILE"
mkdir -p "$PACKAGE_DIR/bin" "$PACKAGE_DIR/libexec"
cp "$REPO_ROOT/build/capy" "$PACKAGE_DIR/bin/capy"
chmod +x "$PACKAGE_DIR/bin/capy"
cp -R "$TOOLCHAIN_DIR" "$PACKAGE_DIR/libexec/toolchain"

tar -czf "$ARCHIVE" -C "$DIST_DIR" "$PACKAGE_NAME"
if command -v shasum >/dev/null 2>&1; then
    HASH_LINE="$(cd "$DIST_DIR" && shasum -a 256 "$PACKAGE_NAME.tar.gz")"
elif command -v sha256sum >/dev/null 2>&1; then
    HASH_LINE="$(cd "$DIST_DIR" && sha256sum "$PACKAGE_NAME.tar.gz")"
else
    printf 'error: shasum or sha256sum is required\n' >&2
    exit 1
fi
printf '%s\n' "$HASH_LINE" > "$CHECKSUM_FILE"
SHA256="${HASH_LINE%% *}"

printf 'Packaged %s\n' "$ARCHIVE"
printf 'SHA-256: %s\n' "$SHA256"
printf 'Run scripts/render-brew.sh after all four target archives are available.\n'
