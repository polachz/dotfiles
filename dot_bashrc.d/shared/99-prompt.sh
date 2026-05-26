#!/usr/bin/env bash
# PS1 prompt — color-coded by uid (root=red, user=green).

if [ $EUID == 0 ]; then
   export PS1="\[$FG_LRED\]\u\[$FG_LPURPLE\]@\[$FG_LCYAN\]\h \[$FG_LBLUE\]\W\$ \[$FG_NO_COLOR\]"
else
   export PS1="\[$FG_LGREEN\]\u\[$FG_LPURPLE\]@\[$FG_LCYAN\]\h \[$FG_LBLUE\]\W\$ \[$FG_NO_COLOR\]"
fi
