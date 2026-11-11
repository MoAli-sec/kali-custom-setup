# aliases.zsh — shortcuts for daily use, bug bounty, and CTF work

# ---- general quality of life -------------------------------------------------
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias tree='tree -C'
alias c='clear'
alias h='history'
alias reload='exec zsh'
alias ports='sudo netstat -tulanp'
alias myip='curl -s ifconfig.me'
alias update='sudo apt update && sudo apt full-upgrade -y'

# ---- git ----------------------------------------------------------------------
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
alias gco='git checkout'

# ---- tmux ----------------------------------------------------------------------
alias t='tmux'
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux ls'

# ---- bug bounty / recon ---------------------------------------------------------
alias subs='subfinder -silent -d'                     # usage: subs example.com
alias liveweb='httpx -silent'                         # pipe subs into this
alias nucleiscan='nuclei -silent -severity medium,high,critical'
alias urlhistory='waybackurls'
alias ffuffast='ffuf -c -w'                           # append wordlist,fields
alias reconworkdir='mkdir -p ~/bugbounty/$(date +%Y%m%d)-$1 && cd ~/bugbounty/$(date +%Y%m%d)-$1'

# ---- CTF -------------------------------------------------------------------------
alias pwnenv='source ~/tools/pwn-venv/bin/activate'   # jump into the pwntools venv
alias ctfstrings='strings -n 8'
alias hexdump='xxd'
alias checksecfile='checksec --file'

# ---- safer defaults ---------------------------------------------------------------
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I'
