#!/usr/bin/env zsh
# Bitwarden desktop app's SSH agent — common to both profiles (one Bitwarden
# instance, shared across personal and work SSH keys). $HOME instead of a
# hardcoded username for portability. macOS path — verified live on Maclab
# 2026-08-14 (a real, live socket at ~/.bitwarden-ssh-agent.sock; the app
# isn't sandboxed there, so it's flat in $HOME, not under
# ~/Library/Containers/).
#
# Linux path added 2026-08-18, NOT yet live-verified (would need a real
# desktop environment + the SSH agent actually enabled in the app to
# confirm) — inferred from the same non-sandboxed pattern as macOS: this
# repo's Linux install (run_after_install-bitwarden-desktop-linux.sh.tmpl)
# deliberately extracts the official .tar.gz directly rather than using
# Flatpak/Snap specifically to AVOID their sandboxing (Flatpak's own socket
# path is confirmed different — ~/.var/app/com.bitwarden.desktop/data/... —
# precisely because it IS sandboxed). Windows still not covered, no Windows
# machine needs this yet.
case "$(uname -s)" in
    Darwin|Linux)
        export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
        ;;
esac
