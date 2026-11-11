# functions.zsh — small helper functions for daily use, recon, and CTF work

# mkdir + cd in one go
mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

# extract almost any archive type without remembering the flags
extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"    ;;
      *.tar.gz)    tar xzf "$1"    ;;
      *.tar.xz)    tar xJf "$1"    ;;
      *.bz2)       bunzip2 "$1"    ;;
      *.rar)       unrar x "$1"    ;;
      *.gz)        gunzip "$1"     ;;
      *.tar)       tar xf "$1"     ;;
      *.tbz2)      tar xjf "$1"    ;;
      *.tgz)       tar xzf "$1"    ;;
      *.zip)       unzip "$1"      ;;
      *.7z)        7z x "$1"       ;;
      *)           echo "extract: don't know how to handle '$1'" ;;
    esac
  else
    echo "extract: '$1' is not a valid file"
  fi
}

# quick recon scaffold for a new bug bounty target:
#   newtarget example.com
# creates ~/bugbounty/example.com/{recon,scans,notes} and drops in a scope note.
newtarget() {
  if [[ -z "$1" ]]; then
    echo "usage: newtarget <domain>"
    return 1
  fi
  local dir="$HOME/bugbounty/$1"
  mkdir -p "$dir"/{recon,scans,notes}
  echo "# $1 — scope notes" > "$dir/notes/scope.md"
  echo "Created $dir"
  cd "$dir" || return
}

# quick CTF challenge scaffold:
#   newctf pwn baby-rop
# creates ~/ctf/<category>/<name>/ and cd's into it
newctf() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "usage: newctf <category> <challenge-name>"
    return 1
  fi
  local dir="$HOME/ctf/$1/$2"
  mkdir -p "$dir"
  cd "$dir" || return
  echo "Created $dir"
}

# extract strings from a binary and grep in one shot:
#   strgrep ./binary flag
strgrep() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "usage: strgrep <file> <pattern>"
    return 1
  fi
  strings -n 6 "$1" | grep -i --color=auto "$2"
}
