# Shared interactive PowerShell function library — mirrors
# dot_bashrc.d/80-functions-common.sh's role for bash/zsh.
#
# Every function here uses `function global:<name>`, not plain `function
# <name>` — confirmed live 2026-08-20: `ch update`'s auto-reload
# (`. $PROFILE`, see dot_bashrc.d/chezmoi-aliases's comment) dot-sources
# from INSIDE the `ch` function's own local scope, and PowerShell places a
# dot-sourced script's functions into "the scope from which the dot
# sourcing command was run" — `ch`'s local scope, discarded the moment `ch`
# returns. Without `global:`, a function picked up that way never actually
# reaches the interactive session, even though the reload itself reports
# success. Same fix applied to 50-aliases-generated.ps1.tmpl.

# Create a directory (and any missing parents) and cd into it in one step.
function global:mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -Path $Path
}

# Chezmoi shortcuts — mirrors dot_bashrc.d/chezmoi-aliases (bash/zsh). No
# `history -a`-style flush needed: PowerShell's history isn't lost the same
# way on a chezmoi-triggered restart.
#
# `ch update` specifically auto-reloads afterward (re-sources $PROFILE,
# same mechanism as the `reload` alias) — otherwise newly added/changed
# functions/aliases from the pulled commits aren't visible until the shell
# is manually restarted (real pain point hit live 2026-08-20, after several
# rounds of "ch update" not showing fixes until PowerShell was killed and
# reopened).
function global:ch {
    chezmoi @args
    if ($args[0] -eq 'update' -and $LASTEXITCODE -eq 0) {
        . $PROFILE
    }
}
function global:chd { chezmoi cd @args }

# Shell config directory shortcut — same alias name as bash/zsh/fish's `brc`,
# points at PowerShell's own dotfiles fragment directory (user's explicit
# 2026-08-18 request: universal alias name, per-shell target).
function global:brc { Set-Location "$HOME/Documents/PowerShell/dotfiles.d" }

# --- Extra convenience functions (2026-08-18) ---
# Cross-shell ports of dot_bashrc.d/85-functions-extra.sh / the matching
# fish functions — see those files' comments for the reasoning behind each
# design choice (tar auto-detect, python3 being untracked, etc.).

# Extract almost any archive based on its file extension. tar.exe (bundled
# with Windows 10 1803+/Win11, libarchive-based like macOS's bsdtar)
# auto-detects gzip/bzip2/xz the same way — verified for macOS/Linux in the
# bash/fish versions, same underlying tar implementation family.
function global:unpack {
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
function global:backup {
    param([Parameter(Mandatory)][string]$Path)
    Copy-Item -Recurse -Path $Path -Destination "$Path.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
}

# Serve the current directory over HTTP. Checks both python3 and python —
# a Windows Python install commonly only puts `python` on PATH.
function global:serve {
    param([int]$Port = 8000)
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) { Write-Error "serve: python3/python not found on PATH"; return }
    & $py.Source -m http.server $Port
}

# Quick weather report via wttr.in. curl.exe explicitly — PowerShell aliases
# bare `curl` to Invoke-WebRequest, which doesn't understand `-s`.
function global:weather {
    param([string]$Location = "")
    curl.exe -s "wttr.in/$Location"
}

# git clone then cd into the resulting directory. Splitting on '/' rather
# than System.IO.Path methods avoids any URL-vs-filesystem-path parsing
# edge cases (double slashes in "https://", etc.).
function global:gclone {
    param([Parameter(Mandatory)][string]$Url)
    $dir = ($Url.TrimEnd('/') -split '/')[-1] -replace '\.git$', ''
    git clone $Url
    if ($?) { Set-Location $dir }
}

# Print $PATH one entry per line.
function global:pathlist {
    $env:Path -split ';'
}

# cd up N directories (default 1).
function global:up {
    param([int]$Levels = 1)
    $target = (Get-Location).Path
    for ($i = 0; $i -lt $Levels; $i++) { $target = Split-Path $target -Parent }
    Set-Location $target
}

# Find and kill whatever process listens on a TCP port.
function global:killport {
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
function global:json {
    param([string]$Path)
    if ($Path) {
        Get-Content $Path -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 10
    } else {
        $input | ConvertFrom-Json | ConvertTo-Json -Depth 10
    }
}

# Delete local git branches already merged into the default branch — same
# detection/safety-net logic as the bash/fish versions.
function global:gclean {
    $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($defaultBranch) { $defaultBranch = $defaultBranch -replace '^refs/remotes/origin/', '' } else { $defaultBranch = 'main' }
    git branch --merged $defaultBranch |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notmatch '^\*' -and $_ -notin @($defaultBranch, 'main', 'master') } |
        ForEach-Object { git branch -d $_ }
}

