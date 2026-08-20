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
#
# Checks the app is actually INSTALLED, not whether the socket currently
# exists — the socket only appears once Bitwarden has launched, and at
# shell-init time (e.g. right after login, before its autostart entry has
# run) it often won't exist yet even on a real Bitwarden machine. Gating on
# the socket itself would leave SSH_AUTH_SOCK unset for that whole session.
# Gating on the installed app instead restores the tolerant old behavior
# (the path is set before the socket exists, which is fine — nothing reads
# it until an actual ssh/git operation happens) while still skipping
# entirely on machines that never have Bitwarden at all (servers, headless
# boxes), which is the case that was actually clobbering a real ssh-agent.
case "$(uname -s)" in
    Darwin)
        if [ -d "/Applications/Bitwarden.app" ]; then
            export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
        fi
        ;;
    Linux)
        if [ -x "$HOME/.local/share/bitwarden/bitwarden" ]; then
            export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
        fi
        ;;
esac
