# Layers on top of the native prompt wherever starship is actually
# installed — same pattern as dot_zshrc.d/99-starship-init.zsh and
# dot_config/fish/conf.d/starship-init.fish. `Out-String | Invoke-Expression`
# is the standard PowerShell idiom for starship's init output (a multi-line
# function definition) — verified live on winlab.local (`winget install
# --id Starship.Starship`), real colored prompt confirmed rendering.
if (Get-Command starship -ErrorAction SilentlyContinue) {
    starship init powershell | Out-String | Invoke-Expression
}
