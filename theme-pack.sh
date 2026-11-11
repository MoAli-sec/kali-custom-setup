#!/usr/bin/env bash
#
# theme-pack.sh — desktop aesthetic pack, two palettes to choose from
#
# A cohesive look across GTK theme, icons, cursor, wallpaper, AND the
# terminal's actual color palette (not just its window chrome) — plus
# opt-in extras. Two palette choices:
#   tokyonight (default) — dark blue/purple/cyan
#   ember (--ember)      — dark red/orange/amber, Hinokami-Kagura inspired
#
# Usage:
#   ./theme-pack.sh                core suite, Tokyo Night palette
#   ./theme-pack.sh --ember        core suite, ember palette instead
#   ./theme-pack.sh --banner       + fastfetch banner on new terminals
#   ./theme-pack.sh --animations   + Burn My Windows (needs a shell restart after)
#   ./theme-pack.sh --overlay      + Conky live CPU/RAM/net stats on the desktop
#   ./theme-pack.sh --all          all of the above (add --ember before --all
#                                   for the ember version of everything)
#   ./theme-pack.sh --dry-run      with any options above: show every step and each
#                                   setting's current -> new value; install, download,
#                                   write and change NOTHING, and make no backup
#   ./theme-pack.sh --list-backups
#   ./theme-pack.sh --revert [NAME]   undoes settings AND removes what this
#                                      script added (themes, configs, the
#                                      extension) — shares the same backup
#                                      store as gnome-tweaks.sh
#
# The core suite ALWAYS includes the terminal's actual color scheme (GNOME
# Terminal's background/foreground/16-color palette) — a GTK theme only
# changes window chrome, not the colors your text actually renders in, so
# skipping this would leave the terminal looking unchanged, same as before.
#
# BACKUPS: only the specific gsettings keys this script actually sets get
# backed up (and restored on --revert) — never a broad reset of the whole
# GNOME settings tree. An earlier version did a wholesale `dconf reset` +
# reload of /org/gnome/ on revert, which could revert things this script
# never touched at all (like disabling an unrelated extension you already
# had enabled), and risked destabilizing an active session by wiping a huge
# swath of live settings at once. This version only ever touches keys it
# itself changed, plus the specific files/extension it installed.
#
# Every source here is the real upstream project, installed the way its own
# maintainers document — not a hand-copied zip. Specifically:
#   GTK theme    : github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme (its own installer)
#   Icon theme   : github.com/vinceliuice/Tela-circle-icon-theme (its own installer)
#   Cursor theme : github.com/ful1e5/Bibata_Cursor (prebuilt release tarball)
#   Banner       : github.com/fastfetch-cli/fastfetch (official .deb release)
#   Animations   : github.com/Schneegans/Burn-My-Windows, installed + enabled via
#                  the official `gnome-extensions` CLI — its own README explicitly
#                  warns against hand-copying files into the extensions folder,
#                  which is exactly what broke Dash to Dock before.
#   Overlay      : Conky — a standalone app (not a GNOME Shell extension), so it
#                  can't fall into that same "installed but never enabled" trap.

set -uo pipefail

PALETTE="tokyonight"   # or "ember" — set by --ember before any apply_* runs
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
BACKUP_ROOT="$HOME/.kali-custom-setup-backups/gnome"   # shared with gnome-tweaks.sh
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# ---- helpers ----------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "[*] $*" >&2; }
ok()   { echo -e "${GREEN}[+]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[!]${NC} $*" >&2; }
err()  { echo -e "${RED}[-]${NC} $*" >&2; }

# "X applied." normally; "previewed" in a dry run, so output never claims
# something was applied when it wasn't.
applied() {
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] previewed: $1 (nothing changed)"
    else
        ok "$1 applied."
    fi
}

require() {
    if ! command -v "$1" &>/dev/null; then
        if [[ $DRY_RUN -eq 1 ]]; then
            info "[dry-run] would run: sudo apt install -y $1"
            return 0
        fi
        info "Installing $1..."
        if ! { sudo apt update -qq && sudo apt install -y "$1"; }; then
            err "Couldn't install $1 — skipping this step."
            return 1
        fi
    fi
}

