#!/usr/bin/env bash
#
# sync-burn-color.sh — match Burn My Windows' fire animation color to
# whatever your current wallpaper actually is
#
# Run this any time you change your wallpaper (to anything — not just
# something from this repo) and want the window-close fire effect to match
# it again, rather than staying whatever color it was set to before.
#
# Usage:
#   ./sync-burn-color.sh              detect + apply
#   ./sync-burn-color.sh --dry-run    show the 5 fire colors it WOULD set (current -> new);
#                                      writes nothing, makes no backup
#   ./sync-burn-color.sh --list-backups
#   ./sync-burn-color.sh --revert [NAME]   restore the previous fire colors
#
# How it works: reads your current wallpaper path from GNOME's own setting,
# analyzes the image to find its most common vivid (non-background, non-
# washed-out) hue, then builds a 5-stop fire gradient in that hue using the
# same brightness/alpha shape as Burn My Windows' own default fire colors —
# so whatever color your wallpaper leans toward, the animation still reads
# as "fire," just recolored to match.
#
# Needs: python3 + Pillow (installed automatically if missing), and Burn My
# Windows already installed with its Fire effect enabled (theme-pack.sh
# --animations does this, or install it yourself via Extension Manager).
# Detects the extension via `gnome-extensions list` / its install directory
# rather than `gsettings list-schemas` — an extension's schema often isn't
# visible to the plain gsettings CLI at all, only to its own internal code,
# so that check can wrongly report "not installed." Colors are written via
# `dconf write` directly for the same reason.
#
# BACKUPS: only the 5 specific fire-color keys this script writes get
# backed up (and restored on --revert) — never a broad reset of the whole
# GNOME settings tree. An earlier version did a wholesale `dconf reset` +
# reload of /org/gnome/ on revert, which could revert things this script
# never touched at all (like disabling an unrelated extension you already
# had enabled), and risked destabilizing an active session by wiping a huge
# swath of live settings at once. This version only ever touches those 5 keys.

set -uo pipefail

BACKUP_ROOT="$HOME/.kali-custom-setup-backups/gnome"   # shared store, same as gnome-tweaks.sh/theme-pack.sh
BMW_UUID="burn-my-windows@schneegans.github.com"
BMW_DCONF_PATH="/org/gnome/shell/extensions/burn-my-windows-profile/"
DRY_RUN=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "[*] $*" >&2; }
ok()   { echo -e "${GREEN}[+]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $*" >&2; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

require_python_pillow() {
    if [[ $DRY_RUN -eq 1 ]]; then
        if ! command -v python3 &>/dev/null || ! python3 -c "import PIL" &>/dev/null; then
            info "[dry-run] python3 + Pillow are needed to analyze the wallpaper and aren't both present."
            info "[dry-run] a real run would install Pillow via pip; can't preview the colors without it."
            exit 0
        fi
        return 0
    fi
    if ! command -v python3 &>/dev/null; then
        err "python3 not found — can't analyze the wallpaper. Aborting."
        exit 1
    fi
    if ! python3 -c "import PIL" &>/dev/null; then
        info "Installing Pillow (needed to analyze the wallpaper image)..."
        if command -v pip3 &>/dev/null; then
            pip3 install --break-system-packages --quiet Pillow 2>/dev/null || \
            pip3 install --user --quiet Pillow 2>/dev/null
        fi
        if ! python3 -c "import PIL" &>/dev/null; then
            err "Couldn't install Pillow — aborting."
            exit 1
        fi
    fi
}

# Checks whether Burn My Windows is actually installed. Deliberately does NOT
# rely on `gsettings list-schemas` — an extension's schema lives in its own
# per-extension folder and often isn't visible to the plain gsettings CLI at
# all (only to the extension's own internal code), so that check can report
# "not installed" even when it is. Checking `gnome-extensions list` (or the
# install directories directly, as a fallback) is what actually reflects
# whether the extension is present.
is_burn_my_windows_installed() {
    if command -v gnome-extensions &>/dev/null; then
        gnome-extensions list 2>/dev/null | grep -x "$BMW_UUID" >/dev/null && return 0
    fi
    [[ -d "$HOME/.local/share/gnome-shell/extensions/$BMW_UUID" ]] && return 0
    [[ -d "/usr/share/gnome-shell/extensions/$BMW_UUID" ]] && return 0
    return 1
}

get_wallpaper_path() {
    local uri
    uri="$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")"
    if [[ -z "$uri" ]]; then
        return 1
    fi
    echo "${uri#file://}"
}

