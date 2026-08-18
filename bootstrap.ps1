#Requires -Version 5.1
<#
Self-contained dotfiles bootstrap for Windows — PowerShell sibling of
bootstrap.sh (macOS/Linux). Mirrors its structure/flags/env-var names as
closely as PowerShell idiom allows, so the two stay easy to compare.

Downloaded/run directly (irm ... | iex, or saved+run) — must not depend on
any other repo file being present locally already, same self-containment
rule as bootstrap.sh.

One real, load-bearing difference from bootstrap.sh: Windows has no EJSON/
Age install path yet (a known, tracked gap — see CONCEPT_ROADMAP.md), so
the encrypted evault chain (currently only used for per-profile git
identity) can't work here today. This script does NOT try to fake that —
it runs the same `chezmoi init --apply` bootstrap.sh uses, and if that
fails specifically because of the missing `ejson` binary, treats it as a
known/expected partial-failure rather than a fatal error: it warns clearly,
then explicitly re-runs the two scripts that matter most for a usable
shell (PowerShell $PROFILE sourcing, winget package install) so the rest
of the environment still ends up in a fully working state.
#>

[CmdletBinding()]
param(
    # NOT named $Profile - PowerShell variables are case-insensitive, so a
    # parameter named $Profile silently SHADOWS the built-in $PROFILE
    # automatic variable (the current user's $PROFILE path) for the rest of
    # the script. Verified live the hard way: with -Profile work, every
    # later use of $PROFILE inside this script silently became the string
    # "work" instead of a path, so Test-Path/Split-Path/Add-Content all
    # operated on nonsense instead of the real profile file - no error,
    # just silently wrong, hardest possible bug to spot from the symptoms
    # alone.
    [Alias("Profile")]
    [ValidateSet("personal", "work")]
    [string]$DotfilesProfile,

    [ValidateSet("workstation", "server")]
    [string]$Role,

    [ValidateSet("yes", "no")]
    [string]$Gui,

    [string]$Branch,

    [switch]$DryRun,
    [switch]$Apply,
    [switch]$Reinit,
    [switch]$ChezmoiDebug,
    [switch]$DebugAll,
    [switch]$Help
)

$GithubUsername = "polachz"

# ───── Helpers ─────────────────────────────────────────────────────────────

function Write-LogColor { param([string]$Color, [string]$Text) Write-Host $Text -ForegroundColor $Color }
function Write-LogTask  { param([string]$Text) Write-LogColor Blue   "🔃 $Text" }
function Write-LogInfo  { param([string]$Text) Write-LogColor Blue   "🔵 $Text" }
function Write-LogWarn  { param([string]$Text) Write-LogColor Yellow "⚠️  $Text" }
function Write-LogError { param([string]$Text) Write-LogColor Red    "❌ $Text" }
function Exit-WithError { param([string]$Text) Write-LogError $Text; exit 1 }

# ───── Help ──────────────────────────────────────────────────────────────

if ($Help) {
    @"
Usage: bootstrap.ps1 [options]

Options:
  -Profile <personal|work>      Pre-select dotfiles profile (skip menu)
  -Role <workstation|server>    Pre-select machine role (skip menu)
  -Gui <yes|no>                 Pre-select GUI presence (skip menu)
  -Branch <name>                Clone/checkout this git branch instead of
                                  the default branch
  -DryRun                       Run chezmoi in dry-run mode
  -Apply                        Force apply (overrides default on re-runs)
  -Reinit                       Clear chezmoi state and re-apply from scratch
  -ChezmoiDebug                 Pass --debug to chezmoi itself
  -DebugAll                     Both -Verbose and -ChezmoiDebug
  -Help                         Show this message

Env vars (same names as bootstrap.sh, for consistency):
  CHZ_DEPLOYMENT_PROFILE, CHZ_DEPLOYMENT_ROLE, CHZ_HAS_GUI,
  CHZ_BOOTSTRAP_BRANCH, CHZ_BOOTSTRAP_DRY_RUN, CHZ_BOOTSTRAP_VERBOSE,
  CHZ_DOTFILES_DEBUG
"@
    exit 0
}

# ───── Resolve CLI/env inputs ───────────────────────────────────────────────
# Same precedence as bootstrap.sh: explicit flag > env var > interactive menu.