# ---- backup/revert (settings: scoped per-key; files: tracked separately) ---
# Only the specific gsettings keys this script actually sets get backed up
# and restored — never a broad reset of the whole GNOME settings tree. An
# earlier version did a wholesale `dconf reset` + reload of /org/gnome/ on
# revert, which could revert things this script never touched at all (like
# disabling an unrelated extension you already had enabled), and risked
# destabilizing an active session by wiping a huge swath of live settings
# at once. This version only ever touches keys it itself changed.
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

# Safe to run twice: if the previous run was never reverted, the ORIGINAL values
# and the list of files it installed are still accurate, so they are carried
# forward into this run's backup. Reverting then returns you to the state before
# the FIRST run (settings back to your originals AND the installed files removed)
# instead of leaving settings pointed at themes the revert just deleted.
# A reverted run gets a REVERTED marker and the chain starts fresh.
make_backup() {
    local ts prev="" dir n=0
    ts="$(date +%Y%m%d-%H%M%S)"
    dir="$BACKUP_ROOT/$ts"
    while [[ -e "$dir" ]]; do n=$((n+1)); dir="$BACKUP_ROOT/${ts}-$n"; done
    [[ -f "$BACKUP_ROOT/.latest-theme-pack" ]] && prev="$(cat "$BACKUP_ROOT/.latest-theme-pack")"
    mkdir -p "$dir"
    : > "$dir/settings.tsv"
    if [[ -n "$prev" && -f "$BACKUP_ROOT/$prev/settings.tsv" && ! -f "$BACKUP_ROOT/$prev/REVERTED" ]]; then
        cp "$BACKUP_ROOT/$prev/settings.tsv" "$dir/settings.tsv"
        [[ -f "$BACKUP_ROOT/$prev/theme-pack-manifest.txt" ]] && cp "$BACKUP_ROOT/$prev/theme-pack-manifest.txt" "$dir/theme-pack-manifest.txt"
        [[ -d "$BACKUP_ROOT/$prev/orig-files" ]] && cp -a "$BACKUP_ROOT/$prev/orig-files" "$dir/orig-files"
        echo "$prev" > "$dir/CHAINED_FROM"
    fi
    touch "$dir/theme-pack-manifest.txt"
    basename "$dir" > "$BACKUP_ROOT/.latest-theme-pack"
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
    [[ -f "$BACKUP_ROOT/.latest-theme-pack" ]] && echo && echo "Latest theme-pack run: $(cat "$BACKUP_ROOT/.latest-theme-pack")"
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
    if [[ -z "$target" && -f "$BACKUP_ROOT/.latest-theme-pack" ]]; then
        target="$(cat "$BACKUP_ROOT/.latest-theme-pack")"
    fi
    target="$(resolve_backup_target "$target" "settings.tsv")"  || exit 1  # resolve_backup_target already printed the error

    local dir="$BACKUP_ROOT/$target"
    local settings_file="$dir/settings.tsv"
    local manifest="$dir/theme-pack-manifest.txt"

    if [[ -f "$dir/REVERTED" ]]; then
        info "Backup $target was already reverted — nothing to do."
        exit 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] would restore these settings from backup $target (nothing changed):"
        if [[ -f "$settings_file" ]]; then
            while IFS=$'\t' read -r kind schema key value; do
                [[ "$kind" == "gsettings" ]] || continue
                printf '  %-52s %s  ->  %s\n' "$schema $key" "$(gsettings get "$schema" "$key" 2>/dev/null || echo '<unset>')" "$value" >&2
            done < "$settings_file"
        fi
        if [[ -f "$manifest" ]]; then
            info "[dry-run] would delete these files/folders theme-pack installed (and put back"
            info "[dry-run] your own original where it replaced one):"
            while IFS=$'\t' read -r a b _; do
                if [[ "$a" == "restore" ]]; then echo "  restore your original: $b" >&2
                elif [[ -n "$a" ]]; then echo "  delete: $a" >&2; fi
            done < "$manifest"
        fi
        if command -v gnome-extensions &>/dev/null && gnome-extensions list 2>/dev/null | grep "burn-my-windows@schneegans.github.com" >/dev/null; then
            info "[dry-run] would disable + uninstall the Burn My Windows extension"
        fi
        if [[ -f "$manifest" ]] && grep -qF "/.config/conky/conky.conf" "$manifest"; then
            info "[dry-run] would stop the Conky instance theme-pack started"
        fi
        exit 0
    fi

    warn "This restores the specific settings this script changed, AND removes"
    warn "anything theme-pack added (themes, fastfetch/conky config, Burn My Windows)."
    warn "(only those specific things — nothing else on your system is touched)"
    read -rp "Continue? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled — nothing changed."
        exit 0
    fi

    local restored=0
    if [[ -f "$settings_file" ]]; then
        while IFS=$'\t' read -r kind schema key value; do
            [[ "$kind" == "gsettings" ]] || continue
            if gsettings set "$schema" "$key" "$value" 2>/dev/null; then
                restored=$((restored+1))
            else
                warn "Couldn't restore $schema $key (schema/key may no longer exist)"
            fi
        done < "$settings_file"
    fi
    ok "Restored $restored setting(s) from backup: $target"

    if [[ -f "$manifest" ]]; then
        while IFS=$'\t' read -r a b c; do
            if [[ "$a" == "restore" ]]; then
                mkdir -p "$(dirname "$b")"
                cp -a "$dir/orig-files/$c" "$b" && info "restored your original $b"
            elif [[ -n "$a" ]]; then
                rm -rf "$a"
                info "removed $a"
            fi
        done < "$manifest"
    fi

    if command -v gnome-extensions &>/dev/null && gnome-extensions list 2>/dev/null | grep "burn-my-windows@schneegans.github.com" >/dev/null; then
        gnome-extensions disable burn-my-windows@schneegans.github.com 2>/dev/null || true
        gnome-extensions uninstall burn-my-windows@schneegans.github.com 2>/dev/null || true
        info "removed Burn My Windows extension"
    fi

    if [[ -f "$manifest" ]] && grep -qF "/.config/conky/conky.conf" "$manifest"; then
        pkill -x conky 2>/dev/null || true
        info "stopped the Conky instance theme-pack started"
    fi

    mark_reverted "$target"
    ok "Reverted theme-pack changes from backup: $target"
    info "Some changes (theme, extensions) may need a re-login or Alt+F2 -> 'r' to fully clear."
}

