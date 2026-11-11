#!/usr/bin/env bash
#
# restore.sh — put back what the setup scripts changed.
#
# This is the same script as revert.sh, kept under both names. Everything
# revert.sh does is available here:
#   ./restore.sh                interactive menu
#   ./restore.sh --dotfiles     put back your original dotfiles (.zshrc, .tmux.conf, .gitconfig, ...)
#   ./restore.sh --all          dotfiles + GNOME settings + theme-pack + fire color
#   ./restore.sh --list-backups show every backup available
# See revert.sh --help for the full list.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/revert.sh" "$@"
