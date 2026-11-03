#!/usr/bin/env bash
# deploy-agent-rules — drop a shared agent-rules/<name>.md from this dotfiles
# repo into a project checkout as AGENTS.md, without it ever being tracked
# by that project's git history.
#
# Both Claude Code and Codex CLI read AGENTS.md natively from a project's
# working tree, so this is how rules that must NOT end up in a shared/
# upstream repo's commit history (e.g. personal workflow preferences for a
# RedHat driver repo) still reach both agents locally.
#
# Usage:
#   ./deploy-agent-rules.sh <target-repo-path> [rule-set-name]
#
# rule-set-name defaults to "redhat-repos" (agent-rules/redhat-repos.md).
#
# Idempotent: re-run after editing the source file in agent-rules/ to push
# the update out; re-running against the same repo is a no-op for the
# .git/info/exclude entry.
#
# Examples:
#   ./deploy-agent-rules.sh ~/Devel/kvm-guest-drivers-windows
#   ./deploy-agent-rules.sh ~/Devel/some-other-repo redhat-repos

set -euo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ $# -ge 1 ]] || die "usage: $(basename "$0") <target-repo-path> [rule-set-name]"

target_repo=$1
rule_set=${2:-redhat-repos}

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_file="$repo_dir/agent-rules/${rule_set}.md"
[[ -f $source_file ]] || die "no such rule set: $source_file"

target_repo=$(CDPATH= cd -- "$target_repo" && pwd) || die "no such directory: $target_repo"
git_dir=$(git -C "$target_repo" rev-parse --git-dir 2>/dev/null) || die "not a git repo: $target_repo"
# rev-parse --git-dir can be relative to $target_repo (common case, not a worktree).
[[ $git_dir = /* ]] || git_dir="$target_repo/$git_dir"

target_file="$target_repo/AGENTS.md"
cp "$source_file" "$target_file"
printf 'Deployed %s -> %s\n' "$source_file" "$target_file"

exclude_file="$git_dir/info/exclude"
mkdir -p "$(dirname -- "$exclude_file")"
touch "$exclude_file"
if ! grep -qx "AGENTS.md" "$exclude_file" 2>/dev/null; then
    printf '%s\n' "AGENTS.md" >> "$exclude_file"
    printf 'Added AGENTS.md to %s\n' "$exclude_file"
else
    printf 'AGENTS.md already excluded in %s\n' "$exclude_file"
fi