track() {
    # record a path in the current run's manifest so --revert can remove it
    grep -qxF "$1" "$MANIFEST" 2>/dev/null || echo "$1" >> "$MANIFEST"
}

manifest_has() {
    grep -qxF "$1" "$MANIFEST" 2>/dev/null && return 0
    grep -qF "$(printf 'restore\t%s\t' "$1")" "$MANIFEST" 2>/dev/null
}

# For config files we WRITE that may already exist as the user's own (fastfetch,
# conky). Call BEFORE writing. If the file already exists, copy it into this
# run's backup and record "restore" so --revert puts YOUR original back; if it
# doesn't exist, record it for deletion. A path already tracked by an earlier
# unreverted run is left alone — what's there now is ours, not the original.
track_config() {
    local path="$1"
    manifest_has "$path" && return 0
    if [[ -e "$path" ]]; then
        local name; name="$(echo "$path" | sed 's|^/||; s|/|__|g')"
        mkdir -p "$BACKUP_DIR/orig-files"
        cp -a "$path" "$BACKUP_DIR/orig-files/$name"
        printf 'restore\t%s\t%s\n' "$path" "$name" >> "$MANIFEST"
    else
        echo "$path" >> "$MANIFEST"
    fi
}

# ---- GTK theme ----------------------------------------------------------------
apply_gtk_theme() {
    local theme_flag="default" find_pattern="Tokyonight*Dark*" exact_name="Tokyonight-Dark"
    if [[ "$PALETTE" == "ember" ]]; then
        theme_flag="orange"
        find_pattern="Tokyonight*Orange*Dark*"
        exact_name="Tokyonight-Orange-Dark"
    fi
    info "Installing GTK theme ($PALETTE palette)..."
    if [[ $DRY_RUN -eq 1 ]]; then
        require git; require sassc
        info "[dry-run] would git clone Tokyonight-GTK-Theme and run its installer ($theme_flag variant) into ~/.themes"
        tset org.gnome.desktop.interface gtk-theme "$exact_name"
        tset org.gnome.desktop.wm.preferences theme "$exact_name"
        return
    fi
    require git || return
    require sassc || return   # the installer needs this to actually build the theme — without
                               # it, it exits 0 but silently produces nothing
    if ! git clone --depth 1 https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme.git "$WORK_DIR/gtk-theme" 2>/dev/null; then
        warn "Couldn't clone the GTK theme repo — skipping GTK theme."
        return
    fi
    mkdir -p "$HOME/.themes"
    if [[ "$theme_flag" == "default" ]]; then
        # "default" IS blue/Tokyo Night — the installer's own default, no -t needed
        if ! bash "$WORK_DIR/gtk-theme/themes/install.sh" -c dark -d "$HOME/.themes" &>/dev/null; then
            warn "GTK theme installer failed — skipping GTK theme."
            return
        fi
    else
        if ! bash "$WORK_DIR/gtk-theme/themes/install.sh" -t "$theme_flag" -c dark -d "$HOME/.themes" &>/dev/null; then
            warn "GTK theme installer failed — skipping GTK theme."
            return
        fi
    fi
    # the installer creates the plain variant PLUS -hdpi/-xhdpi; prefer the
    # plain one, only fall back to a broader match if that's not there
    local theme_dir="$HOME/.themes/$exact_name"
    if [[ ! -d "$theme_dir" ]]; then
        theme_dir="$(find "$HOME/.themes" -maxdepth 1 -iname "$find_pattern" -type d | sort | head -n1)"
    fi
    if [[ -z "$theme_dir" || ! -d "$theme_dir" ]]; then
        warn "Installed but couldn't find the resulting theme folder — set it manually via GNOME Tweaks."
        return
    fi
    local theme_name; theme_name="$(basename "$theme_dir")"
    # track every variant this installer created (Dark, Dark-hdpi, Dark-xhdpi),
    # not just the one we activate, so --revert cleans up all of it
    while IFS= read -r variant; do
        track "$variant"
    done < <(find "$HOME/.themes" -maxdepth 1 -iname "$find_pattern" -type d)
    tset org.gnome.desktop.interface gtk-theme "$theme_name"
    tset org.gnome.desktop.wm.preferences theme "$theme_name" 2>/dev/null || true
    ok "GTK theme set to: $theme_name"
}

