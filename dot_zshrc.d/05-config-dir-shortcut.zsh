#!/usr/bin/env zsh
# Shell config directory shortcut — same alias name as bash's `brc`
# (dot_bashrc.d/config-dir-shortcut), but points at zsh's OWN fragment
# directory instead (user's explicit 2026-08-18 request: universal alias
# name, per-shell target). Deliberately NOT shared via 00-shared.zsh's list —
# the whole point is that bash and zsh need different values here.
alias brc="cd ~/.zshrc.d"
