#!/usr/bin/env bash
# 02-general-tools.sh — everyday desktop tools, not specific to security work
set -uo pipefail

PACKAGES=(
    # shell / terminal quality of life
    zsh
    tmux
    fzf
    ripgrep
    fd-find
    bat
    tree
    htop
    btop
    ncdu
    neofetch

    # editors
    vim
    neovim

    # archives
    unzip
    p7zip-full
    rar

    # networking basics
    curl
    wget
    net-tools
    openssh-client

    # dev basics
    git
    python3-pip
    python3-venv
    pipx
    build-essential

    # media / misc
    vlc
    gnome-tweaks
    gnome-shell-extensions
    flameshot
    copyq
)

echo "[*] Installing general daily-driver packages..."
sudo apt update
for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo "    [=] $pkg already installed"
    else
        echo "    [+] installing $pkg"
        sudo apt install -y "$pkg" || echo "    [!] failed to install $pkg — skipping"
    fi
done

# pipx path setup (needed for any pip-installed CLI tools later)
if command -v pipx &>/dev/null; then
    pipx ensurepath &>/dev/null || true
fi

echo "[+] General tools installed."
