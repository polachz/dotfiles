#!/usr/bin/env zsh
# Starship — optional layer on top of the classic prompt (99-prompt.zsh),
# only if actually installed (see CONCEPT_ROADMAP.md §6). Sorts after
# 99-prompt.zsh alphabetically ("99-p" < "99-s"), so it loads later and can
# override PROMPT.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
