#!/usr/bin/env bash
#
# install.sh — entry point for the custom Kali Linux build
#
# Usage:
#   ./install.sh                 interactive menu
#   ./install.sh --all           run every module, in order
#   ./install.sh --general       general desktop/daily-driver setup only
#   ./install.sh --bugbounty     bug bounty toolkit only
#   ./install.sh --ctf           CTF toolkit only
#   ./install.sh --dotfiles      symlink dotfiles only
#   ./install.sh --gnome         GNOME tweaks only (installs helper apps too)
#   ./install.sh --theme-pack    Tokyo Night aesthetic pack (opt-in, heavier —
#                                 see theme-pack.sh for what it installs)
#   ./install.sh --zsh           zsh + plugins only   (alias: --shell)
#   ./install.sh --theme         same as --theme-pack (alias); add --ember for the
#                                 red/orange palette instead of Tokyo Night blue/purple
#   ./install.sh --revert        undo GNOME/dotfiles changes (see revert.sh)
#   ./install.sh --dry-run       preview only, changes nothing: lists the modules that
#                                 would run, and for --gnome / --theme-pack shows each
#                                 setting's current -> new value
#
# Safe to re-run: every script is idempotent (checks before installing).
# GNOME settings and dotfiles are backed up automatically before any change
# — if something looks wrong afterward, run ./install.sh --revert or
# ./revert.sh directly. gnome-tweaks.sh at the repo root also works standalone
# if you just want the GNOME piece without the rest of this repo.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
DRY_RUN=0
THEME_ARGS=()

# A dry run must leave nothing behind — no logs/ directory, no log file.
for _arg in "$@"; do [[ "$_arg" == "--dry-run" ]] && DRY_RUN=1; done
if [[ $DRY_RUN -eq 1 ]]; then
    LOG_FILE=/dev/null
else
    mkdir -p "$LOG_DIR"
fi

# ---- colors ----------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${BLUE}[*]${NC} $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}[-]${NC} $*" | tee -a "$LOG_FILE"; }

# ---- sanity checks ----------------------------------------------------------
check_kali() {
    if ! grep -qi "kali" /etc/os-release 2>/dev/null; then
        warn "This doesn't look like Kali Linux. Continuing anyway, but some steps may fail."
    fi
}

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        err "Don't run this as root / with sudo. It will call sudo itself when it needs to."
        exit 1
    fi
}

check_sudo() {
    log "Requesting sudo — you'll be asked once, then it's cached for the session."
    sudo -v || { err "sudo auth failed"; exit 1; }
    # keep sudo alive in the background while the script runs
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
}

cleanup() {
    [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
}
trap cleanup EXIT

run_module() {
    local script="$1"
    local name="$2"
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  would run: $script"
        if [[ "$script" == "06-gnome-setup.sh" ]]; then
            bash "$REPO_ROOT/gnome-tweaks.sh" --dry-run
        fi
        return 0
    fi
    log "Running: $name"
    if bash "$SCRIPTS_DIR/$script" 2>&1 | tee -a "$LOG_FILE"; then
        ok "$name done"
    else
        err "$name failed — check $LOG_FILE, then re-run this module on its own"
    fi
}

usage() {
    awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
}

run_all() {
    run_module "01-system-update.sh"     "System update"
    run_module "02-general-tools.sh"     "General / daily-driver tools"
    run_module "03-bugbounty-tools.sh"   "Bug bounty toolkit"
    run_module "04-ctf-tools.sh"         "CTF toolkit"
    run_module "05-zsh-setup.sh"         "zsh + oh-my-zsh + plugins"
    run_module "06-gnome-setup.sh"       "GNOME tweaks"
    run_module "07-dotfiles-setup.sh"    "Dotfiles symlinks"
}

interactive_menu() {
    echo
    echo "=========================================="
    echo "  Custom Kali Setup — pick what to install"
    echo "=========================================="
    echo "  1) Everything (recommended for a fresh box)"
    echo "  2) System update only"
    echo "  3) General / daily-driver tools"
    echo "  4) Bug bounty toolkit"
    echo "  5) CTF toolkit"
    echo "  6) zsh + plugins"
    echo "  7) GNOME tweaks"
    echo "  8) Dotfiles symlinks"
    echo "  9) Tokyo Night theme pack (opt-in, heavier — see theme-pack.sh)"
    echo " 10) Revert GNOME/dotfiles/theme-pack changes"
    echo "  0) Exit"
    echo
    read -rp "Choice: " choice
    case "$choice" in
        1) run_all ;;
        2) run_module "01-system-update.sh" "System update" ;;
        3) run_module "02-general-tools.sh" "General tools" ;;
        4) run_module "03-bugbounty-tools.sh" "Bug bounty toolkit" ;;
        5) run_module "04-ctf-tools.sh" "CTF toolkit" ;;
        6) run_module "05-zsh-setup.sh" "zsh setup" ;;
        7) run_module "06-gnome-setup.sh" "GNOME tweaks" ;;
        8) run_module "07-dotfiles-setup.sh" "Dotfiles" ;;
        9) bash "$REPO_ROOT/theme-pack.sh" --all ;;
        10) bash "$REPO_ROOT/revert.sh" ;;
        0) exit 0 ;;
        *) warn "Invalid choice"; interactive_menu ;;
    esac
}

