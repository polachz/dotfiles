#!/usr/bin/env zsh
# Google Cloud SDK shell integration — work-only (see CONCEPT_ROADMAP.md §1).
# Migrated from the user's real ~/.zshrc (2026-08-01) — the original hardcoded
# an absolute path with the username baked in; using $HOME instead so this
# actually works if replayed on a different account.
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi
