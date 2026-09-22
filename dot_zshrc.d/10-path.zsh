#!/usr/bin/env zsh
# Common — migrated from the user's real ~/.zshrc (2026-08-01).
# zsh's tied `path` array gives us native de-duplication on every source.
typeset -U path
path=("$HOME/.local/bin" $path)
export PATH
