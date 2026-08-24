# Bitwarden desktop app's SSH agent — common to both profiles (one Bitwarden
# instance, shared across personal and work SSH keys). macOS path — verified
# live on Maclab 2026-08-14 (a real, live socket flat in $HOME, the app
# isn't sandboxed there). Linux path added 2026-08-18, NOT yet live-verified
# — see dot_zshrc.d/10-bitwarden-ssh-agent.zsh for the full reasoning
# (inferred from this repo's non-sandboxed .tar.gz Linux install avoiding
# Flatpak/Snap specifically). Windows still not covered. Mirrors
# dot_zshrc.d/10-bitwarden-ssh-agent.zsh.
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
switch (uname -s)
    case Darwin
        if test -d "/Applications/Bitwarden.app"
            set -gx SSH_AUTH_SOCK "$HOME/.bitwarden-ssh-agent.sock"
        end
    case Linux
        if test -x "$HOME/.local/share/bitwarden/bitwarden"
            set -gx SSH_AUTH_SOCK "$HOME/.bitwarden-ssh-agent.sock"
        end
end
