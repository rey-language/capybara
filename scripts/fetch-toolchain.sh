#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REY_VERSION="${REY_VERSION:-0.3.0}"
OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"

case "$OS_NAME" in
    Darwin)
        case "$ARCH_NAME" in
            arm64|aarch64) REY_TARGET="macos-arm64" ;;
            x86_64|amd64) REY_TARGET="macos-x86_64" ;;
            *) fail "Unsupported macOS architecture: $ARCH_NAME" ;;
        esac
        ;;
    Linux)
        case "$ARCH_NAME" in
            x86_64|amd64) REY_TARGET="linux-x86_64" ;;
            aarch64|arm64) REY_TARGET="linux-aarch64" ;;
            *) fail "Unsupported Linux architecture: $ARCH_NAME" ;;
        esac
        ;;
    *)
        fail "Unsupported operating system: $OS_NAME"
        ;;
esac

DOWNLOAD_URL="https://github.com/rey-language/rey/releases/download/v$REY_VERSION/rey-v$REY_VERSION-$REY_TARGET.tar.gz"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/capy-toolchain.XXXXXX")"
STAGE_DIR="$REPO_ROOT/vendor/.toolchain.new.$$"
BACKUP_DIR="$REPO_ROOT/vendor/.toolchain.previous.$$"
cleanup() {
    rm -rf "$TMP_DIR" "$STAGE_DIR"
}
trap cleanup EXIT

if [[ -n "${REY_ARCHIVE:-}" ]]; then
    [[ -f "$REY_ARCHIVE" ]] || fail "REY_ARCHIVE does not exist: $REY_ARCHIVE"
    ARCHIVE="$REY_ARCHIVE"
else
    command -v curl >/dev/null 2>&1 || fail "curl is required to download the Rey toolchain"
    ARCHIVE="$TMP_DIR/rey.tar.gz"
    curl -fsSL "$DOWNLOAD_URL" -o "$ARCHIVE"
fi

EXTRACT_DIR="$TMP_DIR/extracted"
mkdir -p "$EXTRACT_DIR" "$REPO_ROOT/vendor"
tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"
SOURCE_DIR="$EXTRACT_DIR/rey-v$REY_VERSION-$REY_TARGET"
[[ -d "$SOURCE_DIR" ]] || fail "Archive does not contain rey-v$REY_VERSION-$REY_TARGET"
[[ -f "$SOURCE_DIR/bin/rey" ]] || fail "Rey archive is missing bin/rey"
[[ -f "$SOURCE_DIR/bin/runtime/librey_rt.a" ]] || fail "Rey archive is missing bin/runtime/librey_rt.a"
[[ -d "$SOURCE_DIR/std/src" ]] || fail "Rey archive is missing std/src"

rm -rf "$STAGE_DIR" "$BACKUP_DIR"
cp -R "$SOURCE_DIR" "$STAGE_DIR"
chmod +x "$STAGE_DIR/bin/rey"
if [[ -f "$STAGE_DIR/bin/rey.bin" ]]; then
    chmod +x "$STAGE_DIR/bin/rey.bin"
fi
if [[ -f "$STAGE_DIR/bin/rey-v0" ]]; then
    chmod +x "$STAGE_DIR/bin/rey-v0"
fi
if [[ -d "$REPO_ROOT/compat/std" ]]; then
    rm -rf "$STAGE_DIR/std/src"
    cp -R "$REPO_ROOT/compat/std" "$STAGE_DIR/std/src"
fi
if [[ "${CAPY_NATIVE_RUNTIME:-1}" != "0" ]]; then
    bash "$SCRIPT_DIR/build-runtime.sh" "$STAGE_DIR/bin/runtime"
fi
if [[ -e "$REPO_ROOT/vendor/toolchain" || -L "$REPO_ROOT/vendor/toolchain" ]]; then
    mv "$REPO_ROOT/vendor/toolchain" "$BACKUP_DIR"
fi
if ! mv "$STAGE_DIR" "$REPO_ROOT/vendor/toolchain"; then
    if [[ -e "$BACKUP_DIR" || -L "$BACKUP_DIR" ]]; then
        mv "$BACKUP_DIR" "$REPO_ROOT/vendor/toolchain"
    fi
    fail "Could not install the Rey toolchain"
fi
rm -rf "$BACKUP_DIR"
printf 'Fetched Rey %s for %s into %s\n' "$REY_VERSION" "$REY_TARGET" "$REPO_ROOT/vendor/toolchain"
