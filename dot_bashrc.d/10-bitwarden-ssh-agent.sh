#!/usr/bin/env bash
# Bitwarden desktop app's SSH agent — common to both profiles (one Bitwarden
# instance, shared across personal and work SSH keys). macOS-only path (app
# sandbox container layout) — Linux/Windows Bitwarden desktop uses a
# different location, not covered yet since no Linux/Windows machine needs
# this today. Mirrors dot_zshrc.d/10-bitwarden-ssh-agent.zsh.
if [ "$(uname -s)" = "Darwin" ]; then
    export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
fi
