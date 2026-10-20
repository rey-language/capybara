#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CAPY_VERSION="${1:-${CAPY_VERSION:-0.1.0}}"
CAPY_VERSION="${CAPY_VERSION#v}"
DIST_DIR="${2:-$REPO_ROOT/build/dist}"
REPO_SLUG="${GITHUB_REPOSITORY:-rey-language/capybara}"
RELEASES_BASE="${CAPY_RELEASES_BASE:-https://github.com/$REPO_SLUG/releases/download}"
OUT="$DIST_DIR/latest.toml"

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

[[ -d "$DIST_DIR" ]] || fail "distribution directory does not exist: $DIST_DIR"
mkdir -p "$DIST_DIR"

printf 'version = "%s"\n' "$CAPY_VERSION" > "$OUT"
for target in darwin-arm64 darwin-x86_64 linux-x86_64 linux-aarch64; do
    archive="$DIST_DIR/capy-v$CAPY_VERSION-$target.tar.gz"
    checksum="$archive.sha256"
    [[ -f "$archive" ]] || fail "missing release archive: $archive"
    [[ -f "$checksum" ]] || fail "missing checksum file: $checksum"
    hash="$(awk '{print $1}' "$checksum")"
    [[ -n "$hash" ]] || fail "empty checksum: $checksum"
    printf '%s = "%s/v%s/%s"\n' "$target" "$RELEASES_BASE" "$CAPY_VERSION" "$(basename "$archive")" >> "$OUT"
    printf '%s-sha256 = "%s"\n' "$target" "$hash" >> "$OUT"
done

printf 'Wrote %s\n' "$OUT"