# ---- Icon theme -----------------------------------------------------------------
apply_icon_theme() {
    local icon_color="purple"
    [[ "$PALETTE" == "ember" ]] && icon_color="orange"
    local find_pattern="Tela-circle-${icon_color}*"
    local exact_name="Tela-circle-${icon_color}-dark"

    info "Installing Tela circle icon theme ($icon_color, dark variant)..."
    if [[ $DRY_RUN -eq 1 ]]; then
        require git
        info "[dry-run] would git clone Tela-circle-icon-theme and run its installer into ~/.local/share/icons"
        tset org.gnome.desktop.interface icon-theme "$exact_name"
        return
    fi
    require git || return
    if ! git clone --depth 1 https://github.com/vinceliuice/Tela-circle-icon-theme.git "$WORK_DIR/icon-theme" 2>/dev/null; then
        warn "Couldn't clone the Tela icon theme repo — skipping icon theme."
        return
    fi
    mkdir -p "$HOME/.local/share/icons"
    if ! bash "$WORK_DIR/icon-theme/install.sh" -c -d "$HOME/.local/share/icons" "$icon_color" &>/dev/null; then
        warn "Tela icon theme installer failed — skipping icon theme."
        return
    fi
    # the installer creates <color>, <color>-dark, AND <color>-light — we want
    # the dark-optimized one specifically, to match the rest of the pack
    local icon_dir="$HOME/.local/share/icons/$exact_name"
    if [[ ! -d "$icon_dir" ]]; then
        icon_dir="$(find "$HOME/.local/share/icons" -maxdepth 1 -iname "$find_pattern" -type d | sort | head -n1)"
    fi
    if [[ -z "$icon_dir" || ! -d "$icon_dir" ]]; then
        warn "Installed but couldn't find the resulting icon folder — set it manually via GNOME Tweaks."
        return
    fi
    local icon_name; icon_name="$(basename "$icon_dir")"
    # track every variant this installer created, not just the one we activate
    while IFS= read -r variant; do
        track "$variant"
    done < <(find "$HOME/.local/share/icons" -maxdepth 1 -iname "$find_pattern" -type d)
    tset org.gnome.desktop.interface icon-theme "$icon_name"
    ok "Icon theme set to: $icon_name"
}

