#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
CHECK="${GREEN}✔${NC}"; CROSS="${RED}✖${NC}"; INFO="${CYAN}➜${NC}"; WARN="${YELLOW}⚠${NC}"

RIPTIDE_VERSION="1.0.28"
# What this is: the Riptide app bundle (the editor GUI plus the executor
# dylib), zipped. It is hosted on an anonymous file host so the download link
# stays private to this group — it is not malware. The zip is checksummed by
# PAYLOAD_MD5 below, and that check runs before anything is installed.
PAYLOAD_URL="https://files.catbox.moe/wyhmtw.zip"
PAYLOAD_MD5="f937ec7d35040033fdbfa4207a16fcfb"
RBX_VERSION="version-5b15515e80624095"
RBX_PLAYER="0.738.0.7381393"
RBX_URL="https://setup.rbxcdn.com/mac/${RBX_VERSION}-RobloxPlayer.zip"
RBX_MD5="200789e817ab4ed6fbe45632db2bcbdb"
INSTALLER_URL="https://raw.githubusercontent.com/cocoBEAMS/riptide-installer/main/install.sh"

if [ -w "/Applications" ]; then
  APP_DIR="/Applications"
else
  APP_DIR="$HOME/Applications"
fi

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

verify_md5() {
  local got
  got="$(/sbin/md5 -q "$1" 2>/dev/null || md5 -q "$1")"
  [ "$got" = "$2" ] || { echo -e "${CROSS} $3 failed the md5 check (got $got, expected $2)"; exit 1; }
}
export -f verify_md5

banner() {
  clear
  echo -e "${BOLD}${CYAN}"
  cat <<'EOF'
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   ____  ___ _____ ____  _____ ____  _____
  |  _ \|_ _|_   _|  _ \| ____|  _ \| ____|
  | |_) || |  | | | |_) |  _| | | | |  _|
  |  _ < | |  | | |  __/| |___| |_| | |___
  |_| \_\___| |_| |_|   |_____|____/|_____|
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EOF
  echo -e "${NC}"
  echo -e "${MAGENTA}${BOLD}  ╭──────────────────────────────────────────────────────────────╮${NC}"
  echo -e "${MAGENTA}${BOLD}  │${NC}   ${CYAN}${BOLD}RIPTIDE EXECUTOR${NC}${MAGENTA}${BOLD}                                       │${NC}"
  echo -e "${MAGENTA}${BOLD}  │${NC}   ${CYAN}The latest macOS executor on the market${NC}${MAGENTA}${BOLD}       │${NC}"
  echo -e "${MAGENTA}${BOLD}  │${NC}   version ${GREEN}${BOLD}$RIPTIDE_VERSION${NC}${MAGENTA}${BOLD}   ·   liquid glass, no neon${NC}${MAGENTA}${BOLD}     │${NC}"
  echo -e "${MAGENTA}${BOLD}  ╰──────────────────────────────────────────────────────────────╯${NC}"
  echo
}

surf_report() {
  echo
  echo -e "${GREEN}${BOLD}   ╔═════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}   ║${NC}   ${GREEN}${BOLD}RIPTIDE $RIPTIDE_VERSION installed${NC}${GREEN}${BOLD}              ║${NC}"
  echo -e "${GREEN}${BOLD}   ║${NC}   ${GREEN}The latest macOS executor on the market${NC}${GREEN}${BOLD}  ║${NC}"
  echo -e "${GREEN}${BOLD}   ║${NC}   ${GREEN}Roblox pinned · injection ready${NC}${GREEN}${BOLD}              ║${NC}"
  echo -e "${GREEN}${BOLD}   ╚═════════════════════════════════════════════════╝${NC}"
}

do_uninstall() {
  banner
  section "Uninstalling Riptide"
  killall -9 RobloxCrashHandler RobloxMenuBar RobloxPlayer Roblox Riptide 2>/dev/null || true
  run_step "Removing Riptide.app" bash -c "
    rm -rf '$APP_DIR/Riptide.app' 2>/dev/null || sudo rm -rf '$APP_DIR/Riptide.app'
    [ ! -e '$APP_DIR/Riptide.app' ]
  "
  rm -rf "$HOME/Library/Application Support/Riptide" 2>/dev/null || true
  rm -f "$HOME/Library/Preferences/com.riptide.executor.gui.plist" 2>/dev/null || true
  echo
  echo -e "${GREEN}${BOLD}Riptide has been removed.${NC}"
  echo -e "${WARN} Roblox is untouched and still patched. Restore stock Roblox with:"
  echo "  curl -fsSL $INSTALLER_URL | bash"
}

case "${1:-}" in
  --uninstall|--remove)
    do_uninstall
    exit 0
    ;;
esac

main() {
  banner

  echo -e "${INFO} Dropping into ${BOLD}$APP_DIR${NC}"

  TEMP="$(mktemp -d)"
  trap 'rm -rf "$TEMP"' EXIT

  section "Closing Roblox"
  run_step "Killing Roblox processes" bash -c \
    'killall -9 RobloxCrashHandler RobloxMenuBar RobloxPlayer Roblox 2>/dev/null || true'

  section "Removing previous installs"
  for target in "$APP_DIR/Roblox.app" "$APP_DIR/Riptide.app"; do
    [ -e "$target" ] || continue
    name="$(basename "$target")"
    rm -rf "$target" 2>/dev/null || true
    if [ -e "$target" ]; then
      echo -e "${WARN} Removing $name needs root..."
      sudo rm -rf "$target" 2>/dev/null || true
    fi
    if [ -e "$target" ]; then
      echo -e "${CROSS} Could not remove $name — please delete it by hand, then re-run."
      exit 1
    fi
    echo -e "${CHECK} Removed $name"
  done

  section "Preparing Roblox $RBX_PLAYER"
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

  section "Setting up the workspace"
  mkdir -p "$HOME/Documents/Riptide/workspace" "$HOME/Documents/Riptide/autoexec"
  echo -e "${CHECK} ~/Documents/Riptide/workspace + autoexec ready"

  surf_report
  echo -e "${INFO} Update later:  curl -fsSL $INSTALLER_URL | bash"
  echo -e "${INFO} Uninstall:    $0 --uninstall"

  open "$APP_DIR/Roblox.app"
  open "$APP_DIR/Riptide.app"
}

main "$@"