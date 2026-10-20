#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/compat/runtime"
OUT_DIR="${1:-$REPO_ROOT/vendor/toolchain/bin/runtime}"

[[ -f "$SOURCE_DIR/rey_rt.h" ]] || fail "runtime sources are missing: $SOURCE_DIR"

CC="${CC:-}"
if [[ -z "$CC" ]]; then
    if [[ "$(uname -s)" == "Darwin" && -x /usr/bin/clang ]]; then
        CC=/usr/bin/clang
    elif command -v clang >/dev/null 2>&1; then
        CC="$(command -v clang)"
    elif [[ -x /usr/bin/clang ]]; then
        CC=/usr/bin/clang
    elif command -v cc >/dev/null 2>&1; then
        CC="$(command -v cc)"
    else
        fail "clang (or cc) is required to build the Rey runtime"
    fi
fi
command -v "$CC" >/dev/null 2>&1 || fail "compiler not found: $CC"

AR="${AR:-}"
if [[ -z "$AR" ]]; then
    if command -v ar >/dev/null 2>&1; then
        AR="$(command -v ar)"
    elif [[ -x /usr/bin/ar ]]; then
        AR=/usr/bin/ar
    else
        fail "ar is required to archive the Rey runtime"
    fi
fi
command -v "$AR" >/dev/null 2>&1 || fail "archiver not found: $AR"

CFLAGS=(-O2 -fPIC -fno-lto -D_GNU_SOURCE -Wall -Wextra -Wno-unused-parameter -std=c11)
if [[ -n "${RUNTIME_CFLAGS:-}" ]]; then
    read -r -a CFLAGS <<< "$RUNTIME_CFLAGS"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/capy-runtime.XXXXXX")"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

OBJECT_DIR="$TMP_DIR/object"
mkdir -p "$OBJECT_DIR"
RUNTIME_SOURCES=(mem string vec hashmap result enum io value math)
OBJECTS=()
for source in "${RUNTIME_SOURCES[@]}"; do
    object="$OBJECT_DIR/$source.o"
    "$CC" "${CFLAGS[@]}" -I"$SOURCE_DIR" -c "$SOURCE_DIR/$source.c" -o "$object"
    OBJECTS+=("$object")
done

mkdir -p "$OUT_DIR"
ARCHIVE_STAGE="$OUT_DIR/librey_rt.a.tmp.$$"
"$AR" rcs "$ARCHIVE_STAGE" "${OBJECTS[@]}"
mv -f "$ARCHIVE_STAGE" "$OUT_DIR/librey_rt.a"
printf 'Built native Rey runtime: %s\n' "$OUT_DIR/librey_rt.a"
