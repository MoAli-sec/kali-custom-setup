#!/usr/bin/env bash
# 06-gnome-setup.sh — installs GNOME helper apps, then delegates the actual
# settings changes to the standalone ../gnome-tweaks.sh (safe to run/re-run/
# revert on its own; only needs sudo itself if you pass --font, since that
# installs a font package).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v gsettings &>/dev/null; then
    echo "[!] gsettings not found — this doesn't look like a GNOME session. Skipping."
    exit 0
fi

echo "[*] Installing GNOME Tweaks + Extension Manager + dconf-editor + GSConnect..."
sudo apt update
sudo apt install -y gnome-tweaks gnome-shell-extensions dconf-editor gnome-shell-extension-manager gnome-shell-extension-gsconnect 2>/dev/null || true

if [[ ! -f "$REPO_ROOT/gnome-tweaks.sh" ]]; then
    echo "[-] Can't find gnome-tweaks.sh at repo root — skipping settings tweaks."
    exit 1
fi

echo "[*] Applying GNOME settings (safe tweaks only — your backup is saved automatically)..."
echo "    Run gnome-tweaks.sh directly with --dark-mode / --dock / --font / --all if you want those too."
bash "$REPO_ROOT/gnome-tweaks.sh"

echo
echo "[*] GSConnect is installed but not enabled — turn it on via Extension Manager"
echo "    (installed above) and pair it with your phone's KDE Connect app."
