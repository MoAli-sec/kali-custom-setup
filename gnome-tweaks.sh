#!/usr/bin/env bash
#
# gnome-tweaks.sh — standalone GNOME tweaks with automatic backup + revert
#
# This file has no dependency on the rest of the kali-custom-setup repo —
# download just this one file and run it if that's all you want.
#
# Usage:
#   ./gnome-tweaks.sh                 back up current settings, then apply
#                                      the SAFE tweaks only (see below)
#   ./gnome-tweaks.sh --dark-mode      also switch to dark mode / dark theme
#   ./gnome-tweaks.sh --dock          also apply opinionated Dash to Dock
#                                      settings (position/size/autohide)
#   ./gnome-tweaks.sh --font          also install + set Fira Code as the
#                                      monospace/terminal font (opt-in — the
#                                      only tweak here that needs sudo, since
#                                      it installs a package)
#   ./gnome-tweaks.sh --all           safe tweaks + dark mode + dock + font
#   ./gnome-tweaks.sh --dry-run       with any option above: show each setting's
#                                      current value -> new value, change nothing,
#                                      make no backup, install nothing
#   ./gnome-tweaks.sh --list-backups  show every backup this script has made
#   ./gnome-tweaks.sh --revert        restore the most recent backup
#   ./gnome-tweaks.sh --revert NAME   restore a specific backup (see
#                                      --list-backups for names)
#
# WHY THIS IS SPLIT INTO SAFE vs OPT-IN:
# The two things most likely to visibly change your desktop in a way you
# might not want are (a) forcing dark mode / a specific GTK theme, and
# (b) rewriting your Dash to Dock config over whatever you already had
# tuned. So neither runs unless you explicitly ask for it. Everything
# else (screensaver/idle timing, clock display, a couple of window-manager
# details) is low-risk and runs by default.
#
# BACKUPS: every gsettings key this script is ABOUT to change gets its
# CURRENT value recorded first (one line per key, in
# ~/.kali-custom-setup-backups/gnome/<timestamp>/settings.tsv) before the
# new value is applied. --revert reads that file back and restores each
# exact key — nothing else. It deliberately does NOT touch any broader
# dconf state (like which extensions are enabled) — an earlier version of
# this script did a wholesale `dconf reset` + reload of the entire
# /org/gnome/ tree on revert, which could revert things this script never
# touched at all (like disabling an unrelated extension), and risked
# destabilizing an active session by wiping a huge swath of live settings
# at once. This version only ever touches the specific keys it itself set.

set -uo pipefail

BACKUP_ROOT="$HOME/.kali-custom-setup-backups/gnome"
LATEST_FILE=".latest-gnome-tweaks"   # this script's own pointer (theme-pack has its own)
DRY_RUN=0

# ---- helpers ----------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "[*] $*" >&2; }
ok()   { echo -e "${GREEN}[+]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $*" >&2; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

# "X applied." normally; "X previewed" in a dry run, so output never claims
# something was applied when it wasn't.
applied() {
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] previewed: $1 (nothing changed)"
    else
        ok "$1 applied."
    fi
}

require_gsettings() {
    if ! command -v gsettings &>/dev/null; then
        err "gsettings not found — this doesn't look like a GNOME session. Aborting."
        exit 1
    fi
}

# NOTE: no `grep -q` here on purpose. -q makes grep exit at the first match, so
# the upstream command can get SIGPIPE, and under `set -o pipefail` that turns
# a successful lookup into a false "not found" (measured: ~20% false negatives).
schema_exists() {
    gsettings list-schemas 2>/dev/null | grep -x "$1" >/dev/null
}

# Tracked set: records the CURRENT value of a specific key (only the first
# time this run touches it) before applying a new one, so --revert can put
# back exactly this key — nothing broader. Always use this instead of a bare
# `gsettings set` for anything that should be revertible.
tset() {
    local schema="$1" key="$2" new_value="$3"
    local old_value
    old_value="$(gsettings get "$schema" "$key" 2>/dev/null)"
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  %-52s %s  ->  %s\n' "$schema $key" "${old_value:-<unset>}" "$new_value" >&2
        return 0
    fi
    if [[ -n "$old_value" ]] && [[ -n "${SETTINGS_MANIFEST:-}" ]]; then
        if ! grep -qF "$(printf 'gsettings\t%s\t%s\t' "$schema" "$key")" "$SETTINGS_MANIFEST" 2>/dev/null; then
            printf 'gsettings\t%s\t%s\t%s\n' "$schema" "$key" "$old_value" >> "$SETTINGS_MANIFEST"
        fi
    fi
    gsettings set "$schema" "$key" "$new_value"
}

