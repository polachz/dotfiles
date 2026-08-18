#Requires -Version 5.1
<#
Self-contained dotfiles bootstrap for Windows — PowerShell sibling of
bootstrap.sh (macOS/Linux). Mirrors its structure/flags/env-var names as
closely as PowerShell idiom allows, so the two stay easy to compare.

Downloaded/run directly (irm ... | iex, or saved+run) — must not depend on
any other repo file being present locally already, same self-containment
rule as bootstrap.sh.

Installs EJSON from Shopify's GitHub releases (real Windows amd64/arm64
builds exist, no winget package though) alongside chezmoi/git via winget,
then runs the same `chezmoi init --apply` bootstrap.sh uses. The Age/EJSON
key-unlock step that used to be bash-only now has a PowerShell sibling too
(.chezmoiscripts/run_once_before_init_age.ps1.tmpl), so the encrypted
evault chain (per-profile git identity) resolves on Windows the same way
it does on macOS/Linux — no more partial-failure workaround needed here.

Everything lives inside Invoke-DotfilesBootstrap (called at the bottom via
`Invoke-DotfilesBootstrap @args`), NOT in a top-level param() block — found
live (2026-08-18) that `irm <url> | iex` runs the fetched text via
Invoke-Expression IN THE CURRENT SCOPE rather than as a real script/function
invocation, so a top-level `param()` with a [ValidateSet(...)] attribute
gets executed as a plain statement: the typed variable is initialized to ""
first, then the attribute is attached and immediately (wrongly) validated
against that "" — "personal"/"work" isn't in the set, so it throws
"The attribute cannot be added because variable ... would no longer be
valid", even with zero arguments passed. A real function call (even a bare
one with no args) always goes through genuine parameter binding, which
doesn't have this eager-validation-before-assignment behavior — so wrapping
the whole thing in a function and invoking it for real, instead of letting
`iex` execute a param() block inline, fixes it for every invocation style
(bare `irm | iex`, `& ([scriptblock]::Create($script)) -DotfilesProfile
work`, and a saved-then-run `.\bootstrap.ps1 -DotfilesProfile work` — in
all three, $args ends up holding whatever was actually passed, and
`Invoke-DotfilesBootstrap @args` splats it through to the real function
parameters).
#>

