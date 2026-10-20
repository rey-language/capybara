#!/usr/bin/env bash
set -euo pipefail

# Capybara installer
#
# Installs the latest Capy CLI together with its bundled Rey compiler, runtime,
# and standard library. On macOS it bootstraps Xcode Command Line Tools
# (clang) when needed; on Linux it installs clang and the basic build tools
# through the system package manager when they are missing.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rey-language/capybara/main/install.sh | sh
#
# Environment:
#   CAPY_HOME             Install directory (default: ~/.capy)
#   CAPY_VERSION          Install a specific Capy version instead of latest
#   CAPY_ARCHIVE          Install from a local release archive
#   CAPY_ARCHIVE_URL      Override the archive download URL
#   CAPY_UPDATE_MANIFEST  Override the latest.toml manifest URL or path
#   CAPY_SKIP_DEPS=1      Do not install clang/system packages
#   CAPY_SKIP_PROFILE=1   Do not edit shell profiles
#   CAPY_SKIP_VERIFY=1    Allow an archive without a SHA-256 checksum
#   CAPY_CLANG_WAIT       Seconds to wait for macOS CLT (default: 600)

REPO_SLUG="${CAPY_REPO:-rey-language/capybara}"
DEFAULT_MANIFEST_URL="https://github.com/$REPO_SLUG/releases/latest/download/latest.toml"

