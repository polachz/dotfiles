<#
deploy-agent-rules — drop a shared agent-rules/<name>.md from this dotfiles
repo into a project checkout as AGENTS.md, without it ever being tracked by
that project's git history.

PowerShell sibling of deploy-agent-rules.sh — same behavior, for a plain
Windows shell where a .sh script can't be run directly without explicitly
invoking bash. See docs/DAILY_WORKFLOW.md S14.

Both Claude Code and Codex CLI read AGENTS.md natively from a project's
working tree, so this is how rules that must NOT end up in a shared/
upstream repo's commit history (e.g. personal workflow preferences for a
RedHat driver repo) still reach both agents locally.

Idempotent: re-run after editing the source file in agent-rules/ to push
the update out; re-running against the same repo is a no-op for the
.git/info/exclude entry.

.PARAMETER TargetRepoPath
Path to the project checkout to deploy into.

.PARAMETER RuleSet
Name of the agent-rules/<name>.md source file, without extension.
Defaults to "redhat-repos".

.EXAMPLE
.\deploy-agent-rules.ps1 ~\Devel\kvm-guest-drivers-windows

.EXAMPLE
.\deploy-agent-rules.ps1 ~\Devel\some-other-repo redhat-repos
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetRepoPath,

    [Parameter(Position = 1)]
    [string]$RuleSet = "redhat-repos"
)

$ErrorActionPreference = "Stop"

$repoDir = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $repoDir "agent-rules\$RuleSet.md"
if (-not (Test-Path $sourceFile -PathType Leaf)) {
    throw "No such rule set: $sourceFile"
}

try {
    $targetRepo = (Resolve-Path $TargetRepoPath -ErrorAction Stop).Path
}
catch {
    throw "No such directory: $TargetRepoPath"
}

$gitDirRaw = & git -C $targetRepo rev-parse --git-dir 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Not a git repo: $targetRepo"
}
# rev-parse --git-dir can be relative to $targetRepo (common case, not a worktree).
if ([System.IO.Path]::IsPathRooted($gitDirRaw)) {
    $gitDir = $gitDirRaw
}
else {
    $gitDir = Join-Path $targetRepo $gitDirRaw
}

$targetFile = Join-Path $targetRepo "AGENTS.md"
Copy-Item -Path $sourceFile -Destination $targetFile -Force
Write-Host "Deployed $sourceFile -> $targetFile" -ForegroundColor Blue

$excludeFile = Join-Path $gitDir "info\exclude"
New-Item -ItemType Directory -Path (Split-Path -Parent $excludeFile) -Force | Out-Null
if (-not (Test-Path $excludeFile)) {
    New-Item -ItemType File -Path $excludeFile | Out-Null
}

$existing = Get-Content -Path $excludeFile -ErrorAction SilentlyContinue
if ($existing -notcontains "AGENTS.md") {
    Add-Content -Path $excludeFile -Value "AGENTS.md"
    Write-Host "Added AGENTS.md to $excludeFile" -ForegroundColor Blue
}
else {
    Write-Host "AGENTS.md already excluded in $excludeFile" -ForegroundColor Blue
}
