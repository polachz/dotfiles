# Keep user-local tools reachable in fish sessions.
# --global changes only this shell and avoids fish universal-variable writes.
fish_add_path --global --path --prepend "$HOME/.local/bin"
