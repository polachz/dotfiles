# Layers on top of the native prompt wherever oh-my-posh is actually
# installed — same pattern as dot_zshrc.d/99-theme-init.zsh and
# dot_config/fish/conf.d/ohmyposh-init.fish. Theme is vendored in the repo
# (see dot_config/oh-my-posh/atomic.omp.json) rather than relying on
# package-manager-specific bundled theme paths (winget's $env:POSH_THEMES_PATH
# vs. brew's/dnf's differently-versioned install layout).
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config (Join-Path $HOME ".config/oh-my-posh/atomic.omp.json") | Out-String | Invoke-Expression
}
