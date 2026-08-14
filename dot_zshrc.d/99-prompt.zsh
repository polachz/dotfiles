#!/usr/bin/env zsh
# PROMPT — color-coded by uid (root=red, user=green). zsh equivalent of
# dot_bashrc.d/99-prompt.sh — PS1 backslash escapes (\u, \h, \W, \[...\]) are
# bash-only, zsh uses %-escapes (%n, %m, %1~, %{...%}) instead, so this can't
# be shared verbatim even though the $FG_* color variables (00-colors.sh) are.

if [ "${EUID}" = 0 ]; then
    PROMPT="%{${FG_LRED}%}%n%{${FG_LPURPLE}%}@%{${FG_LCYAN}%}%m %{${FG_LBLUE}%}%1~%# %{${FG_NO_COLOR}%}"
else
    PROMPT="%{${FG_LGREEN}%}%n%{${FG_LPURPLE}%}@%{${FG_LCYAN}%}%m %{${FG_LBLUE}%}%1~%# %{${FG_NO_COLOR}%}"
fi