# ---- Cursor theme ---------------------------------------------------------------
apply_cursor_theme() {
    local cursor_variant="Ice"
    [[ "$PALETTE" == "ember" ]] && cursor_variant="Amber"
    local cursor_base="Bibata-Modern-${cursor_variant}"

    info "Installing $cursor_base cursor theme..."
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] would download ${cursor_base}.tar.xz from the Bibata_Cursor GitHub release into ~/.local/share/icons"
        tset org.gnome.desktop.interface cursor-theme "$cursor_base"
        return
    fi
    local url="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/${cursor_base}.tar.xz"
    local tarball="$WORK_DIR/bibata.tar.xz"
    if ! curl -fsSL "$url" -o "$tarball" 2>/dev/null; then
        warn "Couldn't download Bibata cursor theme (release asset may have been renamed upstream) — skipping cursor."
        return
    fi
    mkdir -p "$HOME/.local/share/icons"
    if ! tar -xf "$tarball" -C "$HOME/.local/share/icons" 2>/dev/null; then
        warn "Couldn't extract Bibata cursor theme — skipping cursor."
        return
    fi
    local cursor_dir="$HOME/.local/share/icons/$cursor_base"
    if [[ ! -d "$cursor_dir" ]]; then
        cursor_dir="$(find "$HOME/.local/share/icons" -maxdepth 1 -iname "${cursor_base}*" -type d | head -n1)"
    fi
    if [[ -z "$cursor_dir" || ! -d "$cursor_dir" ]]; then
        warn "Extracted but couldn't find the resulting cursor folder — set it manually via GNOME Tweaks."
        return
    fi
    local cursor_name; cursor_name="$(basename "$cursor_dir")"
    track "$cursor_dir"
    tset org.gnome.desktop.interface cursor-theme "$cursor_name"
    ok "Cursor theme set to: $cursor_name"
}

# ---- Wallpaper (generated locally — nothing external to break) -----------------
apply_wallpaper() {
    info "Generating a $PALETTE wallpaper..."
    if [[ $DRY_RUN -eq 1 ]]; then
        local dry_out="$HOME/.local/share/backgrounds/${PALETTE}-wallpaper.png"
        if [[ -f "$dry_out" ]]; then
            info "[dry-run] would overwrite existing file: $dry_out"
        else
            info "[dry-run] would generate (ImageMagick): $dry_out"
        fi
        tset org.gnome.desktop.background picture-uri "file://$dry_out"
        tset org.gnome.desktop.background picture-uri-dark "file://$dry_out"
        tset org.gnome.desktop.background picture-options 'zoom'
        return
    fi
    local magick_cmd=""
    if command -v magick &>/dev/null; then
        magick_cmd="magick"
    elif command -v convert &>/dev/null; then
        magick_cmd="convert"
    else
        require imagemagick || return
        command -v magick &>/dev/null && magick_cmd="magick" || magick_cmd="convert"
    fi

    mkdir -p "$HOME/.local/share/backgrounds"
    local out="$HOME/.local/share/backgrounds/${PALETTE}-wallpaper.png"
    local ok_gen=1

    if [[ "$PALETTE" == "ember" ]]; then
        # Hinokami-Kagura-inspired: deep ash black with a rising fire glow
        "$magick_cmd" -size 1920x1080 \
            gradient:'#0d0604'-'#1a0803' \
            \( -size 1920x1080 xc:none -fill '#ff4500' -draw "circle 960,1200 960,1400" -blur 0x100 -channel A -evaluate multiply 0.5 +channel \) -composite \
            \( -size 1920x1080 xc:none -fill '#ff8c00' -draw "circle 960,1300 960,1450" -blur 0x70 -channel A -evaluate multiply 0.4 +channel \) -composite \
            \( -size 1920x1080 xc:none -fill '#ffb347' -draw "circle 960,1350 960,1460" -blur 0x40 -channel A -evaluate multiply 0.35 +channel \) -composite \
            "$out" 2>/dev/null || ok_gen=0
    else
        "$magick_cmd" -size 1920x1080 \
            gradient:'#1a1b26'-'#16161e' \
            \( -size 1920x1080 xc:none -fill '#7aa2f7' -draw "circle 1600,150 1600,350" -blur 0x60 -channel A -evaluate multiply 0.25 +channel \) -composite \
            \( -size 1920x1080 xc:none -fill '#bb9af7' -draw "circle 300,900 300,1100" -blur 0x80 -channel A -evaluate multiply 0.2 +channel \) -composite \
            "$out" 2>/dev/null || ok_gen=0
    fi

    if [[ $ok_gen -eq 0 || ! -f "$out" ]]; then
        warn "Wallpaper generation failed — leaving your current wallpaper alone."
        return
    fi

    track "$out"
    tset org.gnome.desktop.background picture-uri "file://$out"
    tset org.gnome.desktop.background picture-uri-dark "file://$out" 2>/dev/null || true
    tset org.gnome.desktop.background picture-options 'zoom'
    ok "Wallpaper set: $out"
}

