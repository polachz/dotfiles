# Global definitions also survive a profile reload from inside ch update.
function global:unlock-bw {
    [System.Diagnostics.DebuggerHidden()]
    param()

    $bw = Get-Command bw -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $bw) {
        throw 'Bitwarden CLI (bw) is required.'
    }
    $PSNativeCommandUseErrorActionPreference = $false
    if ($env:BW_SESSION) {
        & $bw unlock --check *> $null
        if ($LASTEXITCODE -eq 0) { return }
    }
    & $bw login --check > $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Check your Bitwarden CLI login with bw login.'
    }

    $bwKey = & $bw unlock --raw
    if ($LASTEXITCODE -ne 0) {
        throw "Bitwarden CLI unlock failed (exit code $LASTEXITCODE)."
    }
    if ($bwKey -isnot [string] -or $bwKey -cnotmatch '\A[A-Za-z0-9+/=_-]+\z') {
        throw 'Invalid Bitwarden session response.'
    }

    $previousKey = $env:BW_SESSION
    $accepted = $false
    try {
        $env:BW_SESSION = $bwKey
        & $bw unlock --check *> $null
        if ($LASTEXITCODE -ne 0) {
            throw 'Bitwarden CLI did not accept the new session key.'
        }
        $accepted = $true
    } finally {
        if (-not $accepted) { $env:BW_SESSION = $previousKey }
    }
}

function global:lock-bw {
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        $bw = Get-Command bw -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $bw) {
            throw 'Bitwarden CLI (bw) is required.'
        }
        & $bw lock
        if ($LASTEXITCODE -ne 0) {
            throw "Bitwarden CLI lock failed (exit code $LASTEXITCODE)."
        }
    } finally {
        $env:BW_SESSION = $null
    }
}
