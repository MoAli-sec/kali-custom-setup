# exports.zsh — environment variables and PATH additions

# Keep PATH free of duplicates, so sourcing this file again (or `exec zsh`,
# which inherits the exported PATH) never makes it grow.
typeset -U path PATH

export EDITOR="vim"
export VISUAL="vim"
export LANG="en_US.UTF-8"

# Go tools (subfinder, httpx, nuclei, ffuf, etc. all land here)
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# local user-installed scripts / tools
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/tools/bin"

# pipx-installed CLI tools
export PATH="$PATH:$HOME/.local/pipx/venvs"

# bat is installed as `batcat` on Debian/Kali — keep muscle memory as `bat`
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  alias bat="batcat"
fi

# fd is installed as `fdfind` on Debian/Kali
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  alias fd="fdfind"
fi

# history
export HISTSIZE=50000
export SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
