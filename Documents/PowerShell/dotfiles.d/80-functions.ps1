# Shared interactive PowerShell function library — mirrors
# dot_bashrc.d/80-functions-common.sh's role for bash/zsh.

# Create a directory (and any missing parents) and cd into it in one step.
function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -Path $Path
}

# Chezmoi shortcuts — mirrors dot_bashrc.d/chezmoi-aliases (bash/zsh). No
# `history -a`-style flush needed: PowerShell's history isn't lost the same
# way on a chezmoi-triggered restart.
function ch { chezmoi @args }
function chd { chezmoi cd @args }

# Shell config directory shortcut — same alias name as bash/zsh/fish's `brc`,
# points at PowerShell's own dotfiles fragment directory (user's explicit
# 2026-08-18 request: universal alias name, per-shell target).
function brc { Set-Location "$HOME/Documents/PowerShell/dotfiles.d" }

# --- Extra convenience functions (2026-08-18) ---
# Cross-shell ports of dot_bashrc.d/85-functions-extra.sh / the matching
# fish functions — see those files' comments for the reasoning behind each
# design choice (tar auto-detect, python3 being untracked, etc.).

# Extract almost any archive based on its file extension. tar.exe (bundled
# with Windows 10 1803+/Win11, libarchive-based like macOS's bsdtar)
# auto-detects gzip/bzip2/xz the same way — verified for macOS/Linux in the
# bash/fish versions, same underlying tar implementation family.
function unpack {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Error "unpack: '$Path' is not a valid file"
        return
    }
    switch -Regex ($Path) {
        '\.(tar|tar\.gz|tgz|tar\.bz2|tbz2|tar\.xz|txz)$' { tar.exe xf $Path }
        '\.zip$' { Expand-Archive -Path $Path -DestinationPath . -Force }
        '\.7z$' { & 7z x $Path }
        '\.rar$' { & unrar x $Path }
        default { Write-Error "unpack: don't know how to extract '$Path'" }
    }
}

# Copy a file/dir to a timestamped .bak sibling.
function backup {
    param([Parameter(Mandatory)][string]$Path)
    Copy-Item -Recurse -Path $Path -Destination "$Path.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
}

# Serve the current directory over HTTP. Checks both python3 and python —
# a Windows Python install commonly only puts `python` on PATH.
function serve {
    param([int]$Port = 8000)
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) { Write-Error "serve: python3/python not found on PATH"; return }
    & $py.Source -m http.server $Port
}

# Quick weather report via wttr.in. curl.exe explicitly — PowerShell aliases
# bare `curl` to Invoke-WebRequest, which doesn't understand `-s`.
function weather {
    param([string]$Location = "")
    curl.exe -s "wttr.in/$Location"
}

# git clone then cd into the resulting directory. Splitting on '/' rather
# than System.IO.Path methods avoids any URL-vs-filesystem-path parsing
# edge cases (double slashes in "https://", etc.).
function gclone {
    param([Parameter(Mandatory)][string]$Url)
    $dir = ($Url.TrimEnd('/') -split '/')[-1] -replace '\.git$', ''
    git clone $Url
    if ($?) { Set-Location $dir }
}

# Print $PATH one entry per line.
function pathlist {
    $env:Path -split ';'
}

# cd up N directories (default 1).
function up {
    param([int]$Levels = 1)
    $target = (Get-Location).Path
    for ($i = 0; $i -lt $Levels; $i++) { $target = Split-Path $target -Parent }
    Set-Location $target
}

# Find and kill whatever process listens on a TCP port.
function killport {
    param([Parameter(Mandatory)][int]$Port)
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if (-not $conns) {
        Write-Error "killport: nothing listening on port $Port"
        return
    }
    $conns | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force }
}

# Pretty-print JSON — native ConvertFrom-Json/ConvertTo-Json, no jq needed
# on Windows (jq is a workstation-only package on dnf/apt/brew only).
function json {
    param([string]$Path)
    if ($Path) {
        Get-Content $Path -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 10
    } else {
        $input | ConvertFrom-Json | ConvertTo-Json -Depth 10
    }
}

# Delete local git branches already merged into the default branch — same
# detection/safety-net logic as the bash/fish versions.
function gclean {
    $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($defaultBranch) { $defaultBranch = $defaultBranch -replace '^refs/remotes/origin/', '' } else { $defaultBranch = 'main' }
    git branch --merged $defaultBranch |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notmatch '^\*' -and $_ -notin @($defaultBranch, 'main', 'master') } |
        ForEach-Object { git branch -d $_ }
}

# Quick cheatsheet lookup via cheat.sh.
function cheat {
    param([string]$Topic)
    curl.exe -s "cheat.sh/$Topic"
}
