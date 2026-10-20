#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLCHAIN_DIR="$REPO_ROOT/vendor/toolchain"

if [[ ! -x "$TOOLCHAIN_DIR/bin/rey" || ! -f "$TOOLCHAIN_DIR/bin/runtime/librey_rt.a" || ! -d "$TOOLCHAIN_DIR/std/src" ]]; then
    bash "$SCRIPT_DIR/fetch-toolchain.sh"
fi

# The official Rey archives ship librey_rt.a as LLVM 21 bitcode. Rebuild the
# vendored runtime as native object code so the bundled clang can link it.
if [[ "${CAPY_NATIVE_RUNTIME:-1}" != "0" ]]; then
    bash "$SCRIPT_DIR/build-runtime.sh" "$TOOLCHAIN_DIR/bin/runtime"
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
