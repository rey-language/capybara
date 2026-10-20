#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLCHAIN_DIR="$REPO_ROOT/vendor/toolchain"

if [[ ! -x "$TOOLCHAIN_DIR/bin/rey" || ! -f "$TOOLCHAIN_DIR/bin/rey.bin" || ! -f "$TOOLCHAIN_DIR/bin/runtime/librey_rt.a" || ! -d "$TOOLCHAIN_DIR/std/src" ]]; then
    bash "$SCRIPT_DIR/fetch-toolchain.sh"
fi

if [[ ! -e "$REPO_ROOT/std" && ! -L "$REPO_ROOT/std" ]]; then
    ln -s "$TOOLCHAIN_DIR/std/src" "$REPO_ROOT/std"
fi

export REY_HOME="$TOOLCHAIN_DIR"
export REY_STD_PATH="$TOOLCHAIN_DIR/std/src"
export REY_RUNTIME_DIR="$TOOLCHAIN_DIR/bin/runtime"

cd "$REPO_ROOT"
mkdir -p build
"$TOOLCHAIN_DIR/bin/rey" build "$REPO_ROOT/src/main.rey" -o "$REPO_ROOT/build/capy" --runtime-dir "$TOOLCHAIN_DIR/bin/runtime"
chmod +x build/capy