$deploymentProfile = if ($DotfilesProfile) { $DotfilesProfile } else { $env:CHZ_DEPLOYMENT_PROFILE }
$deploymentRole    = if ($Role)    { $Role }    else { $env:CHZ_DEPLOYMENT_ROLE }
$hasGuiChoice      = if ($Gui)     { $Gui }     else { $env:CHZ_HAS_GUI }
$bootstrapBranch   = if ($Branch)  { $Branch }  else { $env:CHZ_BOOTSTRAP_BRANCH }
$dryRun            = $DryRun.IsPresent   -or ($env:CHZ_BOOTSTRAP_DRY_RUN -eq "1")
$verboseOut        = $VerbosePreference -ne "SilentlyContinue" -or ($env:CHZ_BOOTSTRAP_VERBOSE -eq "1") -or $DebugAll.IsPresent
$chezmoiDebug      = $ChezmoiDebug.IsPresent -or $DebugAll.IsPresent
$forceApply        = $Apply.IsPresent

# ───── Resolve profile ───────────────────────────────────────────────────────

if (-not $deploymentProfile) {
    while ($true) {
        Write-Host "Select dotfiles profile:`n"
        Write-Host "  1) Personal - private machines, personal email/git/ssh identity"
        Write-Host "  2) Work     - work machines, work email/git/ssh identity"
        Write-Host "  e) Exit`n"
        $choice = Read-Host "Enter your choice"
        switch ($choice) {
            "1" { $deploymentProfile = "personal"; break }
            "2" { $deploymentProfile = "work"; break }
            { $_ -in "e", "exit" } { Write-Host "Aborted."; exit 0 }
            default { Write-Host "Invalid selection. Please try again."; continue }
        }
        if ($deploymentProfile) { break }
    }
}
if ($deploymentProfile -notin "personal", "work") {
    Exit-WithError "Invalid -Profile: '$deploymentProfile' (must be 'personal' or 'work')"
}
Write-LogInfo "Selected profile: $deploymentProfile"

# ───── Resolve role ──────────────────────────────────────────────────────────

if (-not $deploymentRole) {
    while ($true) {
        Write-Host "Select machine role:`n"
        Write-Host "  1) Workstation - desktop/laptop dev machine"
        Write-Host "  2) Server      - headless/server machine"
        Write-Host "  e) Exit`n"
        $choice = Read-Host "Enter your choice"
        switch ($choice) {
            "1" { $deploymentRole = "workstation"; break }
            "2" { $deploymentRole = "server"; break }
            { $_ -in "e", "exit" } { Write-Host "Aborted."; exit 0 }
            default { Write-Host "Invalid selection. Please try again."; continue }
        }
        if ($deploymentRole) { break }
    }
}
if ($deploymentRole -notin "workstation", "server") {
    Exit-WithError "Invalid -Role: '$deploymentRole' (must be 'workstation' or 'server')"
}
Write-LogInfo "Selected role: $deploymentRole"

# ───── Resolve GUI presence ──────────────────────────────────────────────────

if (-not $hasGuiChoice) {
    while ($true) {
        Write-Host "Does this machine have a GUI?`n"
        Write-Host "  1) Yes"
        Write-Host "  2) No"
        Write-Host "  e) Exit`n"
        $choice = Read-Host "Enter your choice"
        switch ($choice) {
            "1" { $hasGuiChoice = "yes"; break }
            "2" { $hasGuiChoice = "no"; break }
            { $_ -in "e", "exit" } { Write-Host "Aborted."; exit 0 }
            default { Write-Host "Invalid selection. Please try again."; continue }
        }
        if ($hasGuiChoice) { break }
    }
}
if ($hasGuiChoice -notin "yes", "no") {
    Exit-WithError "Invalid -Gui: '$hasGuiChoice' (must be 'yes' or 'no')"
}
Write-LogInfo "Has GUI: $hasGuiChoice"

# ───── Ensure winget ─────────────────────────────────────────────────────────

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Exit-WithError "winget was not found. It ships with Windows 11/recent Windows 10 (App Installer) - install it from the Microsoft Store, then re-run."
}

# ───── Install chezmoi + git via winget ──────────────────────────────────────
# No CLT/Homebrew/tar-style prerequisite dance needed here - winget already
# has both as real packages (twpayne.chezmoi, Git.Git), verified live
# 2026-08-18. Refresh $env:Path from the registry after each install so
# this same script session can use them immediately, without requiring the
# user to open a new shell (winget updates the registry PATH, not the
# current process's copy of it).

