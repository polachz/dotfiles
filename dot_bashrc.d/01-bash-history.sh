#!/usr/bin/env bash
# Bash-only history config — HISTCONTROL/HISTFILESIZE have no zsh equivalent
# (zsh uses SAVEHIST + setopt HIST_IGNORE_*), see dot_zshrc for that side.

# Increase Bash history size. Allow 5000 entries; the default is 500.
export HISTSIZE='5000';
export HISTFILESIZE="${HISTSIZE}";
# Omit duplicates and commands that begin with a space from history.
export HISTCONTROL='ignoreboth';
# Make some commands not show up in history
HISTIGNORE="ls:cd:cd -:pwd:exit"
