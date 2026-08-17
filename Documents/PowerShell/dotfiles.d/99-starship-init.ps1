# Layers on top of the native prompt wherever starship is actually
# installed — same pattern as dot_zshrc.d/99-starship-init.zsh and
# dot_config/fish/conf.d/starship-init.fish. `Out-String | Invoke-Expression`
# is the standard PowerShell idiom for starship's init output (a multi-line
# function definition) — verified live on winlab.local (`winget install
# --id Starship.Starship`), real colored prompt confirmed rendering.
if (Get-Command starship -ErrorAction SilentlyContinue) {
    starship init powershell | Out-String | Invoke-Expression
}

# Switch the active Starship prompt theme for the current shell session —
# session-only (sets $env:STARSHIP_CONFIG); add a call to this in $PROFILE
# yourself if you want a theme to persist across new shells. See
# dot_config/starship/{atomic,jandedobbeleer}.toml for the available
# alternates to the default ~/.config/starship.toml (Pastel Powerline).
function starship-theme {
    param([string]$Name)
    switch ($Name) {
        { $_ -in @('pastel', 'default', '') } {
            Remove-Item Env:\STARSHIP_CONFIG -ErrorAction SilentlyContinue
        }
        { $_ -in @('atomic', 'jandedobbeleer') } {
            $env:STARSHIP_CONFIG = Join-Path $HOME ".config/starship/$Name.toml"
        }
        default {
            Write-Error "Usage: starship-theme <pastel|atomic|jandedobbeleer>"
        }
    }
}
