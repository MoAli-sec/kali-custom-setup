#!/usr/bin/env bash
#
# revert.sh — one place to undo everything this repo's scripts changed
#
# Usage:
#   ./revert.sh                 interactive menu
#   ./revert.sh --gnome         revert GNOME settings only (latest backup)
#   ./revert.sh --dotfiles      revert dotfiles only (latest backup)
#   ./revert.sh --theme-pack    revert theme-pack (removes installed themes,
#                                fastfetch/conky config, Burn My Windows)
#   ./revert.sh --burn-color    revert sync-burn-color.sh's fire color change
#   ./revert.sh --all           revert all four (latest backups)
#   ./revert.sh --list-backups  show every backup available, all kinds
#
# For a SPECIFIC (non-latest) backup, use the underlying scripts directly:
#   ./gnome-tweaks.sh --revert <name>
#   ./scripts/07-dotfiles-setup.sh --revert <name>
# (--list-backups on this script shows you the names.)
#
# This script never touches installed packages — apt/go-installed tools
# are left alone. It only undoes configuration changes: dconf/GNOME
# settings and the dotfiles symlinks, since those are the only things
# that get silently overwritten without you asking each time.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "[*] $*" >&2; }
ok()   { echo -e "${GREEN}[+]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $*" >&2; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

revert_gnome() {
    if [[ ! -f "$REPO_ROOT/gnome-tweaks.sh" ]]; then
        err "Can't find gnome-tweaks.sh at repo root."
        return 1
    fi
    bash "$REPO_ROOT/gnome-tweaks.sh" --revert
}

revert_dotfiles() {
    if [[ ! -f "$REPO_ROOT/scripts/07-dotfiles-setup.sh" ]]; then
        err "Can't find scripts/07-dotfiles-setup.sh."
        return 1
    fi
    bash "$REPO_ROOT/scripts/07-dotfiles-setup.sh" --revert
}

revert_theme_pack() {
    if [[ ! -f "$REPO_ROOT/theme-pack.sh" ]]; then
        err "Can't find theme-pack.sh at repo root."
        return 1
    fi
    bash "$REPO_ROOT/theme-pack.sh" --revert
}

revert_burn_color() {
    if [[ ! -f "$REPO_ROOT/sync-burn-color.sh" ]]; then
        err "Can't find sync-burn-color.sh at repo root."
        return 1
    fi
    bash "$REPO_ROOT/sync-burn-color.sh" --revert
}

list_backups() {
    echo "== GNOME backups (shared with theme-pack) =="
    bash "$REPO_ROOT/gnome-tweaks.sh" --list-backups 2>/dev/null || warn "none"
    echo
    echo "== Dotfiles backups =="
    bash "$REPO_ROOT/scripts/07-dotfiles-setup.sh" --list-backups 2>/dev/null || warn "none"
}

interactive_menu() {
    echo
    echo "=========================================="
    echo "  Revert — undo changes made by this repo"
    echo "=========================================="
    echo "  1) Revert GNOME settings (latest backup)"
    echo "  2) Revert dotfiles (latest backup)"
    echo "  3) Revert theme-pack (themes, fastfetch/conky, Burn My Windows)"
    echo "  4) Revert fire color sync (sync-burn-color.sh)"
    echo "  5) Revert all four"
    echo "  6) List all available backups"
    echo "  0) Cancel"
    echo
    read -rp "Choice: " choice
    case "$choice" in
        1) revert_gnome ;;
        2) revert_dotfiles ;;
        3) revert_theme_pack ;;
        4) revert_burn_color ;;
        5) revert_gnome; revert_dotfiles; revert_theme_pack; revert_burn_color ;;
        6) list_backups ;;
        0) exit 0 ;;
        *) warn "Invalid choice"; interactive_menu ;;
    esac
}

usage() {
    grep '^#' "$0" | sed -n '2,17p' | sed 's/^# \{0,1\}//'
}

main() {
    if [[ $# -eq 0 ]]; then
        interactive_menu
        exit 0
    fi

    case "$1" in
        --gnome)        revert_gnome ;;
        --dotfiles)     revert_dotfiles ;;
        --theme-pack)   revert_theme_pack ;;
        --burn-color)   revert_burn_color ;;
        --all)          revert_gnome; revert_dotfiles; revert_theme_pack; revert_burn_color ;;
        --list-backups) list_backups ;;
        -h|--help)      usage ;;
        *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
}

main "$@"
