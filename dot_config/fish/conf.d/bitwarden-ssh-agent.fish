# Bitwarden desktop app's SSH agent — common to both profiles (one Bitwarden
# instance, shared across personal and work SSH keys). macOS path — verified
# live on Maclab 2026-08-14 (a real, live socket flat in $HOME, the app
# isn't sandboxed there). Linux path added 2026-08-18, NOT yet live-verified
# — see dot_zshrc.d/10-bitwarden-ssh-agent.zsh for the full reasoning
# (inferred from this repo's non-sandboxed .tar.gz Linux install avoiding
# Flatpak/Snap specifically). Windows still not covered. Mirrors
# dot_zshrc.d/10-bitwarden-ssh-agent.zsh.
if test (uname -s) = Darwin -o (uname -s) = Linux
    set -gx SSH_AUTH_SOCK "$HOME/.bitwarden-ssh-agent.sock"
end
