#!/usr/bin/env zsh
# Bitwarden desktop app's SSH agent — common to both profiles (one Bitwarden
# instance, shared across personal and work SSH keys). Migrated from the
# user's real ~/.zshrc (2026-08-01) — original hardcoded the username in the
# path, using $HOME instead for portability. macOS-only path (app sandbox
# container layout) — Linux/Windows Bitwarden desktop uses a different
# location, not covered yet since no Linux/Windows machine needs this today.
if [ "$(uname -s)" = "Darwin" ]; then
    export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
fi
