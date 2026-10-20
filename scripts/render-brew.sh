#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CAPY_VERSION="${1:-${CAPY_VERSION:-0.1.1}}"
CAPY_VERSION="${CAPY_VERSION#v}"
DIST_DIR="${2:-$REPO_ROOT/build/dist}"
TEMPLATE="$REPO_ROOT/packaging/brew/capy.rb"
OUT="${3:-$REPO_ROOT/build/capy.rb}"

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

[[ -f "$TEMPLATE" ]] || fail "missing formula template: $TEMPLATE"
mkdir -p "$(dirname "$OUT")"
sed "s/0\\.1\\.1/$CAPY_VERSION/g" "$TEMPLATE" > "$OUT"

for target in darwin-arm64 darwin-x86_64 linux-x86_64 linux-aarch64; do
    case "$target" in
        darwin-arm64) placeholder="__SHA_DARWIN_ARM64__" ;;
        darwin-x86_64) placeholder="__SHA_DARWIN_X86_64__" ;;
        linux-x86_64) placeholder="__SHA_LINUX_X86_64__" ;;
        linux-aarch64) placeholder="__SHA_LINUX_AARCH64__" ;;
    esac
    checksum="$DIST_DIR/capy-v$CAPY_VERSION-$target.tar.gz.sha256"
    [[ -f "$checksum" ]] || fail "missing checksum file: $checksum"
    hash="$(awk '{print $1}' "$checksum")"
    [[ -n "$hash" ]] || fail "empty checksum: $checksum"
    temp="$OUT.tmp.$$"
    sed "s/$placeholder/$hash/g" "$OUT" > "$temp"
    mv "$temp" "$OUT"
done

if grep -q "__SHA_" "$OUT"; then
    fail "formula still contains an unreplaced SHA-256 placeholder"
fi

printf 'Wrote %s\n' "$OUT"
