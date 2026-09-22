#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  Riptide installer — public script, anonymous payload host, no tokens.
#
#  This file is the single public entry point. It carries the whole release:
#  the pinned Roblox version and the payload URL (an unguessable anonymous
#  link). Nothing in it is a credential, so it can live on a public repo and
#  be piped straight into bash:
#
#      curl -fsSL https://raw.githubusercontent.com/cocoBEAMS/riptide-installer/main/install.sh | bash
#
#  The payload link is the shared secret of the release; revoke a leak by
#  re-uploading the zip (new link, new md5) and updating this file.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
CHECK="${GREEN}✔${NC}"; CROSS="${RED}✖${NC}"; INFO="${CYAN}➜${NC}"; WARN="${YELLOW}⚠${NC}"

# ─── release definition (edit me on every release) ─────────────────────────
RIPTIDE_VERSION="1.0.27"
PAYLOAD_URL="https://files.catbox.moe/uvnv2l.zip"          # Riptide.app.zip
PAYLOAD_MD5="8938d834df224b8c8444243d576ef673"
RBX_VERSION="version-5b15515e80624095"                     # supported Roblox pin
RBX_PLAYER="0.738.0.7381393"
RBX_URL="https://setup.rbxcdn.com/mac/${RBX_VERSION}-RobloxPlayer.zip"
RBX_MD5="200789e817ab4ed6fbe45632db2bcbdb"

# The public URL this script is served from — used to tell people how to update.
INSTALLER_URL="https://raw.githubusercontent.com/cocoBEAMS/riptide-installer/main/install.sh"

section() { echo; echo -e "${BOLD}${CYAN}==> $1${NC}"; }

run_step() {
    local msg="$1"; shift
    echo -ne "${CYAN}[...]${NC} $msg\r"
    if "$@"; then
        printf "\r\033[K${CHECK} %s\n" "$msg"
    else
        printf "\r\033[K${CROSS} %s\n" "$msg"
        exit 1
    fi
}

verify_md5() { # file expected label
    local got
    got="$(/sbin/md5 -q "$1" 2>/dev/null || md5 -q "$1")"
    [ "$got" = "$2" ] || { echo -e "${CROSS} $3 failed the md5 check (got $got, expected $2)"; exit 1; }
}
export -f verify_md5   # reachable from the run_step subshells

banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat <<'EOF'
 ____  ___ _____ ____  _____ ____  _____ 
|  _ \|_ _|_   _|  _ \| ____|  _ \| ____|
| |_) || |  | | | |_) |  _| | | | |  _|  
|  _ < | |  | | |  __/| |___| |_| | |___ 
|_| \_\___| |_| |_|   |_____|____/|_____|
EOF
    echo -e "${NC}"
    echo -e "${BLUE}=[ Riptide $RIPTIDE_VERSION Installer ]=${NC}"
    echo -e "${CYAN}Jet-black · no neon · private by payload\n${NC}"
}

main() {
    banner

    if [ -w "/Applications" ]; then
        APP_DIR="/Applications"
        echo -e "${INFO} Installing to /Applications"
    else
        APP_DIR="$HOME/Applications"
        mkdir -p "$APP_DIR"
        echo -e "${WARN} Using $APP_DIR (no root access)"
    fi

    TEMP="$(mktemp -d)"
    trap 'rm -rf "$TEMP"' EXIT

    section "Closing Roblox"
    run_step "Killing Roblox processes" bash -c \
        'killall -9 RobloxCrashHandler RobloxMenuBar RobloxPlayer Roblox 2>/dev/null || true'

    section "Removing old installs"
    for target in "$APP_DIR/Roblox.app" "$APP_DIR/Riptide.app"; do
        [ -e "$target" ] || continue
        name="$(basename "$target")"
        rm -rf "$target" 2>/dev/null || true
        if [ -e "$target" ]; then
            echo -e "${WARN} Removing $name needs root..."
            sudo rm -rf "$target" 2>/dev/null || true
        fi
        if [ -e "$target" ]; then
            echo -e "${CROSS} Failed to remove $name, please delete it manually."
            exit 1
        fi
        echo -e "${CHECK} Removed $name"
    done

    section "Downloading Roblox $RBX_PLAYER"
    run_step "Downloading Roblox (~140 MB)" bash -c "
        curl -# -L '$RBX_URL' -o '$TEMP/Roblox.zip' &&
        verify_md5 '$TEMP/Roblox.zip' '$RBX_MD5' 'Roblox' &&
        unzip -oq '$TEMP/Roblox.zip' -d '$TEMP' &&
        rm -rf '$APP_DIR/Roblox.app' &&
        mv '$TEMP/RobloxPlayer.app' '$APP_DIR/Roblox.app' &&
        xattr -dr com.apple.quarantine '$APP_DIR/Roblox.app' &&
        codesign --remove-signature '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayer'
    "

    section "Installing Riptide $RIPTIDE_VERSION"
    run_step "Downloading the Riptide payload" bash -c "
        curl -# -L '$PAYLOAD_URL' -o '$TEMP/Riptide.zip' &&
        verify_md5 '$TEMP/Riptide.zip' '$PAYLOAD_MD5' 'Riptide' &&
        unzip -oq '$TEMP/Riptide.zip' -d '$TEMP' &&
        rm -rf '$APP_DIR/Riptide.app' &&
        mv '$TEMP/Riptide.app' '$APP_DIR/Riptide.app' &&
        xattr -dr com.apple.quarantine '$APP_DIR/Riptide.app'
    "

    # The bundled patcher swaps a weak load command into RobloxPlayer, like the
    # reference executor's Injector - same result, one self-contained binary.
    section "Patching RobloxPlayer"
    run_step "Injecting libRiptide.dylib" bash -c "
        rm -rf '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayerInstaller.app' &&
        rm -rf '$APP_DIR/Roblox.app/Contents/MacOS/RobloxMenuBar.app' &&
        '$APP_DIR/Riptide.app/Contents/Resources/riptide-machopatch' \
            --binary '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayer' \
            --dylib '$APP_DIR/Riptide.app/Contents/Resources/libRiptide.dylib' &&
        rm -f '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayer.unix-backup' &&
        codesign --force -s - '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayer'
    "

    section "Workspace"
    mkdir -p "$HOME/Documents/Riptide/workspace" "$HOME/Documents/Riptide/autoexec"
    echo -e "${CHECK} ~/Documents/Riptide/workspace + autoexec ready"

    echo
    echo -e "${GREEN}${BOLD}Riptide $RIPTIDE_VERSION installed.${NC}"
    echo -e "${CHECK} Roblox pinned to $RBX_PLAYER (self-updater removed)"
    echo -e "${INFO} Update later:  curl -fsSL $INSTALLER_URL | bash"

    open "$APP_DIR/Roblox.app"
    open "$APP_DIR/Riptide.app"
}

main "$@"