function Update-SessionPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-LogTask "Installing chezmoi via winget..."
    winget install -e --id twpayne.chezmoi --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
    Update-SessionPath
    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        Exit-WithError "chezmoi install via winget appears to have failed - check the output above and re-run."
    }
    Write-LogInfo "chezmoi installed successfully."
} else {
    Write-LogInfo "chezmoi already installed."
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-LogTask "Installing git via winget..."
    winget install -e --id Git.Git --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
    Update-SessionPath
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Exit-WithError "git install via winget appears to have failed - check the output above and re-run."
    }
    Write-LogInfo "git installed successfully."
} else {
    Write-LogInfo "git already installed."
}

# ───── EJSON — known, tracked gap on Windows ─────────────────────────────────
# No install attempted here at all (unlike bootstrap.sh's macOS/Linux
# branches) - there is no first-party EJSON Windows binary, and no fallback
# has been built yet. This means the encrypted evault chain (today: only
# per-profile git identity) can't resolve - handled below as an expected,
# non-fatal partial failure of the main chezmoi apply, not pretended away.
if (-not (Get-Command ejson -ErrorAction SilentlyContinue)) {
    Write-LogWarn "ejson is not available on Windows yet (known gap - see CONCEPT_ROADMAP.md). Git identity (user.name/user.email from the encrypted evault) will NOT be configured by this run."
}

# ───── Run chezmoi ────────────────────────────────────────────────────────────

Write-LogTask "Preparing chezmoi run..."

if ($Reinit) {
    chezmoi state delete-bucket --bucket=entryState 2>$null | Out-Null
    chezmoi update --init
}

$chezmoiArgs = @("init")
if ($forceApply) {
    $chezmoiArgs += "--apply"
} elseif ($dryRun) {
    $chezmoiArgs += "--dry-run"
} else {
    if ($bootstrapBranch) {
        Write-LogInfo "Using branch: $bootstrapBranch"
        $chezmoiArgs += @("--branch", $bootstrapBranch)
    }
    $chezmoiArgs += @("--apply", "https://github.com/$GithubUsername/dotfiles.git")
}

if ($chezmoiDebug) {
    $chezmoiArgs += "--debug"
} elseif ($verboseOut) {
    $chezmoiArgs += "--verbose"
}

$env:DOTFILES_PROFILE = $deploymentProfile
$env:DOTFILES_ROLE = $deploymentRole
$env:DOTFILES_HAS_GUI = if ($hasGuiChoice -eq "yes") { "true" } else { "false" }

Write-LogTask "Running 'chezmoi $($chezmoiArgs -join ' ')' (profile=$deploymentProfile, role=$deploymentRole, gui=$hasGuiChoice)"

$chezmoiOutput = & chezmoi @chezmoiArgs 2>&1 | ForEach-Object { Write-Host $_; $_ }
$chezmoiExit = $LASTEXITCODE

if ($chezmoiExit -eq 0) {
    Write-LogInfo "Bootstrap complete."
    exit 0
}

# ───── Recover from the known ejson-related partial failure ─────────────────
# Verified live (2026-08-18): a combined `chezmoi init --apply` aborts the
# ENTIRE regular-file-apply phase at the first template error, not just the
# one failing entry — `Documents/PowerShell/dotfiles.d` (needed for every
# alias/function/prompt) never got created, even though it sorts well after
# `.config/git` and has nothing to do with it. Retrying with `chezmoi apply`
# alone doesn't help either, since it hits the exact same error every time.
#
# Fix: apply every top-level managed entry INDIVIDUALLY, explicitly skipping
# only `.config/git` (the one path that needs the evault chain) — not a
# hardcoded list of "the important paths", so this keeps working if the
# repo's top-level layout changes later. `.chezmoiscripts` itself is never a
# valid apply target (it's not a real target path, just where scripts live)
# so it's skipped too; its scripts are re-run explicitly afterward instead.

$knownGap = $chezmoiOutput -join "`n" | Select-String -Pattern "ejson" -Quiet

if (-not $knownGap) {
    Exit-WithError "chezmoi init/apply failed for a reason other than the known missing-ejson gap - see the output above."
}