function Invoke-DotfilesBootstrap {
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

    # ───── Helpers ─────────────────────────────────────────────────────────

    function Write-LogColor { param([string]$Color, [string]$Text) Write-Host $Text -ForegroundColor $Color }
    function Write-LogTask  { param([string]$Text) Write-LogColor Blue   "🔃 $Text" }
    function Write-LogInfo  { param([string]$Text) Write-LogColor Blue   "🔵 $Text" }
    function Write-LogWarn  { param([string]$Text) Write-LogColor Yellow "⚠️  $Text" }
    function Write-LogError { param([string]$Text) Write-LogColor Red    "❌ $Text" }
    # `throw`, not `exit 1` - `exit` terminates the whole PowerShell PROCESS,
    # not just this function. Harmless for a real `.ps1` file run, but when
    # this script runs via `irm <url> | iex` (its main advertised usage),
    # `iex` executes the fetched text in the CALLER'S OWN process - so `exit`
    # would close the user's entire interactive PowerShell window on any
    # error. Confirmed live 2026-08-18. `throw` propagates a catchable
    # exception instead; the top-level call at the bottom of this file
    # decides whether to actually set a process exit code.
    function Exit-WithError { param([string]$Text) throw $Text }

    # winget/other installers write PATH to the registry, not to this
    # process's already-running copy of $env:Path. Refreshed up front, before
    # any Get-Command check below, not just after our own installs - a tool
    # (git, in particular) may already be present because something else
    # installed it earlier (a previous bootstrap.ps1 run, a different
    # installer, ...) without this specific PowerShell session ever having
    # picked that up. Skipping this and checking against the stale PATH risks
    # a false "not installed" and a redundant reinstall - confirmed live
    # 2026-08-18 as the real cause of an unexpected UAC prompt from `winget
    # install ... Git.Git` re-triggering on a machine that already had git.
    function Update-SessionPath {
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"
    }
    Update-SessionPath

    # ───── Help ──────────────────────────────────────────────────────────

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
        return
    }

    # ───── Resolve CLI/env inputs ───────────────────────────────────────────
    # Same precedence as bootstrap.sh: explicit flag > env var > interactive menu.

    $deploymentProfile = if ($DotfilesProfile) { $DotfilesProfile } else { $env:CHZ_DEPLOYMENT_PROFILE }
    $deploymentRole    = if ($Role)    { $Role }    else { $env:CHZ_DEPLOYMENT_ROLE }
    $hasGuiChoice      = if ($Gui)     { $Gui }     else { $env:CHZ_HAS_GUI }
    # TEMPORARY (2026-08-18): falls back to dotfiles-rework, not this repo's
    # actual default branch (main) - main doesn't have this session's work
    # yet (env-var-first deployment resolution, Windows package_manager
    # support, the EJSON evault chain, ...), so a bare `chezmoi init --apply
    # <url>` with no --branch silently bootstraps a much older, incompatible
    # tree. Verified live as the real root cause of a Windows machine
    # re-prompting for profile (main's .chezmoi.yaml.tmpl unconditionally
    # calls promptStringOnce, no env-var check at all) and then failing
    # outright (no `package_manager: winget` branch on main) - which, run via
    # `irm | iex`, closed the whole PowerShell window (see Exit-WithError
    # below). Remove/repoint this default once dotfiles-rework is merged into
    # main - see CONCEPT_ROADMAP.md.
    $bootstrapBranch   = if ($Branch)  { $Branch }  elseif ($env:CHZ_BOOTSTRAP_BRANCH) { $env:CHZ_BOOTSTRAP_BRANCH }  else { "dotfiles-rework" }
    $dryRun            = $DryRun.IsPresent   -or ($env:CHZ_BOOTSTRAP_DRY_RUN -eq "1")
    $verboseOut        = $VerbosePreference -ne "SilentlyContinue" -or ($env:CHZ_BOOTSTRAP_VERBOSE -eq "1") -or $DebugAll.IsPresent
    $chezmoiDebug      = $ChezmoiDebug.IsPresent -or $DebugAll.IsPresent
    $forceApply        = $Apply.IsPresent

    # ───── Resolve profile ───────────────────────────────────────────────────

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
                { $_ -in "e", "exit" } { Write-Host "Aborted."; return }
                default { Write-Host "Invalid selection. Please try again."; continue }
            }
            if ($deploymentProfile) { break }
        }
    }
    if ($deploymentProfile -notin "personal", "work") {
        Exit-WithError "Invalid -Profile: '$deploymentProfile' (must be 'personal' or 'work')"
    }
    Write-LogInfo "Selected profile: $deploymentProfile"

    # ───── Resolve role ────────────────────────────────────────────────────────

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
                { $_ -in "e", "exit" } { Write-Host "Aborted."; return }
                default { Write-Host "Invalid selection. Please try again."; continue }
            }
            if ($deploymentRole) { break }
        }
    }
    if ($deploymentRole -notin "workstation", "server") {
        Exit-WithError "Invalid -Role: '$deploymentRole' (must be 'workstation' or 'server')"
    }
    Write-LogInfo "Selected role: $deploymentRole"

    # ───── Resolve GUI presence ──────────────────────────────────────────────

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
                { $_ -in "e", "exit" } { Write-Host "Aborted."; return }
                default { Write-Host "Invalid selection. Please try again."; continue }
            }
            if ($hasGuiChoice) { break }
        }
    }
    if ($hasGuiChoice -notin "yes", "no") {
        Exit-WithError "Invalid -Gui: '$hasGuiChoice' (must be 'yes' or 'no')"
    }
    Write-LogInfo "Has GUI: $hasGuiChoice"

    # ───── Ensure winget ─────────────────────────────────────────────────────

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Exit-WithError "winget was not found. It ships with Windows 11/recent Windows 10 (App Installer) - install it from the Microsoft Store, then re-run."
    }

    # ───── Install chezmoi + git via winget ──────────────────────────────────
    # No CLT/Homebrew/tar-style prerequisite dance needed here - winget already
    # has both as real packages (twpayne.chezmoi, Git.Git), verified live
    # 2026-08-18. Update-SessionPath (defined above, already called once) is
    # called again after each install so this same script session can use the
    # newly-installed tool immediately, without opening a new shell.
    #
    # Git.Git explicitly gets --scope user: its winget manifest defaults to a
    # machine-wide install, which triggers a UAC prompt - confirmed live
    # 2026-08-18. Standing rule for this repo is to prefer user scope on
    # Windows wherever a tool supports it (a target machine may have no admin
    # rights at all, e.g. a locked-down server) - see CONCEPT_ROADMAP.md.
    # chezmoi's package is already scope-less/portable (no prompt observed),
    # so it's left as-is rather than risking an unsupported --scope flag.

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
        winget install -e --id Git.Git --scope user --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
        Update-SessionPath
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Exit-WithError "git install via winget appears to have failed - check the output above and re-run."
        }
        Write-LogInfo "git installed successfully."
    } else {
        Write-LogInfo "git already installed."
    }

    # ───── Install EJSON if missing ──────────────────────────────────────────
    # Shopify publishes real Windows builds (amd64 + arm64) as of ejson v1.5.x,
    # confirmed live via the GitHub releases API 2026-08-18 - no winget package
    # exists, so this mirrors bootstrap.sh's Linux GitHub-tarball path: resolve
    # the latest tag via the API (asset filenames embed the version, so the
    # version-less "latest/download" redirect doesn't work), download, extract
    # with the tar.exe built into Windows since 10 (1803) - no extra tool
    # needed. Installed to $HOME\bin - deliberately NOT ~\.local\bin (the
    # Linux/macOS convention): Windows has no "dotfiles" culture, so a bare
    # `bin` folder reads as native here, and unlike bootstrap.sh's Linux path
    # there's no existing Windows content already anchored under .local to
    # match. Added to the User PATH if not already there.

    if (-not (Get-Command ejson -ErrorAction SilentlyContinue)) {
        Write-LogTask "Installing EJSON..."
        $ejsonArch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) { "arm64" } else { "amd64" }
        $ejsonBinDir = Join-Path $HOME "bin"
        New-Item -ItemType Directory -Path $ejsonBinDir -Force | Out-Null

        $ejsonTag = (Invoke-RestMethod -Uri "https://api.github.com/repos/Shopify/ejson/releases/latest").tag_name
        if (-not $ejsonTag) {
            Exit-WithError "Could not resolve latest EJSON release - install it manually into $ejsonBinDir and re-run."
        }
        $ejsonVersion = $ejsonTag.TrimStart("v")
        $ejsonUrl = "https://github.com/Shopify/ejson/releases/download/$ejsonTag/ejson_${ejsonVersion}_windows_${ejsonArch}.tar.gz"
        $ejsonTarball = Join-Path $env:TEMP "ejson.tar.gz"
        Invoke-WebRequest -Uri $ejsonUrl -OutFile $ejsonTarball
        tar -xzf $ejsonTarball -C $ejsonBinDir ejson.exe
        Remove-Item $ejsonTarball -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path (Join-Path $ejsonBinDir "ejson.exe"))) {
            Exit-WithError "EJSON download/extract failed ($ejsonUrl) - install it manually into $ejsonBinDir and re-run."
        }

        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$ejsonBinDir*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$ejsonBinDir", "User")
        }
        Update-SessionPath
        if (-not (Get-Command ejson -ErrorAction SilentlyContinue)) {
            Exit-WithError "EJSON was installed to $ejsonBinDir but is still not on PATH - check the output above and re-run."
        }
        Write-LogInfo "EJSON installed successfully."
    } else {
        Write-LogInfo "EJSON already installed."
    }

    # ───── Run chezmoi ────────────────────────────────────────────────────────

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

    & chezmoi @chezmoiArgs
    $chezmoiExit = $LASTEXITCODE

    if ($chezmoiExit -ne 0) {
        Exit-WithError "chezmoi init/apply failed - see the output above."
    }

    Write-LogInfo "Bootstrap complete - open a new PowerShell session to pick up the updated `$PROFILE."
}

# See the Exit-WithError comment above: a real `.ps1` file run still gets a
# meaningful process exit code (useful for CI/scripting), but under `irm |
# iex` (no $MyInvocation.MyCommand.Path - the code has no file of its own),
# a fatal error is reported and control returns to the user's shell instead
# of closing their window.
try {
    Invoke-DotfilesBootstrap @args
} catch {
    Write-Host "❌ $($_.Exception.Message)" -ForegroundColor Red
    if ($MyInvocation.MyCommand.Path) {
        exit 1
    }
}
