#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper. The complete installer lives at the repository root
# and is attached to every Capy release as install.sh.

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../install.sh" ]]; then
    exec bash "$SCRIPT_DIR/../install.sh" "$@"
fi

command -v curl >/dev/null 2>&1 || {
    printf 'error: curl is required to fetch the Capy installer\n' >&2
    exit 1
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/capy-installer.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fsSL "https://raw.githubusercontent.com/rey-language/capybara/main/install.sh" -o "$TMP_DIR/install.sh"
bash "$TMP_DIR/install.sh" "$@"
