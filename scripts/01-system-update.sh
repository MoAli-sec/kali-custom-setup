#!/usr/bin/env bash
# 01-system-update.sh — bring the box fully up to date before installing anything else
set -uo pipefail

echo "[*] Updating package lists..."
sudo apt update

echo "[*] Upgrading installed packages..."
sudo apt full-upgrade -y

echo "[*] Removing packages that are no longer needed..."
sudo apt autoremove -y
sudo apt autoclean -y

echo "[+] System is up to date."