# ---- Terminal colors (GNOME Terminal profile — NOT covered by the GTK theme) ---
# A GTK theme only changes window chrome (title bar, menus). The actual
# background/foreground/16-color palette your text renders in is a separate
# per-profile setting GNOME Terminal keeps under its own schema — skipping
# this is exactly why "the terminal didn't change" after just a GTK theme.
apply_terminal_colors() {
    info "Setting terminal colors ($PALETTE palette)..."
    if ! command -v gnome-terminal &>/dev/null; then
        warn "gnome-terminal not found — if you use a different terminal app, its colors need to be set separately."
        return
    fi

    local uuid
    uuid="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")"
    if [[ -z "$uuid" ]]; then
        warn "Couldn't find a default GNOME Terminal profile — skipping terminal colors."
        return
    fi
    local profile_path="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$uuid/"

    local bg fg palette
    if [[ "$PALETTE" == "ember" ]]; then
        bg='#170F0A'
        fg='#F4E9DC'
        palette="['#170F0A', '#FF5555', '#A3C76A', '#FFB454', '#5EC8D8', '#FF7096', '#4FB8AE', '#F4E9DC', '#5C4632', '#FF6E6E', '#B8DC7A', '#FFCB6B', '#82D6E3', '#FF8FAE', '#6BCEC4', '#FFF8F0']"
    else
        bg='#1A1B26'
        fg='#C0CAF5'
        palette="['#15161E', '#F7768E', '#9ECE6A', '#E0AF68', '#7AA2F7', '#BB9AF7', '#7DCFFF', '#A9B1D6', '#414868', '#F7768E', '#9ECE6A', '#E0AF68', '#7AA2F7', '#BB9AF7', '#7DCFFF', '#C0CAF5']"
    fi

    tset "$profile_path" use-theme-colors false
    tset "$profile_path" background-color "$bg"
    tset "$profile_path" foreground-color "$fg"
    tset "$profile_path" palette "$palette"
    applied "Terminal profile colors (background/foreground/16-color palette)"
}

