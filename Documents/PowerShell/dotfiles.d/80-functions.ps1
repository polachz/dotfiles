# Shared interactive PowerShell function library — mirrors
# dot_bashrc.d/80-functions-common.sh's role for bash/zsh.

# Create a directory (and any missing parents) and cd into it in one step.
function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -Path $Path
}