# Creates a new git branch and pushes it to the remote with tracking set up
# in one step — same base-branch detection/safety-net logic as the
# bash/fish versions.
function global:gnb {
    param([string]$Name, [string]$Base)
    if (-not $Name) {
        Write-Host "usage: gnb <branch-name> [base-branch|@]" -ForegroundColor Yellow
        return
    }
    if (-not $Base) {
        $Base = git symbolic-ref refs/remotes/origin/HEAD 2>$null
        if ($Base) { $Base = $Base -replace '^refs/remotes/origin/', '' } else { $Base = 'main' }
    } elseif ($Base -eq '@') {
        $Base = 'HEAD'
    }
    git rev-parse --verify --quiet $Base *>$null
    if ($LASTEXITCODE -ne 0) { $Base = "origin/$Base" }
    git switch -c $Name $Base
    if ($LASTEXITCODE -eq 0) { git push -u origin $Name }
}

# Quick cheatsheet lookup via cheat.sh.
function global:cheat {
    param([string]$Topic)
    curl.exe -s "cheat.sh/$Topic"
}

# Search shell history for a pattern. `ghi` always works; `gh` is only
# defined when the real GitHub CLI (`gh.exe`) isn't on PATH — checked fresh
# every time this profile loads (a new pwsh session), so it stops shadowing
# the real tool the moment it's installed, no re-apply needed. See
# dot_bashrc.d/85-functions-extra.sh for the bash/zsh equivalent. User's
# call, 2026-08-20.
function global:ghi {
    param([string]$Pattern)
    Get-History | Out-String -Stream | Select-String $Pattern
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    function global:gh {
        param([string]$Pattern)
        Get-History | Out-String -Stream | Select-String $Pattern
    }
}

