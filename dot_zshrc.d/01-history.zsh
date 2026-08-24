#!/usr/bin/env zsh
# zsh-native history — HISTCONTROL/HISTFILESIZE (bash) have no zsh equivalent.
HISTSIZE=5000
SAVEHIST=5000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_ALL_DUPS
