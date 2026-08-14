#!/usr/bin/env zsh
# Bitwarden desktop app's SSH agent — common to both profiles (one Bitwarden
# instance, shared across personal and work SSH keys). $HOME instead of a
# hardcoded username for portability. macOS-only path — verified live on
# Maclab 2026-08-14 (a real, live socket at ~/.bitwarden-ssh-agent.sock; the
# app isn't sandboxed there, so it's flat in $HOME, not under
# ~/Library/Containers/). Linux/Windows Bitwarden desktop uses a different
# location, not covered yet since no Linux/Windows machine needs this today.
if [ "$(uname -s)" = "Darwin" ]; then
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
fi