# Prints the 5 rgba() fire-color values on stdout, one per line, in order.
# Returns non-zero if no usable wallpaper / no vivid color could be found.
compute_fire_gradient() {
    local wallpaper="$1"
    python3 - "$wallpaper" << 'PYEOF'
import sys, colorsys, warnings
warnings.filterwarnings("ignore")
from PIL import Image

path = sys.argv[1]
try:
    img = Image.open(path).convert("RGB")
except Exception as e:
    sys.exit(1)

img.thumbnail((300, 300))
pixels = list(img.getdata())

candidates = []
for (r, g, b) in pixels:
    h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
    if v >= 0.25 and s >= 0.25:
        candidates.append((r, g, b))

if not candidates:
    sys.exit(1)

tiny = Image.new("RGB", (len(candidates), 1))
tiny.putdata(candidates)
n = min(10, len(candidates))
quantized = tiny.quantize(colors=n, method=Image.MEDIANCUT)
palette = quantized.getpalette()
counts = quantized.getcolors()
counts.sort(reverse=True)

_, top_idx = counts[0]
r, g, b = palette[top_idx*3], palette[top_idx*3+1], palette[top_idx*3+2]
hue, _, _ = colorsys.rgb_to_hsv(r/255, g/255, b/255)

def rgba(hue_frac, s, v, a):
    rr, gg, bb = colorsys.hsv_to_rgb(hue_frac % 1.0, s, v)
    return f"rgba({round(rr*255)}, {round(gg*255)}, {round(bb*255)}, {a})"

# same saturation/value/alpha shape as Burn My Windows' own default fire
# gradient (transparent dark -> deep -> vivid -> warm-shifted bright -> white)
print(rgba(hue, 0.671, 0.298, 0.0))
print(rgba(hue, 0.833, 0.706, 0.7))
print(rgba(hue, 0.851, 1.000, 0.9))
print(rgba(hue + 26.8/360, 0.902, 1.000, 1.0))
print("rgba(255, 255, 255, 1)")
PYEOF
}

# ---- backup/revert — scoped to just the 5 fire-color-N keys ------------------
# Records the CURRENT value of each fire-color key (if any) before writing a
# new one, so --revert can put back exactly those 5 keys — nothing broader.
tracked_dconf_write() {
    local path="$1" new_value="$2"
    local old_value
    old_value="$(dconf read "$path" 2>/dev/null)"
    # first value recorded wins: if an earlier (unreverted) run already saved the
    # ORIGINAL for this key, don't overwrite it with a value we set ourselves
    if [[ -n "${SETTINGS_MANIFEST:-}" ]] && ! grep -qF "$(printf '\t%s\t' "$path")" "$SETTINGS_MANIFEST" 2>/dev/null; then
        if [[ -n "$old_value" ]]; then
            printf 'dconf\t%s\t%s\n' "$path" "$old_value" >> "$SETTINGS_MANIFEST"
        else
            printf 'dconf-unset\t%s\t\n' "$path" >> "$SETTINGS_MANIFEST"
        fi
    fi
    dconf write "$path" "$new_value"
}

