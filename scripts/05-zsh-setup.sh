#!/usr/bin/env bash
# 05-zsh-setup.sh — zsh, oh-my-zsh, powerlevel10k, and the usual plugins
set -uo pipefail

# ---- zsh itself --------------------------------------------------------------
if ! command -v zsh &>/dev/null; then
    echo "[*] Installing zsh..."
    sudo apt update && sudo apt install -y zsh
else
    echo "[=] zsh already installed"
fi

# ---- oh-my-zsh ----------------------------------------------------------------
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
    echo "[*] Installing oh-my-zsh (unattended)..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "[=] oh-my-zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

clone_if_missing() {
    local repo="$1"
    local dest="$2"
    if [[ ! -d "$dest" ]]; then
        echo "    [+] cloning $(basename "$dest")"
        git clone --depth 1 "$repo" "$dest"
    else
        echo "    [=] $(basename "$dest") already present"
    fi
}

echo "[*] Installing zsh plugins..."
clone_if_missing "https://github.com/zsh-users/zsh-autosuggestions"        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_missing "https://github.com/zsh-users/zsh-syntax-highlighting"    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing "https://github.com/zsh-users/zsh-completions"           "$ZSH_CUSTOM/plugins/zsh-completions"

echo "[*] Installing powerlevel10k theme..."
clone_if_missing "https://github.com/romkatv/powerlevel10k.git"           "$ZSH_CUSTOM/themes/powerlevel10k"

# ---- make zsh the default shell ---------------------------------------------
if [[ "$SHELL" != *"zsh"* ]]; then
    echo "[*] Setting zsh as your default shell (you'll need to log out/in for it to fully apply)..."
    chsh -s "$(command -v zsh)" || echo "    [!] chsh failed — run it manually: chsh -s \$(which zsh)"
else
    echo "[=] zsh is already your default shell"
fi

echo "[+] zsh environment ready."
echo "    Run scripts/07-dotfiles-setup.sh (or install.sh --dotfiles) to symlink .zshrc etc."
