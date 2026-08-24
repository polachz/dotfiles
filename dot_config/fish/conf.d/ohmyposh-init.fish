# Oh My Posh — only activates if actually installed. Fish has no separate
# classic-prompt file to override (unlike zsh's 99-prompt.zsh), since
# `oh-my-posh init fish | source` simply redefines `fish_prompt` directly —
# no load-order concern here. Theme is vendored in the repo (see
# dot_config/oh-my-posh/atomic.omp.json) rather than relying on
# package-manager-specific bundled theme paths, which differ across
# brew/dnf/winget installs.
if command -q oh-my-posh
    oh-my-posh init fish --config "$HOME/.config/oh-my-posh/atomic.omp.json" | source
end
