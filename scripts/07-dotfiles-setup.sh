#!/usr/bin/env bash
#
# 07-dotfiles-setup.sh — symlink dotfiles from the repo into $HOME
#
# Usage:
#   ./07-dotfiles-setup.sh                 back up + symlink dotfiles
#   ./07-dotfiles-setup.sh --list-backups   show every backup made
#   ./07-dotfiles-setup.sh --revert         undo — restore the most recent
#                                            pre-symlink state
#   ./07-dotfiles-setup.sh --revert NAME    restore a specific backup
#
# Every file that already existed before symlinking is moved (not deleted)
# into ~/.kali-custom-setup-backups/dotfiles/<timestamp>/, along with a
# manifest.txt recording where each one came from — so --revert knows
# exactly how to put things back, including files that DIDN'T exist before
# (those just get their symlink removed, nothing restored).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="$REPO_ROOT/dotfiles"
BACKUP_ROOT="$HOME/.kali-custom-setup-backups/dotfiles"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "[*] $*" >&2; }
ok()   { echo -e "${GREEN}[+]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $*" >&2; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

# The set of dotfiles this script manages: "source-in-repo|destination-in-home"
DOTFILE_MAP=(
    "$DOTFILES_DIR/zsh/.zshrc|$HOME/.zshrc"
    "$DOTFILES_DIR/zsh/aliases.zsh|$HOME/.zsh/aliases.zsh"
    "$DOTFILES_DIR/zsh/functions.zsh|$HOME/.zsh/functions.zsh"
    "$DOTFILES_DIR/zsh/exports.zsh|$HOME/.zsh/exports.zsh"
    "$DOTFILES_DIR/tmux/.tmux.conf|$HOME/.tmux.conf"
    "$DOTFILES_DIR/git/.gitconfig|$HOME/.gitconfig"
)

# ---- install (backup + symlink) ---------------------------------------------
install_dotfiles() {
    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    local backup_dir="$BACKUP_ROOT/$ts"
    local manifest="$backup_dir/manifest.txt"
    local backed_up_anything=0

    mkdir -p "$HOME/.zsh"

    for pair in "${DOTFILE_MAP[@]}"; do
        local src="${pair%%|*}"
        local dest="${pair##*|}"

        if [[ -L "$dest" ]]; then
            info "$dest already symlinked — leaving as is"
            continue
        fi

        if [[ -e "$dest" ]]; then
            mkdir -p "$backup_dir"
            local backup_name
            backup_name="$(echo "$dest" | sed 's|^/||; s|/|__|g')"
            mv "$dest" "$backup_dir/$backup_name"
            echo "$backup_dir/$backup_name|$dest" >> "$manifest"
            backed_up_anything=1
            info "backed up existing $dest"
        fi

        ln -s "$src" "$dest"
        ok "linked $dest -> $src"
    done

    if [[ $backed_up_anything -eq 1 ]]; then
        echo "$ts" > "$BACKUP_ROOT/.latest"
        ok "Backup of anything overwritten is in: $backup_dir"
        echo "    Undo any time with: $0 --revert"
    else
        info "Nothing pre-existing needed backing up."
    fi

    ok "Dotfiles linked. Open a new terminal (or 'exec zsh') to pick up the changes."
}

# ---- list / revert ------------------------------------------------------------
list_backups() {
    if [[ ! -d "$BACKUP_ROOT" ]] || [[ -z "$(ls -A "$BACKUP_ROOT" 2>/dev/null)" ]]; then
        warn "No dotfiles backups found yet."
        return
    fi
    echo "Available dotfiles backups (newest last):"
    for d in "$BACKUP_ROOT"/*/; do
        [[ -d "$d" ]] || continue
        basename "$d" | sed 's/^/  - /'
    done
    if [[ -f "$BACKUP_ROOT/.latest" ]]; then
        echo
        echo "Latest: $(cat "$BACKUP_ROOT/.latest")"
    fi
}

# Resolves a requested backup name to one that actually exists and is usable
# (has $required_file in it). Falls back to listing real backups and asking
# if the requested one is missing/stale — e.g. it was deleted by hand, or
# came from a run that got interrupted before finishing. Prints the chosen
# name on stdout; everything else (prompts, warnings) goes to stderr so it
# doesn't get captured by command substitution.
resolve_backup_target() {
    local desired="$1" required_file="$2"

    if [[ -n "$desired" && -f "$BACKUP_ROOT/$desired/$required_file" ]]; then
        echo "$desired"
        return 0
    fi

    if [[ -n "$desired" ]]; then
        warn "Backup '$desired' isn't usable (missing, or from a run that didn't finish) — looking for another one."
    fi

    local candidates=()
    for d in "$BACKUP_ROOT"/*/; do
        [[ -f "$d$required_file" ]] && candidates+=("$(basename "$d")")
    done
    if [[ ${#candidates[@]} -eq 0 ]]; then
        err "No valid backups exist — nothing to revert to."
        exit 1
    fi

    mapfile -t candidates < <(printf '%s\n' "${candidates[@]}" | sort)
    local newest="${candidates[-1]}"

    echo "Available backups:" >&2
    local i=1
    for c in "${candidates[@]}"; do
        echo "  $i) $c" >&2
        ((i++))
    done
    read -rp "Pick a number, or press Enter to use the most recent ($newest): " choice
    if [[ -z "$choice" ]]; then
        echo "$newest"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#candidates[@]} )); then
        echo "${candidates[$((choice-1))]}"
    else
        err "Invalid choice — aborting."
        exit 1
    fi
}

revert() {
    local target="${1:-}"
    if [[ -z "$target" && -f "$BACKUP_ROOT/.latest" ]]; then
        target="$(cat "$BACKUP_ROOT/.latest")"
    fi
    target="$(resolve_backup_target "$target" "manifest.txt")"  || exit 1  # resolve_backup_target already printed the error

    local backup_dir="$BACKUP_ROOT/$target"
    local manifest="$backup_dir/manifest.txt"

    warn "This will remove the dotfiles symlinks this script created and restore"
    warn "whatever was there before (backup: $target)."
    read -rp "Continue? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled — nothing changed."
        exit 0
    fi

    # first, remove every symlink this script could have created, whether or
    # not it has a backed-up original (no backup = the file didn't exist before)
    for pair in "${DOTFILE_MAP[@]}"; do
        local dest="${pair##*|}"
        if [[ -L "$dest" ]]; then
            rm "$dest"
            info "removed symlink $dest"
        fi
    done

    # then restore anything that WAS backed up
    if [[ -f "$manifest" ]]; then
        while IFS='|' read -r backup_path original_dest; do
            [[ -z "$backup_path" ]] && continue
            mkdir -p "$(dirname "$original_dest")"
            mv "$backup_path" "$original_dest"
            ok "restored $original_dest"
        done < "$manifest"
    fi

    ok "Reverted to pre-dotfiles state from backup: $target"
}

usage() {
    grep '^#' "$0" | sed -n '2,14p' | sed 's/^# \{0,1\}//'
}

# ---- main ---------------------------------------------------------------------
main() {
    if [[ $# -eq 0 ]]; then
        install_dotfiles
        exit 0
    fi

    case "$1" in
        --list-backups)
            list_backups
            ;;
        --revert)
            revert "${2:-}"
            ;;
        -h|--help)
            usage
            ;;
        *)
            err "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