info() {
    printf '==> %s\n' "$*"
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

usage() {
    cat <<'EOF'
Capybara installer

Installs the Capy CLI, the bundled Rey compiler/runtime/standard library, and
the build tools Capy needs.

Usage:
  install.sh [--help]

Environment:
  CAPY_HOME            Install directory (default: ~/.capy)
  CAPY_VERSION         Install a specific Capy version instead of latest
  CAPY_ARCHIVE         Install from a local release archive
  CAPY_ARCHIVE_URL     Override the archive download URL
  CAPY_UPDATE_MANIFEST Override the latest.toml manifest URL or path
  CAPY_SKIP_DEPS=1     Do not install clang/system packages
  CAPY_SKIP_PROFILE=1  Do not edit shell profiles
  CAPY_SKIP_VERIFY=1   Allow an archive without a SHA-256 checksum
  CAPY_CLANG_WAIT      Seconds to wait for macOS CLT (default: 600)
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        fail "unknown argument: $1 (use --help)"
        ;;
esac

: "${HOME:?HOME must be set}"
CAPY_HOME="${CAPY_HOME:-$HOME/.capy}"
CAPY_HOME="${CAPY_HOME%/}"
if [[ "$CAPY_HOME" != /* ]]; then
    CAPY_HOME="$PWD/$CAPY_HOME"
fi

REY_HOME="$HOME/.rey"
MARKER="$CAPY_HOME/.rey-migrated"

case "$(uname -s)" in
    Darwin)
        OS="Darwin"
        case "$(uname -m)" in
            arm64|aarch64) TARGET="darwin-arm64" ;;
            x86_64|amd64) TARGET="darwin-x86_64" ;;
            *) fail "Unsupported macOS architecture: $(uname -m)" ;;
        esac
        ;;
    Linux)
        OS="Linux"
        case "$(uname -m)" in
            x86_64|amd64) TARGET="linux-x86_64" ;;
            aarch64|arm64) TARGET="linux-aarch64" ;;
            *) fail "Unsupported Linux architecture: $(uname -m)" ;;
        esac
        ;;
    *)
        fail "Unsupported operating system: $(uname -s). Capy supports macOS and Linux."
        ;;
esac

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/capy-install.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

run_privileged() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif have sudo; then
        sudo "$@"
    else
        fail "root privileges are required to install system packages"
    fi
}

clang_works() {
    if [[ "$OS" == "Darwin" ]]; then
        /usr/bin/clang --version >/dev/null 2>&1
    else
        have clang && clang --version >/dev/null 2>&1
    fi
}

ensure_macos_clt() {
    if clang_works; then
        return 0
    fi
    if [[ "${CAPY_SKIP_DEPS:-0}" == "1" ]]; then
        warn "clang is missing and CAPY_SKIP_DEPS=1; Capy will not be able to compile until Xcode Command Line Tools are installed"
        return 0
    fi

    info "Xcode Command Line Tools (clang) are required"
    if [[ ! -r /dev/tty ]]; then
        fail "clang is missing. Run 'xcode-select --install', finish the installation, and re-run this installer"
    fi

    printf 'Install Xcode Command Line Tools now? [Y/n] ' >/dev/tty
    read -r reply </dev/tty || reply=""
    case "${reply:-y}" in
        [Nn]*) fail "clang is missing. Run 'xcode-select --install', finish the installation, and re-run this installer" ;;
    esac

    xcode-select --install >/dev/null 2>&1 || true
    local wait_seconds="${CAPY_CLANG_WAIT:-600}"
    [[ "$wait_seconds" =~ ^[0-9]+$ ]] || wait_seconds=600
    local waited=0
    info "Waiting for Command Line Tools (up to ${wait_seconds}s)"
    while ! clang_works; do
        if (( waited >= wait_seconds )); then
            fail "Xcode Command Line Tools did not finish installing. Complete the installer dialog, then re-run this script"
        fi
        sleep 5
        waited=$((waited + 5))
        if (( waited % 30 == 0 )); then
            info "Still waiting for Command Line Tools (${waited}s)"
        fi
    done
    info "clang is available"
}

ensure_linux_deps() {
    local missing=""
    local command_name
    for command_name in clang git curl tar; do
        if ! have "$command_name"; then
            missing="$missing $command_name"
        fi
    done
    if have clang && ! clang --version >/dev/null 2>&1; then
        missing="$missing clang"
    fi
    if ! have shasum && ! have sha256sum; then
        missing="$missing sha256"
    fi
    if [[ -z "$missing" ]]; then
        return 0
    fi

    if [[ "${CAPY_SKIP_DEPS:-0}" == "1" ]]; then
        warn "missing system tools:$missing (skipped because CAPY_SKIP_DEPS=1)"
        return 0
    fi

    info "Installing system dependencies:$missing"
    if have apt-get; then
        run_privileged apt-get update
        run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y clang git curl tar ca-certificates coreutils
    elif have dnf; then
        run_privileged dnf install -y clang git curl tar ca-certificates coreutils
    elif have yum; then
        run_privileged yum install -y clang git curl tar ca-certificates coreutils
    elif have zypper; then
        run_privileged zypper --non-interactive install clang git curl tar ca-certificates coreutils
    elif have pacman; then
        run_privileged pacman -Sy --noconfirm clang git curl tar ca-certificates coreutils
    elif have apk; then
        run_privileged apk add --no-cache clang git curl tar ca-certificates coreutils
    else
        fail "missing system tools:$missing. Install them with your package manager and re-run this installer"
    fi
}

info "Checking build tools"
if [[ "$OS" == "Darwin" ]]; then
    ensure_macos_clt
else
    ensure_linux_deps
fi

if ! clang_works; then
    if [[ "${CAPY_SKIP_DEPS:-0}" == "1" ]]; then
        warn "clang is still missing; 'capy build' will fail until it is installed"
    else
        fail "clang is required to build Rey programs but is not available"
    fi
fi

sha256_file() {
    if have shasum; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif have sha256sum; then
        sha256sum "$1" | awk '{print $1}'
    else
        fail "shasum or sha256sum is required to verify the download"
    fi
}

manifest_value() {
    local key="$1"
    [[ -n "$MANIFEST" && -f "$MANIFEST" ]] || return 0
    sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$MANIFEST" | head -n 1
}

MANIFEST=""
MANIFEST_VERSION=""
VERSION_EXPLICIT=0
if [[ -n "${CAPY_VERSION:-}" ]]; then
    VERSION_EXPLICIT=1
    CAPY_VERSION="${CAPY_VERSION#v}"
fi

if [[ -z "${CAPY_ARCHIVE:-}" ]]; then
    MANIFEST_URL="${CAPY_UPDATE_MANIFEST:-$DEFAULT_MANIFEST_URL}"
    if [[ -f "$MANIFEST_URL" ]]; then
        cp "$MANIFEST_URL" "$TMP_DIR/latest.toml"
        MANIFEST="$TMP_DIR/latest.toml"
    elif have curl && curl -fsSL --max-time 15 "$MANIFEST_URL" -o "$TMP_DIR/latest.toml" 2>/dev/null; then
        MANIFEST="$TMP_DIR/latest.toml"
    fi
    if [[ -n "$MANIFEST" ]]; then
        MANIFEST_VERSION="$(manifest_value version)"
    fi
fi

if [[ -z "${CAPY_ARCHIVE:-}" ]]; then
    if [[ -z "${CAPY_VERSION:-}" ]]; then
        if [[ -n "$MANIFEST_VERSION" ]]; then
            CAPY_VERSION="$MANIFEST_VERSION"
        else
            info "Looking up the latest Capy release"
            LATEST_JSON="$(curl -fsSL --max-time 15 "https://api.github.com/repos/$REPO_SLUG/releases/latest" 2>/dev/null || true)"
            CAPY_VERSION="$(printf '%s\n' "$LATEST_JSON" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
            CAPY_VERSION="${CAPY_VERSION#v}"
        fi
    fi
    [[ -n "${CAPY_VERSION:-}" ]] || fail "could not determine the latest Capy release. Set CAPY_VERSION or CAPY_ARCHIVE and try again"
fi

if [[ -n "${CAPY_VERSION:-}" ]]; then
    [[ "$CAPY_VERSION" =~ ^[0-9A-Za-z._-]+$ ]] || fail "invalid Capy version: $CAPY_VERSION"
fi

ARCHIVE=""
ARCHIVE_URL=""
if [[ -n "${CAPY_ARCHIVE:-}" ]]; then
    [[ -f "$CAPY_ARCHIVE" ]] || fail "CAPY_ARCHIVE does not exist: $CAPY_ARCHIVE"
    ARCHIVE="$CAPY_ARCHIVE"
    info "Using local archive: $ARCHIVE"
else
    MANIFEST_ARCHIVE=""
    if [[ -n "$MANIFEST" ]]; then
        if [[ "$VERSION_EXPLICIT" -eq 0 || "$MANIFEST_VERSION" == "$CAPY_VERSION" ]]; then
            MANIFEST_ARCHIVE="$(manifest_value "$TARGET")"
        fi
    fi
    if [[ -n "${CAPY_ARCHIVE_URL:-}" ]]; then
        ARCHIVE_URL="$CAPY_ARCHIVE_URL"
    elif [[ -n "$MANIFEST_ARCHIVE" ]]; then
        ARCHIVE_URL="$MANIFEST_ARCHIVE"
    else
        ARCHIVE_URL="https://github.com/$REPO_SLUG/releases/download/v$CAPY_VERSION/capy-v$CAPY_VERSION-$TARGET.tar.gz"
    fi
    ARCHIVE="$TMP_DIR/capy.tar.gz"
    info "Downloading Capy $CAPY_VERSION for $TARGET"
    if ! curl -fL --retry 3 --connect-timeout 15 "$ARCHIVE_URL" -o "$ARCHIVE"; then
        fail "could not download $ARCHIVE_URL"
    fi
    if have curl; then
        curl -fsSL --max-time 30 "$ARCHIVE_URL.sha256" -o "$ARCHIVE.sha256" 2>/dev/null || rm -f "$ARCHIVE.sha256"
    fi
fi

EXPECTED_SHA=""
if [[ -n "$MANIFEST" ]]; then
    if [[ -z "${CAPY_ARCHIVE:-}" ]]; then
        if [[ "$VERSION_EXPLICIT" -eq 0 || "$MANIFEST_VERSION" == "$CAPY_VERSION" ]]; then
            EXPECTED_SHA="$(manifest_value "${TARGET}-sha256")"
        fi
    fi
fi

SIDECAR_SHA=""
if [[ -f "$ARCHIVE.sha256" ]]; then
    SIDECAR_SHA="$(awk 'NR == 1 {print $1}' "$ARCHIVE.sha256")"
fi
if [[ -n "$EXPECTED_SHA" && -n "$SIDECAR_SHA" && "$EXPECTED_SHA" != "$SIDECAR_SHA" ]]; then
    fail "checksum mismatch between latest.toml and $ARCHIVE.sha256"
fi
if [[ -z "$EXPECTED_SHA" ]]; then
    EXPECTED_SHA="$SIDECAR_SHA"
fi
if [[ -z "$EXPECTED_SHA" ]]; then
    if [[ "${CAPY_SKIP_VERIFY:-0}" == "1" ]]; then
        warn "no SHA-256 checksum found; continuing because CAPY_SKIP_VERIFY=1"
    else
        fail "no SHA-256 checksum found for $ARCHIVE. Set CAPY_SKIP_VERIFY=1 only if you trust this archive"
    fi
else
    ACTUAL_SHA="$(sha256_file "$ARCHIVE")"
    if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
        fail "SHA-256 checksum mismatch for $ARCHIVE"
    fi
    info "SHA-256 verified"
fi

EXTRACT_DIR="$TMP_DIR/extracted"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR"

SOURCE_DIR=""
for candidate in "$EXTRACT_DIR"/capy-v*-"$TARGET"; do
    if [[ -d "$candidate" ]]; then
        SOURCE_DIR="$candidate"
        break
    fi
done
[[ -n "$SOURCE_DIR" ]] || fail "archive does not contain a Capy release for $TARGET"
[[ -f "$SOURCE_DIR/bin/capy" ]] || fail "archive is missing bin/capy"
[[ -f "$SOURCE_DIR/libexec/toolchain/bin/rey" ]] || fail "archive is missing libexec/toolchain/bin/rey"
[[ -f "$SOURCE_DIR/libexec/toolchain/bin/runtime/librey_rt.a" ]] || fail "archive is missing the Rey runtime library"
[[ -d "$SOURCE_DIR/libexec/toolchain/std/src" ]] || fail "archive is missing the Rey standard library"

ARCHIVE_BASENAME="$(basename "$SOURCE_DIR")"
ARCHIVE_VERSION="${ARCHIVE_BASENAME#capy-v}"
ARCHIVE_VERSION="${ARCHIVE_VERSION%-"$TARGET"}"
[[ "$ARCHIVE_VERSION" =~ ^[0-9A-Za-z._-]+$ ]] || fail "archive has an invalid version: $ARCHIVE_VERSION"
if [[ -n "${CAPY_VERSION:-}" && "$CAPY_VERSION" != "$ARCHIVE_VERSION" ]]; then
    fail "CAPY_VERSION $CAPY_VERSION does not match archive version $ARCHIVE_VERSION"
fi
CAPY_VERSION="$ARCHIVE_VERSION"

ACTUAL_REY_VERSION="$("$SOURCE_DIR/libexec/toolchain/bin/rey" --version)" || fail "could not read the bundled Rey version"
[[ "$ACTUAL_REY_VERSION" == "rey "* ]] || fail "unexpected Rey version output: $ACTUAL_REY_VERSION"
ACTUAL_REY_VERSION="${ACTUAL_REY_VERSION#rey }"
if [[ -n "${REY_VERSION:-}" && "$REY_VERSION" != "$ACTUAL_REY_VERSION" ]]; then
    fail "REY_VERSION $REY_VERSION does not match bundled Rey $ACTUAL_REY_VERSION"
fi
REY_VERSION="$ACTUAL_REY_VERSION"
[[ "$REY_VERSION" =~ ^[0-9A-Za-z._-]+$ ]] || fail "archive has an invalid Rey version: $REY_VERSION"

info "Installing Capy $CAPY_VERSION with Rey $REY_VERSION"

mkdir -p "$(dirname "$CAPY_HOME")"

if [[ ! -e "$CAPY_HOME" && ! -L "$CAPY_HOME" ]] && [[ -e "$REY_HOME" || -L "$REY_HOME" ]]; then
    mv "$REY_HOME" "$CAPY_HOME"
    ln -s "$CAPY_HOME" "$REY_HOME"
    : > "$MARKER"
elif [[ -e "$CAPY_HOME" && ( -e "$REY_HOME" || -L "$REY_HOME" ) && ! -e "$MARKER" ]]; then
    [[ -d "$CAPY_HOME" ]] || fail "CAPY_HOME exists and is not a directory: $CAPY_HOME"
    for entry in "$REY_HOME"/* "$REY_HOME"/.[!.]* "$REY_HOME"/..?*; do
        [[ -e "$entry" || -L "$entry" ]] || continue
        name="${entry##*/}"
        if [[ ! -e "$CAPY_HOME/$name" && ! -L "$CAPY_HOME/$name" ]]; then
            cp -R "$entry" "$CAPY_HOME/$name"
        fi
    done

    backup_epoch="$(date +%s)"
    backup_path="$HOME/.rey.bak.$backup_epoch"
    while [[ -e "$backup_path" || -L "$backup_path" ]]; do
        backup_epoch="$((backup_epoch + 1))"
        backup_path="$HOME/.rey.bak.$backup_epoch"
    done
    mv "$REY_HOME" "$backup_path"
    ln -s "$CAPY_HOME" "$REY_HOME"
    : > "$MARKER"
fi

if [[ -e "$CAPY_HOME" && ! -d "$CAPY_HOME" ]]; then
    fail "CAPY_HOME exists and is not a directory: $CAPY_HOME"
fi
mkdir -p "$CAPY_HOME/bin" "$CAPY_HOME/cache" "$CAPY_HOME/store" "$CAPY_HOME/toolchains" "$CAPY_HOME/registry" "$CAPY_HOME/libexec"

BIN_STAGE="$CAPY_HOME/bin/.capy.new.$$"
cp "$SOURCE_DIR/bin/capy" "$BIN_STAGE"
chmod 755 "$BIN_STAGE"
mv -f "$BIN_STAGE" "$CAPY_HOME/bin/capy"

VERSIONED_TOOLCHAIN="$CAPY_HOME/toolchains/$REY_VERSION"
TOOLCHAIN_STAGE="$CAPY_HOME/toolchains/.$REY_VERSION.new.$$"
TOOLCHAIN_BACKUP="$CAPY_HOME/toolchains/.$REY_VERSION.old.$$"
rm -rf "$TOOLCHAIN_STAGE" "$TOOLCHAIN_BACKUP"
cp -R "$SOURCE_DIR/libexec/toolchain" "$TOOLCHAIN_STAGE"
chmod 755 "$TOOLCHAIN_STAGE/bin/rey"
if [[ -f "$TOOLCHAIN_STAGE/bin/rey.bin" ]]; then
    chmod 755 "$TOOLCHAIN_STAGE/bin/rey.bin"
fi
if [[ -f "$TOOLCHAIN_STAGE/bin/rey-v0" ]]; then
    chmod 755 "$TOOLCHAIN_STAGE/bin/rey-v0"
fi
if [[ -e "$VERSIONED_TOOLCHAIN" || -L "$VERSIONED_TOOLCHAIN" ]]; then
    mv "$VERSIONED_TOOLCHAIN" "$TOOLCHAIN_BACKUP"
fi
if ! mv "$TOOLCHAIN_STAGE" "$VERSIONED_TOOLCHAIN"; then
    if [[ -e "$TOOLCHAIN_BACKUP" || -L "$TOOLCHAIN_BACKUP" ]]; then
        mv "$TOOLCHAIN_BACKUP" "$VERSIONED_TOOLCHAIN"
    fi
    fail "could not install the Rey toolchain"
fi
rm -rf "$TOOLCHAIN_BACKUP"

CURRENT_LINK="$CAPY_HOME/toolchains/current"
if [[ -e "$CURRENT_LINK" && ! -L "$CURRENT_LINK" ]]; then
    current_backup_epoch="$(date +%s)"
    current_backup="$CAPY_HOME/toolchains/current.bak.$current_backup_epoch"
    while [[ -e "$current_backup" || -L "$current_backup" ]]; do
        current_backup_epoch="$((current_backup_epoch + 1))"
        current_backup="$CAPY_HOME/toolchains/current.bak.$current_backup_epoch"
    done
    mv "$CURRENT_LINK" "$current_backup"
fi
ln -sfn "$REY_VERSION" "$CURRENT_LINK"

LIBEXEC_LINK="$CAPY_HOME/libexec/toolchain"
if [[ -e "$LIBEXEC_LINK" && ! -L "$LIBEXEC_LINK" ]]; then
    rm -rf "$LIBEXEC_LINK"
fi
ln -sfn "../toolchains/current" "$LIBEXEC_LINK"

REY_LINK="$CAPY_HOME/bin/rey"
if [[ ! -e "$REY_LINK" && ! -L "$REY_LINK" ]]; then
    ln -s "../toolchains/current/bin/rey" "$REY_LINK"
elif [[ -L "$REY_LINK" ]]; then
    ln -sfn "../toolchains/current/bin/rey" "$REY_LINK"
fi

REYC_LINK="$CAPY_HOME/bin/reyc"
if [[ ! -e "$REYC_LINK" && ! -L "$REYC_LINK" ]]; then
    ln -s "rey" "$REYC_LINK"
elif [[ -L "$REYC_LINK" ]]; then
    ln -sfn "rey" "$REYC_LINK"
fi

mkdir -p "$HOME/.reyc"
STD_LINK="$HOME/.reyc/std"
STD_TARGET="$CAPY_HOME/toolchains/current/std"
if [[ ! -e "$STD_LINK" && ! -L "$STD_LINK" ]]; then
    ln -s "$STD_TARGET" "$STD_LINK"
elif [[ -L "$STD_LINK" ]]; then
    existing_target="$(readlink "$STD_LINK" || true)"
    case "$existing_target" in
        "$CAPY_HOME"/toolchains/*|"$CAPY_HOME"/libexec/*|"$HOME"/.capy/toolchains/*)
            ln -sfn "$STD_TARGET" "$STD_LINK"
            ;;
    esac
    if [[ ! -e "$STD_LINK" ]]; then
        ln -sfn "$STD_TARGET" "$STD_LINK"
    fi
else
    info "Leaving existing ~/.reyc/std in place"
fi

write_shell_profile() {
    local profile="$1"
    local temp_file="$profile.tmp.$$"
    local quoted_home

    mkdir -p "$(dirname "$profile")"
    if [[ -f "$profile" ]]; then
        awk -v begin="# >>> capy >>>" -v end="# <<< capy <<<" '
            $0 == begin { skip = 1; next }
            $0 == end { skip = 0; next }
            !skip { print }
        ' "$profile" > "$temp_file"
    else
        : > "$temp_file"
    fi

    printf -v quoted_home '%q' "$CAPY_HOME"
    {
        printf '%s\n' '# >>> capy >>>' "export CAPY_HOME=$quoted_home"
        cat <<'PROFILE_BLOCK'
_capy_bin="$CAPY_HOME/bin"
_capy_path_rest="${PATH:-}"
_capy_path_new=""
while [ -n "$_capy_path_rest" ]; do
    case "$_capy_path_rest" in
        *:*)
            _capy_path_entry="${_capy_path_rest%%:*}"
            _capy_path_rest="${_capy_path_rest#*:}"
            ;;
        *)
            _capy_path_entry="$_capy_path_rest"
            _capy_path_rest=""
            ;;
    esac
    if [ "$_capy_path_entry" != "$_capy_bin" ]; then
        if [ -n "$_capy_path_new" ]; then
            _capy_path_new="$_capy_path_new:$_capy_path_entry"
        else
            _capy_path_new="$_capy_path_entry"
        fi
    fi
done
export PATH="$_capy_bin${_capy_path_new:+:$_capy_path_new}"
unset _capy_bin _capy_path_rest _capy_path_new _capy_path_entry
PROFILE_BLOCK
        printf '%s\n' '# <<< capy <<<'
    } >> "$temp_file"
    mv "$temp_file" "$profile"
}

fish_quote() {
    local escaped
    escaped="$(printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\\\\\&/g")"
    printf "'%s'" "$escaped"
}

write_fish_profile() {
    local profile="$1"
    local temp_file="$profile.tmp.$$"
    local quoted_home

    mkdir -p "$(dirname "$profile")"
    if [[ -f "$profile" ]]; then
        awk -v begin="# >>> capy >>>" -v end="# <<< capy <<<" '
            $0 == begin { skip = 1; next }
            $0 == end { skip = 0; next }
            !skip { print }
        ' "$profile" > "$temp_file"
    else
        : > "$temp_file"
    fi

    quoted_home="$(fish_quote "$CAPY_HOME")"
    {
        printf '%s\n' '# >>> capy >>>' "set -gx CAPY_HOME $quoted_home"
        cat <<'FISH_BLOCK'
begin
    set -l _capy_path
    for _capy_path_entry in $PATH
        if test "$_capy_path_entry" != "$CAPY_HOME/bin"
            set -a _capy_path "$_capy_path_entry"
        end
    end
    set -gx PATH "$CAPY_HOME/bin" $_capy_path
end
FISH_BLOCK
        printf '%s\n' '# <<< capy <<<'
    } >> "$temp_file"
    mv "$temp_file" "$profile"
}

if [[ "${CAPY_SKIP_PROFILE:-0}" == "1" ]]; then
    info "Skipping shell profile changes (CAPY_SKIP_PROFILE=1)"
else
    write_shell_profile "$HOME/.zshrc"
    write_shell_profile "$HOME/.zprofile"
    write_shell_profile "$HOME/.bashrc"
    write_shell_profile "$HOME/.bash_profile"
    write_shell_profile "$HOME/.profile"
    if have fish || [[ -d "$HOME/.config/fish" ]]; then
        write_fish_profile "$HOME/.config/fish/config.fish"
    fi
fi

export CAPY_HOME
export PATH="$CAPY_HOME/bin:${PATH:-}"
hash -r 2>/dev/null || true

info "Verifying Capy installation"
"$CAPY_HOME/bin/capy" --version
if ! "$CAPY_HOME/bin/capy" doctor; then
    fail "Capy was installed, but 'capy doctor' reported a problem"
fi

printf '\nCapy %s installed with Rey %s\n' "$CAPY_VERSION" "$REY_VERSION"
printf '  capy:      %s\n' "$CAPY_HOME/bin/capy"
printf '  rey:       %s\n' "$CAPY_HOME/bin/rey"
printf '  toolchain: %s\n' "$VERSIONED_TOOLCHAIN"
printf '\nOpen a new terminal if capy is not on PATH, or run:\n'
printf '  export PATH="%s/bin:$PATH"\n' "$CAPY_HOME"
printf '\nNext steps:\n'
printf '  capy doctor\n'
printf '  capy init hello-capy\n'
printf '  cd hello-capy && capy run\n'