# Safe to run twice: if the previous run was never reverted, the ORIGINAL values
# it recorded are still the true originals, so they are carried forward — revert
# then returns you to the state before the FIRST run. A reverted run gets a
# REVERTED marker and the chain starts fresh.
make_backup() {
    local ts prev="" dir n=0
    ts="$(date +%Y%m%d-%H%M%S)"
    dir="$BACKUP_ROOT/$ts"
    while [[ -e "$dir" ]]; do n=$((n+1)); dir="$BACKUP_ROOT/${ts}-$n"; done
    [[ -f "$BACKUP_ROOT/.latest-burn-color" ]] && prev="$(cat "$BACKUP_ROOT/.latest-burn-color")"
    mkdir -p "$dir"
    : > "$dir/settings.tsv"
    if [[ -n "$prev" && -f "$BACKUP_ROOT/$prev/settings.tsv" && ! -f "$BACKUP_ROOT/$prev/REVERTED" ]]; then
        cp "$BACKUP_ROOT/$prev/settings.tsv" "$dir/settings.tsv"
        echo "$prev" > "$dir/CHAINED_FROM"
    fi
    basename "$dir" > "$BACKUP_ROOT/.latest-burn-color"
    echo "$dir"
}

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
    [[ -f "$BACKUP_ROOT/.latest-burn-color" ]] && echo && echo "Latest sync-burn-color run: $(cat "$BACKUP_ROOT/.latest-burn-color")"
}

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
    if [[ -z "$target" && -f "$BACKUP_ROOT/.latest-burn-color" ]]; then
        target="$(cat "$BACKUP_ROOT/.latest-burn-color")"
    fi
    target="$(resolve_backup_target "$target" "settings.tsv")" || exit 1

    local file="$BACKUP_ROOT/$target/settings.tsv"
    if [[ -f "$BACKUP_ROOT/$target/REVERTED" ]]; then
        info "Backup $target was already reverted — nothing to do."
        exit 0
    fi
    local n; n=$(wc -l < "$file" 2>/dev/null || echo 0)
    if [[ "$n" -eq 0 ]]; then
        info "That run didn't change anything — nothing to do."
        exit 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] $n fire-color key(s) would be restored from backup $target (nothing changed):"
        while IFS=$'\t' read -r kind path value; do
            case "$kind" in
                dconf)       printf '  %s   %s  ->  %s\n' "${path##*/}" "$(dconf read "$path" 2>/dev/null || echo '<unset>')" "$value" >&2 ;;
                dconf-unset) printf '  %s   %s  ->  <unset: extension default>\n' "${path##*/}" "$(dconf read "$path" 2>/dev/null || echo '<unset>')" >&2 ;;
            esac
        done < "$file"
        exit 0
    fi
    warn "About to restore the $n fire-color key(s) this script changed, from backup: $target"
    warn "(only those specific keys — nothing else on your system is touched)"
    read -rp "Continue? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled — nothing changed."
        exit 0
    fi

    local restored=0
    while IFS=$'\t' read -r kind path value; do
        case "$kind" in
            dconf)
                dconf write "$path" "$value" && restored=$((restored+1))
                ;;
            dconf-unset)
                dconf reset "$path" 2>/dev/null && restored=$((restored+1))
                ;;
        esac
    done < "$file"
    mark_reverted "$target"
    ok "Restored $restored fire-color key(s) from backup: $target"
}

usage() {
    grep '^#' "$0" | sed -n '2,22p' | sed 's/^# \{0,1\}//'
}

# ---- main -----------------------------------------------------------------------
main() {
    local arg
    for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=1; done
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) shift ;;
            --list-backups) list_backups; exit 0 ;;
            --revert)
                if [[ -n "${2:-}" && "$2" != --* ]]; then revert "$2"; else revert ""; fi
                exit 0
                ;;
            --revert=*) revert "${1#--revert=}"; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            *) err "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if ! command -v gsettings &>/dev/null || ! command -v dconf &>/dev/null; then
        err "gsettings/dconf not found — this doesn't look like a GNOME session. Aborting."
        exit 1
    fi

    if ! is_burn_my_windows_installed; then
        warn "Burn My Windows doesn't seem to be installed — nothing to sync."
        warn "Install it via theme-pack.sh --animations, or Extension Manager, first."
        exit 0
    fi

    require_python_pillow

    local wallpaper
    if ! wallpaper="$(get_wallpaper_path)"; then
        err "Couldn't read your current wallpaper setting — aborting."
        exit 1
    fi
    if [[ ! -f "$wallpaper" ]]; then
        err "Wallpaper file not found: $wallpaper"
        exit 1
    fi
    info "Analyzing wallpaper: $wallpaper"

    local gradient
    if ! gradient="$(compute_fire_gradient "$wallpaper")"; then
        warn "Couldn't find a clear dominant color in this wallpaper (too plain/uniform?) — leaving fire colors as they are."
        exit 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY RUN — current value -> new value for the 5 fire-color keys (nothing written, no backup):"
        local j=1 cur
        while IFS= read -r color; do
            cur="$(dconf read "${BMW_DCONF_PATH}fire-color-$j" 2>/dev/null)"
            printf '  fire-color-%s   %s  ->  %s\n' "$j" "${cur:-<unset: extension default>}" "'$color'" >&2
            j=$((j+1))
        done <<< "$gradient"
        ok "Dry run finished — nothing was changed."
        exit 0
    fi

    mkdir -p "$BACKUP_ROOT"
    local backup_dir; backup_dir="$(make_backup)"
    SETTINGS_MANIFEST="$backup_dir/settings.tsv"

    local i=1
    while IFS= read -r color; do
        tracked_dconf_write "${BMW_DCONF_PATH}fire-color-$i" "'$color'"
        i=$((i+1))
    done <<< "$gradient"

    ok "Burn My Windows fire colors synced to your wallpaper."
    info "If a window animation is already mid-flight you won't see it until the next one."
    echo
    ok "Didn't like the result? Undo with:"
    echo "    $0 --revert"
}

main "$@"