# ---- Terminal banner (fastfetch) ------------------------------------------------
apply_banner() {
    info "Installing fastfetch..."
    if [[ $DRY_RUN -eq 1 ]]; then
        if command -v fastfetch &>/dev/null; then
            info "[dry-run] fastfetch already installed"
        else
            info "[dry-run] would download the official fastfetch .deb and install it with: sudo dpkg -i"
        fi
        info "[dry-run] would write ~/.config/fastfetch/config.jsonc ($PALETTE colors)"
        return
    fi
    if ! command -v fastfetch &>/dev/null; then
        local arch; arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
        local deb="$WORK_DIR/fastfetch.deb"
        local url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${arch}.deb"
        if ! curl -fsSL "$url" -o "$deb" 2>/dev/null; then
            warn "Couldn't download fastfetch for architecture '$arch' — skipping banner."
            return
        fi
        if ! sudo dpkg -i "$deb" &>/dev/null; then
            sudo apt -f install -y &>/dev/null || true
            sudo dpkg -i "$deb" &>/dev/null || { warn "fastfetch install failed — skipping banner."; return; }
        fi
    fi
    ok "fastfetch installed."

    mkdir -p "$HOME/.config/fastfetch"
    local config="$HOME/.config/fastfetch/config.jsonc"
    local logo_c1="blue" logo_c2="magenta"
    [[ "$PALETTE" == "ember" ]] && logo_c1="red" && logo_c2="yellow"
    track_config "$config"
    cat > "$config" << FASTFETCH_EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "type": "small", "color": { "1": "$logo_c1", "2": "$logo_c2" } },
  "display": { "separator": "  " },
  "modules": [
    "title",
    "separator",
    "os",
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "terminal",
    "cpu",
    "gpu",
    "memory",
    "break",
    "colors"
  ]
}
FASTFETCH_EOF
    ok "fastfetch configured ($PALETTE accents)."
    info "Banner shows on new terminals — it's already wired into dotfiles/zsh/.zshrc,"
    info "guarded so it's a no-op if fastfetch isn't installed."
}

# ---- Window animations (Burn My Windows, via the official CLI path) -----------
apply_animations() {
    info "Installing Burn My Windows (window close animations)..."
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] would download Burn My Windows from its GitHub release, then run:"
        info "[dry-run]   gnome-extensions install --force  +  gnome-extensions enable burn-my-windows@..."
        info "[dry-run] would then run sync-burn-color.sh to match its fire color to your wallpaper"
        info "[dry-run] (this never touches which OTHER extensions are enabled)"
        return
    fi
    if ! command -v gnome-extensions &>/dev/null; then
        warn "gnome-extensions CLI not found — install gnome-shell-extensions first. Skipping animations."
        return
    fi
    local zip="$WORK_DIR/burn-my-windows.zip"
    local url="https://github.com/Schneegans/Burn-My-Windows/releases/latest/download/burn-my-windows@schneegans.github.com.zip"
    if ! curl -fsSL "$url" -o "$zip" 2>/dev/null; then
        warn "Couldn't download Burn My Windows — skipping animations."
        return
    fi
    if ! gnome-extensions install --force "$zip" 2>/dev/null; then
        warn "gnome-extensions install failed — skipping animations."
        return
    fi
    gnome-extensions enable burn-my-windows@schneegans.github.com 2>/dev/null || true
    if gnome-extensions list --enabled 2>/dev/null | grep -x "burn-my-windows@schneegans.github.com" >/dev/null; then
        ok "Burn My Windows installed and enabled."
    else
        warn "Installed, but 'gnome-extensions enable' didn't confirm it's on."
        warn "Turn it on manually via Extension Manager, or run:"
        warn "  gnome-extensions enable burn-my-windows@schneegans.github.com"
    fi
    warn "Either way, GNOME Shell needs a restart to actually load it: Alt+F2 then 'r'"
    warn "on X11, or log out and back in if you're on Wayland."

    if [[ -f "$REPO_ROOT/sync-burn-color.sh" ]]; then
        info "Matching its fire color to your current wallpaper..."
        bash "$REPO_ROOT/sync-burn-color.sh" || true
    fi
}