# Decrypt, edit, and re-encrypt an EJSON evault in one step — PowerShell
# port of private_dot_local/bin/executable_edit-evault.tmpl (the
# bash/zsh/fish version, which has the full design rationale in its header
# comment; this mirrors it as closely as PowerShell allows). Added
# 2026-08-20 — Windows previously had no way to do this at all (that bash
# script isn't reachable there, see ALIASES.md's `ali` entry).
#
# A FUNCTION here, not a standalone $HOME\bin\edit-evault.ps1 script like
# ejson/7-Zip's installers — PowerShell only auto-invokes a bare `.ps1` by
# name if `.PS1` is in $env:PATHEXT, which it isn't by default (deliberate
# Windows security default, would need `.\edit-evault.ps1` otherwise), so a
# function in this profile-loaded file is invokable by bare name with no
# such caveat — same reason gclean/gnb/ch/json etc. are functions here too.
#
# IMPORTANT — write target: defaults to editing directly in chezmoi's OWN
# source-path ($HOME\.local\share\chezmoi) — that IS a real git repo
# (chezmoi init clones it there), so `chd` (chezmoi cd) + a normal git
# commit/push works from it like any other repo. Simplified 2026-08-20 (was:
# "never use chezmoi's source-path, keep a second dev-repo clone") — see the
# bash edit-evault.tmpl's header for the full reasoning. A second, separate
# clone is still supported via -Repo/$env:DOTFILES_REPO for anyone who wants
# one, just not required anymore.
#
# No tmpfs equivalent on Windows (unlike /dev/shm on Linux/macOS) —
# plaintext briefly touches $env:TEMP while editing; overwritten with
# random bytes before deletion as a best-effort wipe (no shred.exe
# equivalent bundled with Windows).
function global:edit-evault {
    param(
        # NOT $Profile — shadows the built-in $PROFILE automatic variable;
        # see bootstrap.ps1's identical guard (and its comment) for why.
        [Parameter(Position = 0)]
        [Alias("Profile")]
        [ValidateSet("personal", "work")]
        [string]$DotfilesProfile,
        [string]$Repo
    )

    if (-not $DotfilesProfile) {
        Write-Host "Usage: edit-evault <personal|work> [-Repo <path>]" -ForegroundColor Yellow
        return
    }

    if (-not $Repo) { $Repo = $env:DOTFILES_REPO }
    if (-not $Repo -and (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        $Repo = chezmoi source-path 2>$null
        if ($Repo) { Write-Host "Using chezmoi source-path: $Repo" -ForegroundColor Blue }
    }
    if (-not $Repo) {
        Write-Host "No -Repo, `$env:DOTFILES_REPO, or chezmoi source-path found." -ForegroundColor Yellow
        $Repo = Read-Host "Enter dotfiles repo path"
    }

    if (-not (Test-Path $Repo -PathType Container)) {
        Write-Host "Repo path does not exist: $Repo" -ForegroundColor Red
        return
    }
    if (-not (Test-Path (Join-Path $Repo ".chezmoi.yaml.tmpl"))) {
        Write-Host "Not a dotfiles repo (missing .chezmoi.yaml.tmpl): $Repo" -ForegroundColor Red
        return
    }
    if (-not (Test-Path (Join-Path $Repo ".git"))) {
        Write-Host "Repo path has no .git\ — sure this is the right repo? Continuing anyway." -ForegroundColor Yellow
    }

    $evault = Join-Path $Repo "secrets\$DotfilesProfile\evault"
    if (-not (Test-Path $evault)) {
        Write-Host "Evault not found at $evault" -ForegroundColor Red
        return
    }

    $ejsonPub = (Get-Content $evault -Raw | ConvertFrom-Json)._public_key
    $profileUpper = $DotfilesProfile.ToUpper()
    if (-not $ejsonPub -or $ejsonPub -eq "REPLACE_WITH_${profileUpper}_EJSON_PUBLIC_KEY") {
        Write-Host "Evault has no real _public_key — run ENCRYPTION_SETUP.md first" -ForegroundColor Red
        return
    }

    $keysDir = Join-Path $HOME ".config\chezmoi\keys"
    $keyFile = Join-Path $keysDir $ejsonPub
    if (-not (Test-Path $keyFile)) {
        Write-Host "EJSON private key missing at $keyFile" -ForegroundColor Red
        Write-Host "Run 'chezmoi apply' first to unlock the key chain." -ForegroundColor Red
        return
    }

    Write-Host "No tmpfs on Windows — plaintext will briefly touch $env:TEMP" -ForegroundColor Yellow
    $work = Join-Path $env:TEMP "edit-evault-$DotfilesProfile-$PID"
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $tmpFile = Join-Path $work "evault.json"

    try {
        Write-Host "-> Decrypting $DotfilesProfile evault into $work..." -ForegroundColor Blue
        & ejson -keydir $keysDir decrypt $evault > $tmpFile
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ejson decrypt failed" -ForegroundColor Red
            return
        }

        $editorCmd = if ($env:EDITOR) { $env:EDITOR } else { "nano" }
        $hashBefore = (Get-FileHash -Algorithm SHA256 -Path $tmpFile).Hash

        while ($true) {
            Write-Host "-> Opening $editorCmd..." -ForegroundColor Blue
            & $editorCmd $tmpFile

            $hashAfter = (Get-FileHash -Algorithm SHA256 -Path $tmpFile).Hash
            if ($hashBefore -eq $hashAfter) {
                Write-Host "OK: No changes — skipping re-encrypt." -ForegroundColor Green
                return
            }

            $validJson = $true
            try { Get-Content $tmpFile -Raw | ConvertFrom-Json | Out-Null } catch { $validJson = $false }
            if ($validJson) { break }

            Write-Host "Edited file is not valid JSON." -ForegroundColor Red
            $retry = Read-Host "Re-open $editorCmd to fix it? [Y/n]"
            if ($retry -match '^[Nn]') {
                Write-Host "Plaintext is still at $tmpFile; copy your work somewhere before exit" -ForegroundColor Red
                return
            }
        }

        Write-Host "-> Re-encrypting evault into $Repo..." -ForegroundColor Blue
        Copy-Item $tmpFile $evault -Force
        & ejson encrypt $evault
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ejson encrypt failed — evault may be in a broken state" -ForegroundColor Red
            return
        }

        Write-Host "OK: $DotfilesProfile evault updated and re-encrypted in dev repo." -ForegroundColor Green
        Write-Host "Next steps:" -ForegroundColor Blue
        Write-Host "  cd $Repo"
        Write-Host "  git add secrets/$DotfilesProfile/evault; git commit -m 'evault: update $DotfilesProfile'"
        Write-Host "  git push"
        Write-Host "  # On other machines: chezmoi update  (pulls + applies)"
    } finally {
        if (Test-Path $tmpFile) {
            $len = (Get-Item $tmpFile).Length
            if ($len -gt 0) {
                $randomBytes = New-Object byte[] $len
                (New-Object Random).NextBytes($randomBytes)
                [System.IO.File]::WriteAllBytes($tmpFile, $randomBytes)
            }
            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        }
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
