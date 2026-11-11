#!/usr/bin/env bash
# 04-ctf-tools.sh — pwn, reversing, forensics, crypto and misc CTF categories
set -uo pipefail

APT_PACKAGES=(
    # pwn / reversing
    gdb
    radare2
    binwalk
    checksec
    ltrace
    strace
    patchelf

    # forensics / stego
    exiftool
    steghide
    foremost
    testdisk
    volatility3
    wireshark

    # crypto / cracking
    john
    hashcat
    hash-identifier

    # misc / recon for jeopardy-style challenges
    file
    xxd
    imagemagick
)

echo "[*] Installing apt-based CTF packages..."
sudo apt update
for pkg in "${APT_PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo "    [=] $pkg already installed"
    else
        echo "    [+] installing $pkg"
        sudo apt install -y "$pkg" || echo "    [!] failed to install $pkg — skipping"
    fi
done

# ---- pwntools + pwn-focused python ecosystem --------------------------------
echo "[*] Setting up pwntools in a dedicated venv (~/tools/pwn-venv)..."
mkdir -p "$HOME/tools"
if [[ ! -d "$HOME/tools/pwn-venv" ]]; then
    python3 -m venv "$HOME/tools/pwn-venv"
fi
# shellcheck disable=SC1091
source "$HOME/tools/pwn-venv/bin/activate"
pip install --upgrade pip &>/dev/null
pip install pwntools ropper angr &>/dev/null && echo "    [+] pwntools, ropper, angr installed in venv" \
    || echo "    [!] pip install failed inside venv — check manually"
deactivate

# ---- pwndbg (gdb enhancement, very standard for pwn CTFs) -------------------
if [[ ! -d "$HOME/tools/pwndbg" ]]; then
    echo "[*] Cloning and installing pwndbg..."
    git clone --depth 1 https://github.com/pwndbg/pwndbg "$HOME/tools/pwndbg"
    (cd "$HOME/tools/pwndbg" && ./setup.sh) || echo "    [!] pwndbg setup failed — try running its setup.sh manually"
else
    echo "    [=] pwndbg already cloned at ~/tools/pwndbg"
fi

echo "[+] CTF toolkit installed."
echo "    Activate the pwn venv with: source ~/tools/pwn-venv/bin/activate"
echo "    (an alias 'pwnenv' for this is set up in dotfiles/zsh/aliases.zsh)"
