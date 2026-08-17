#!/usr/bin/env zsh
# Oh My Posh — optional layer on top of the classic prompt (99-prompt.zsh),
# only if actually installed (see CONCEPT_ROADMAP.md §6). Named "theme-init",
# not "ohmyposh-init" — confirmed live that "99-ohmyposh-init.zsh" sorts
# BEFORE "99-prompt.zsh" alphabetically ('o' < 'p'), which would let the
# classic prompt's PROMPT assignment load after and silently win back over
# oh-my-posh's. "99-theme-init.zsh" sorts after ('t' > 'p'), same effect
# "99-starship-init.zsh" got by coincidence before this. Theme is vendored
# in the repo (see dot_config/oh-my-posh/atomic.omp.json) rather than
# relying on package-manager-specific bundled theme paths, which differ
# across brew/dnf/winget installs.
if command -v oh-my-posh >/dev/null 2>&1; then
    eval "$(oh-my-posh init zsh --config "$HOME/.config/oh-my-posh/atomic.omp.json")"
fi