# ---- backup -------------------------------------------------------------------
# Safe to run twice: if the previous run was never reverted, the "original"
# values it recorded are still the TRUE originals — so they are carried forward
# into this run's backup. Reverting then always returns you to the state before
# the FIRST run, instead of to a middle state that already had our changes.
# Once a run is reverted it gets a REVERTED marker and the chain starts fresh.
make_backup() {
    local ts prev="" dir n=0
    ts="$(date +%Y%m%d-%H%M%S)"
    dir="$BACKUP_ROOT/$ts"
    while [[ -e "$dir" ]]; do n=$((n+1)); dir="$BACKUP_ROOT/${ts}-$n"; done
    [[ -f "$BACKUP_ROOT/$LATEST_FILE" ]] && prev="$(cat "$BACKUP_ROOT/$LATEST_FILE")"
    mkdir -p "$dir"
    : > "$dir/settings.tsv"
    if [[ -n "$prev" && -f "$BACKUP_ROOT/$prev/settings.tsv" && ! -f "$BACKUP_ROOT/$prev/REVERTED" ]]; then
        cp "$BACKUP_ROOT/$prev/settings.tsv" "$dir/settings.tsv"
        echo "$prev" > "$dir/CHAINED_FROM"
    fi
    basename "$dir" > "$BACKUP_ROOT/$LATEST_FILE"
    echo "$dir"
}

# Marks a backup — and every earlier run it was chained from — as reverted.
mark_reverted() {
    local d="$BACKUP_ROOT/$1"
    while [[ -n "$d" && -d "$d" ]]; do
        touch "$d/REVERTED"
        if [[ -f "$d/CHAINED_FROM" ]]; then d="$BACKUP_ROOT/$(cat "$d/CHAINED_FROM")"; else d=""; fi
    done
}