# ---- Live stats overlay (Conky — a normal app, not a shell extension) ---------
apply_overlay() {
    info "Installing Conky (live system-stats overlay)..."
    if [[ $DRY_RUN -eq 1 ]]; then
        require conky-all
        info "[dry-run] would write ~/.config/conky/conky.conf ($PALETTE colors) and ~/.config/autostart/conky.desktop"
        info "[dry-run] would start conky now"
        return
    fi
    require conky-all || return

    mkdir -p "$HOME/.config/conky" "$HOME/.config/autostart"
    local conf="$HOME/.config/conky/conky.conf"
    local text_c1="c0caf5" accent1="7aa2f7" accent2="bb9af7" bg_shade="1a1b26"
    if [[ "$PALETTE" == "ember" ]]; then
        text_c1="f4e9dc"; accent1="ff5555"; accent2="ffb454"; bg_shade="170f0a"
    fi
    track_config "$conf"
    cat > "$conf" << CONKY_EOF
conky.config = {
    alignment = 'top_right',
    background = false,
    border_width = 0,
    cpu_avg_samples = 2,
    default_color = '$text_c1',
    default_outline_color = '$bg_shade',
    default_shade_color = '$bg_shade',
    double_buffer = true,
    draw_borders = false,
    draw_outline = false,
    draw_shades = false,
    use_xft = true,
    font = 'Fira Code:size=10',
    gap_x = 20,
    gap_y = 40,
    minimum_width = 220,
    net_avg_samples = 2,
    own_window = true,
    own_window_type = 'dock',
    own_window_transparent = true,
    own_window_argb_visual = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    update_interval = 2.0,
}

conky.text = [[
\${color $accent1}SYSTEM\${color}
CPU  \${cpu}% \${cpubar 6}
RAM  \${memperc}% \${membar 6}
\${color $accent2}NETWORK\${color}
Up   \${upspeed}
Down \${downspeed}
]]
CONKY_EOF

    track_config "$HOME/.config/autostart/conky.desktop"
    cat > "$HOME/.config/autostart/conky.desktop" << 'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=Conky
Exec=conky -c %h/.config/conky/conky.conf
X-GNOME-Autostart-enabled=true
DESKTOP_EOF

    pkill conky 2>/dev/null || true
    nohup conky -c "$conf" &>/dev/null &
    disown
    ok "Conky overlay running now, and set to autostart on login."
}

usage() {
    grep '^#' "$0" | sed -n '2,24p' | sed 's/^# \{0,1\}//'
}

# ---- main -----------------------------------------------------------------------
main() {
    if ! command -v gsettings &>/dev/null || ! command -v dconf &>/dev/null; then
        err "gsettings/dconf not found — this doesn't look like a GNOME session. Aborting."
        exit 1
    fi

    local do_banner=0 do_animations=0 do_overlay=0
    local arg
    for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=1; done

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)      shift ;;
            --ember)        PALETTE="ember"; shift ;;
            --banner)       do_banner=1; shift ;;
            --animations)   do_animations=1; shift ;;
            --overlay)      do_overlay=1; shift ;;
            --all)          do_banner=1; do_animations=1; do_overlay=1; shift ;;
            --list-backups) list_backups; exit 0 ;;
            --revert)
                if [[ -n "${2:-}" && "$2" != --* ]]; then revert "$2"; else revert ""; fi
                exit 0
                ;;
            --revert=*)     revert "${1#--revert=}"; exit 0 ;;
            -h|--help)      usage; exit 0 ;;
            *) err "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ $DRY_RUN -eq 1 ]]; then
        info "DRY RUN ($PALETTE palette) — current value -> new value shown for each setting."
        info "Nothing is installed, downloaded, written or applied, and no backup is made."
        apply_gtk_theme
        apply_icon_theme
        apply_cursor_theme
        apply_wallpaper
        apply_terminal_colors
        [[ $do_banner -eq 1 ]] && apply_banner
        [[ $do_animations -eq 1 ]] && apply_animations
        [[ $do_overlay -eq 1 ]] && apply_overlay
        echo
        ok "Dry run finished — nothing was changed."
        exit 0
    fi

    mkdir -p "$BACKUP_ROOT"
    local backup_dir; backup_dir="$(make_backup)"
    MANIFEST="$backup_dir/theme-pack-manifest.txt"
    SETTINGS_MANIFEST="$backup_dir/settings.tsv"
    BACKUP_DIR="$backup_dir"

    apply_gtk_theme
    apply_icon_theme
    apply_cursor_theme
    apply_wallpaper
    apply_terminal_colors
    [[ $do_banner -eq 1 ]] && apply_banner
    [[ $do_animations -eq 1 ]] && apply_animations
    [[ $do_overlay -eq 1 ]] && apply_overlay

    echo
    ok "Theme pack applied. If anything looks wrong, undo it with:"
    echo "    $0 --revert"
}

main "$@"
