# ~/.zshrc — Mohamed's custom Kali setup
# Repo: kali-custom-setup (see dotfiles/zsh/ for the pieces this loads)

# ---- terminal banner (only if theme-pack.sh --banner installed fastfetch) --
# Must run BEFORE the instant prompt block below: p10k's own docs warn that
# console output produced AFTER instant prompt initializes gets garbled.
# This line is a no-op on any machine that hasn't installed fastfetch.
command -v fastfetch &>/dev/null && fastfetch

# ---- Powerlevel10k instant prompt (must stay near the top) ------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ---- oh-my-zsh ----------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  colored-man-pages
  command-not-found
  sudo
)

source "$ZSH/oh-my-zsh.sh"

# ---- split-out config (kept in the repo, symlinked into ~/.zsh/) ------------
[[ -f "$HOME/.zsh/exports.zsh"   ]] && source "$HOME/.zsh/exports.zsh"
[[ -f "$HOME/.zsh/aliases.zsh"   ]] && source "$HOME/.zsh/aliases.zsh"
[[ -f "$HOME/.zsh/functions.zsh" ]] && source "$HOME/.zsh/functions.zsh"

# ---- fzf ------------------------------------------------------------------
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -f /usr/share/doc/fzf/examples/completion.zsh   ]] && source /usr/share/doc/fzf/examples/completion.zsh

# ---- p10k prompt config ------------------------------------------------------
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