list_backups() {
    if [[ ! -d "$BACKUP_ROOT" ]] || [[ -z "$(ls -A "$BACKUP_ROOT" 2>/dev/null)" ]]; then
        warn "No backups found yet."
        return
    fi
    echo "Available backups (newest last):"
    for d in "$BACKUP_ROOT"/*/; do
        [[ -d "$d" ]] || continue
        basename "$d" | sed 's/^/  - /'
    done
    if [[ -f "$BACKUP_ROOT/$LATEST_FILE" ]]; then
        echo
        echo "Latest: $(cat "$BACKUP_ROOT/$LATEST_FILE")"
    fi
}

# Resolves a requested backup name to one that actually exists and is usable
# (has $required_file in it). Falls back to listing real backups and asking
# if the requested one is missing/stale. Prints the chosen name on stdout;
# everything else goes to stderr so it doesn't get captured by $().
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
    if [[ -z "$target" && -f "$BACKUP_ROOT/$LATEST_FILE" ]]; then
        target="$(cat "$BACKUP_ROOT/$LATEST_FILE")"
    fi
    target="$(resolve_backup_target "$target" "settings.tsv")" || exit 1

    local file="$BACKUP_ROOT/$target/settings.tsv"
    if [[ -f "$BACKUP_ROOT/$target/REVERTED" ]]; then
        info "Backup $target was already reverted — nothing to do."
        exit 0
    fi
    local n; n=$(wc -l < "$file" 2>/dev/null || echo 0)
    if [[ "$n" -eq 0 ]]; then
        info "That run didn't change anything that needed restoring — nothing to do."
        exit 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] $n setting(s) would be restored from backup $target (nothing changed):"
        while IFS=$'\t' read -r kind schema key value; do
            [[ "$kind" == "gsettings" ]] || continue
            printf '  %-52s %s  ->  %s\n' "$schema $key" "$(gsettings get "$schema" "$key" 2>/dev/null || echo '<unset>')" "$value" >&2
        done < "$file"
        exit 0
    fi
    warn "About to restore $n setting(s) this script changed, from backup: $target"
    warn "(only those specific keys — nothing else on your system is touched)"
    read -rp "Continue? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled — nothing changed."
        exit 0
    fi

    local restored=0
    while IFS=$'\t' read -r kind schema key value; do
        [[ "$kind" == "gsettings" ]] || continue
        if gsettings set "$schema" "$key" "$value" 2>/dev/null; then
            restored=$((restored+1))
        else
            warn "Couldn't restore $schema $key (schema/key may no longer exist)"
        fi
    done < "$file"
    mark_reverted "$target"
    ok "Restored $restored setting(s) from backup: $target"
    info "Some changes (e.g. theme) may need a re-login or Alt+F2 -> 'r' to fully apply."
}

# ---- the actual tweaks -------------------------------------------------------
apply_safe_tweaks() {
    info "Applying safe tweaks (low risk of visibly changing your desktop)..."
    tset org.gnome.desktop.interface clock-show-seconds true
    tset org.gnome.desktop.interface clock-show-weekday true
    tset org.gnome.desktop.screensaver lock-enabled false
    tset org.gnome.desktop.session idle-delay 900
    tset org.gnome.mutter attach-modal-dialogs false
    if schema_exists "org.gtk.Settings.FileChooser"; then
        tset org.gtk.Settings.FileChooser sort-directories-first true
    fi
    applied "Safe tweaks"
}

apply_dark_mode() {
    info "Applying dark mode..."
    tset org.gnome.desktop.interface color-scheme 'prefer-dark'

    # only force a specific GTK theme if it's actually installed —
    # otherwise leave whatever theme is already set alone
    if [[ -d "/usr/share/themes/Kali-Dark" || -d "$HOME/.themes/Kali-Dark" || -d "$HOME/.local/share/themes/Kali-Dark" ]]; then
        tset org.gnome.desktop.interface gtk-theme 'Kali-Dark'
        applied "Dark mode + Kali-Dark theme"
    else
        warn "Kali-Dark theme isn't installed — left your current GTK theme alone, only switched color-scheme to dark."
    fi
}

apply_dock_tweaks() {
    if ! schema_exists "org.gnome.shell.extensions.dash-to-dock"; then
        warn "Dash to Dock extension/schema not found — skipping dock tweaks (nothing to overwrite)."
        return
    fi
    info "Applying Dash to Dock tweaks (position: bottom, autohide: on, icon size: 40)..."
    tset org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
    tset org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 40
    tset org.gnome.shell.extensions.dash-to-dock autohide true
    applied "Dock tweaks"
}

apply_font() {
    local font_family="Fira Code"
    local font_setting="Fira Code Retina 11"

    if [[ $DRY_RUN -eq 1 ]]; then
        if fc-list 2>/dev/null | grep -i "$font_family" >/dev/null; then
            info "[dry-run] $font_family already installed — no package install needed"
        else
            info "[dry-run] would run: sudo apt install -y fonts-firacode"
        fi
        tset org.gnome.desktop.interface monospace-font-name "$font_setting"
        return
    fi

    if ! fc-list 2>/dev/null | grep -i "$font_family" >/dev/null; then
        if command -v apt &>/dev/null; then
            info "Installing $font_family (needs sudo — the only tweak here that does)..."
            if sudo apt update && sudo apt install -y fonts-firacode; then
                ok "$font_family installed."
            else
                warn "Couldn't install $font_family via apt — leaving monospace font alone."
                return
            fi
        else
            warn "apt not found and $font_family isn't installed — leaving monospace font alone."
            return
        fi
    else
        info "$font_family already installed."
    fi

    if fc-list 2>/dev/null | grep -i "$font_family" >/dev/null; then
        # quoted throughout — font names have spaces, and unquoted gsettings
        # values with spaces get word-split into multiple bogus arguments
        tset org.gnome.desktop.interface monospace-font-name "$font_setting"
        ok "Set terminal/monospace font to: $font_setting"
    else
        warn "$font_family still not showing in fc-list after install — leaving monospace font alone."
    fi
}

usage() {
    grep '^#' "$0" | sed -n '2,25p' | sed 's/^# \{0,1\}//'
}

# ---- main ---------------------------------------------------------------------
main() {
    require_gsettings

    local do_safe=1 do_dark=0 do_dock=0 do_font=0
    local arg
    for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=1; done

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                shift
                ;;
            --dark-mode)
                do_dark=1
                shift
                ;;
            --dock)
                do_dock=1
                shift
                ;;
            --font)
                do_font=1
                shift
                ;;
            --all)
                do_dark=1
                do_dock=1
                do_font=1
                shift
                ;;
            --list-backups)
                list_backups
                exit 0
                ;;
            --revert)
                if [[ -n "${2:-}" && "$2" != --* ]]; then
                    revert "$2"
                else
                    revert ""
                fi
                exit 0
                ;;
            --revert=*)
                revert "${1#--revert=}"
                exit 0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                err "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY RUN — current value -> new value for every setting below."
        info "Nothing is applied, no backup is created, nothing is installed."
    else
        mkdir -p "$BACKUP_ROOT"
        local backup_dir; backup_dir="$(make_backup)"
        SETTINGS_MANIFEST="$backup_dir/settings.tsv"
    fi

    [[ $do_safe -eq 1 ]] && apply_safe_tweaks
    [[ $do_dark -eq 1 ]] && apply_dark_mode
    [[ $do_dock -eq 1 ]] && apply_dock_tweaks
    [[ $do_font -eq 1 ]] && apply_font

    echo
    if [[ $DRY_RUN -eq 1 ]]; then
        ok "Dry run finished — nothing was changed."
    else
        ok "Done. If anything looks wrong, undo it with:"
        echo "    $0 --revert"
    fi
}

main "$@"