Write-LogWarn "chezmoi apply hit the known missing-ejson gap (git identity skipped). Applying everything else individually, then re-running the affected scripts..."

$sourcePath = chezmoi source-path
$homeFwd = $HOME -replace '\\', '/'
$managed = chezmoi managed --path-style absolute | ForEach-Object { $_ -replace '\\', '/' }
$topLevelEntries = $managed | ForEach-Object { ($_.Substring($homeFwd.Length + 1) -split '/')[0] } | Sort-Object -Unique

foreach ($entry in $topLevelEntries) {
    if ($entry -eq ".chezmoiscripts") {
        continue
    } elseif ($entry -eq ".config") {
        $configChildren = $managed | Where-Object { $_ -like "$homeFwd/.config/*" } |
            ForEach-Object { ($_.Substring("$homeFwd/.config/".Length) -split '/')[0] } | Sort-Object -Unique
        foreach ($child in $configChildren) {
            if ($child -eq "git") { continue }
            chezmoi apply --exclude=scripts "$homeFwd/.config/$child" 2>&1 | Out-Null
        }
    } else {
        chezmoi apply --exclude=scripts "$homeFwd/$entry" 2>&1 | Out-Null
    }
}

# $PROFILE sourcing done directly, natively, NOT by re-rendering and piping
# through `chezmoi execute-template` — verified live (repeatedly, and
# non-deterministically) that piping a native chezmoi subprocess's output
# into Out-File and then invoking the result was unreliable in this nested-
# script context specifically: it silently produced a rendered script that
# didn't take effect on some runs and worked fine on others, root cause not
# pinned down (likely a native-command stdio interaction after several
# prior chezmoi subprocess calls in the same session). Without a working
# $PROFILE nothing else in this bootstrap matters, so this one critical,
# simple, stable piece of logic is inlined natively instead of depending on
# that pipeline at all. Mirrors
# .chezmoiscripts/run_after_ensure-powershell-profile-sourcing.ps1.tmpl
# exactly — keep both in sync if that template's logic ever changes.
Write-LogTask "Ensuring `$PROFILE sources dotfiles.d..."
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
$existingProfileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
if (-not $existingProfileContent -or $existingProfileContent -notmatch 'dotfiles\.d') {
    $profileBlock = @'

# Added by dotfiles bootstrap - sources Documents\PowerShell\dotfiles.d\*.ps1
# (see CONCEPT_ROADMAP.md 2.1/2.3/2.4/3.3 for why this file itself is never
# fully owned by chezmoi).
$dotfilesD = Join-Path (Split-Path $PROFILE) 'dotfiles.d'
if (Test-Path $dotfilesD) {
    Get-ChildItem "$dotfilesD\*.ps1" | ForEach-Object { . $_.FullName }
}
'@
    Add-Content -Path $PROFILE -Value $profileBlock
}
if (-not (Select-String -Path $PROFILE -Pattern 'dotfiles\.d' -Quiet)) {
    Exit-WithError "Failed to set up `$PROFILE sourcing - check $PROFILE manually."
}
Write-LogInfo "`$PROFILE OK."

# Packages script re-run via the normal render-and-execute path — lower
# stakes than $PROFILE above (every install it does is independently
# idempotent, and simply not running here just means winget installs
# happen on the next real `chezmoi apply` instead), so the same pipeline
# reliability concern isn't worth hand-inlining this one too.
$packagesTemplatePath = Join-Path $sourcePath ".chezmoiscripts/run_onchange_install-packages.ps1.tmpl"
if (Test-Path $packagesTemplatePath) {
    Write-LogTask "Re-running package install..."
    $renderedPath = Join-Path $env:TEMP "dotfiles-bootstrap-packages.ps1"
    $renderResult = Get-Content $packagesTemplatePath -Raw | chezmoi execute-template -S $sourcePath 2>&1
    $renderResult | Out-File -FilePath $renderedPath -Encoding utf8
    & $renderedPath
    Remove-Item $renderedPath -Force -ErrorAction SilentlyContinue
}

Write-LogInfo "Bootstrap complete, EXCEPT git identity (user.name/user.email) - see the ejson warning above. Everything else (shell aliases/functions/prompt, packages) should be working - open a new PowerShell session to pick it up."