main() {
    check_not_root
    check_kali

    if [[ $# -eq 0 ]]; then
        check_sudo
        interactive_menu
        exit 0
    fi

    local normalized=()
    for arg in "$@"; do
        case "$arg" in
            --shell) normalized+=(--zsh) ;;
            --theme) normalized+=(--theme-pack) ;;
            *)       normalized+=("$arg") ;;
        esac
    done
    set -- "${normalized[@]}"

    for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=1; done

    for arg in "$@"; do
        case "$arg" in
            --ember)      THEME_ARGS+=(--ember) ;;
            --all)        NEED_SUDO=1 ;;
            --general)    NEED_SUDO=1 ;;
            --bugbounty)  NEED_SUDO=1 ;;
            --ctf)        NEED_SUDO=1 ;;
            --zsh)        NEED_SUDO=1 ;;
            --gnome)      NEED_SUDO=1 ;;
            --theme-pack) NEED_SUDO=1 ;;
            --dotfiles)   ;;
            --revert)
                if [[ $DRY_RUN -eq 1 ]]; then
                    echo "  would open the revert menu (revert.sh). To preview exactly what a revert"
                    echo "  restores: ./gnome-tweaks.sh --revert --dry-run   (same for theme-pack.sh"
                    echo "  and sync-burn-color.sh)"
                else
                    bash "$REPO_ROOT/revert.sh"
                fi
                exit 0
                ;;
            --dry-run)    DRY_RUN=1 ;;
            -h|--help)    usage; exit 0 ;;
            *) err "Unknown option: $arg"; usage; exit 1 ;;
        esac
    done

    [[ "${NEED_SUDO:-0}" -eq 1 && $DRY_RUN -eq 0 ]] && check_sudo

    for arg in "$@"; do
        case "$arg" in
            --all)        run_all ;;
            --general)    run_module "02-general-tools.sh" "General tools" ;;
            --bugbounty)  run_module "03-bugbounty-tools.sh" "Bug bounty toolkit" ;;
            --ctf)        run_module "04-ctf-tools.sh" "CTF toolkit" ;;
            --zsh)        run_module "05-zsh-setup.sh" "zsh setup" ;;
            --gnome)      run_module "06-gnome-setup.sh" "GNOME tweaks" ;;
            --dotfiles)   run_module "07-dotfiles-setup.sh" "Dotfiles" ;;
            --theme-pack)
                if [[ $DRY_RUN -eq 1 ]]; then
                    bash "$REPO_ROOT/theme-pack.sh" --all "${THEME_ARGS[@]}" --dry-run
                else
                    bash "$REPO_ROOT/theme-pack.sh" --all "${THEME_ARGS[@]}"
                fi
                ;;
        esac
    done

    if [[ $DRY_RUN -eq 1 ]]; then
        echo
        echo "Dry run: nothing was changed. Note — for the package modules (01-05) this only"
        echo "lists which step would run; it doesn't enumerate individual packages."
    fi
}

main "$@"
