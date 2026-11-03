# Agent instructions for RedHat/virtio-win driver repos

This file is deployed by `helpers/deploy-agent-rules.sh` into each relevant
repo's working tree as `AGENTS.md`, and excluded from that repo's git tracking
via `.git/info/exclude` (never committed/pushed upstream). Both Claude Code
and Codex CLI read `AGENTS.md` natively.

Edit the copy in this dotfiles repo, not the deployed one - re-run the
deploy script to push changes out to each repo that uses it.

## Commit granularity

Split non-trivial work into small commits, each corresponding to exactly one
semantic change, rather than one large commit bundling everything. Plan the
commit breakdown before or while writing the code, not as an afterthought at
commit time.

- Order commits as: infrastructure/field additions -> guard checks that
  reference the new state (inert/unreachable while the triggering condition
  can never occur yet) -> the function that acts on it, written complete the
  first time -> a final minimal "enable" commit that wires it into the real
  trigger path. Each commit must compile and keep the driver fully
  functional, with no behavioral regression at any point in the sequence -
  guard commits are allowed to be functionally inert, never functionally
  incomplete.
- Never reference a symbol (function, method) by name - in code comments
  *or* commit messages - before the commit that introduces it. Forward-
  looking design notes are fine ("a later commit wires this in"), but don't
  write as if a not-yet-existing symbol is already callable.
- A function that conditionally writes to an out-parameter only on some
  paths cannot rely on the caller having initialized it; make the function
  itself set a defined value (e.g. a sentinel) on every path, not just the
  error path.
- Prefer a named sentinel/constant (e.g. `MAXULONG`) over a cast-from-
  negative idiom like `(ULONG)-1` - same value, no signed/unsigned mixing,
  reads better.
- After splitting/reordering commits, verify zero content drift with
  `git diff <old-tip> <new-tip>` (must be empty) and check every commit for
  `Signed-off-by`.

## Git hygiene

- Every commit needs `Signed-off-by: <name> <email>` - check every commit in
  a PR, not just HEAD; GitHub's web-UI merge commits silently drop it.
  Fix via rebase, not amend, if found missing partway through a branch.
- Never add `Co-Authored-By: Claude` or similar AI attribution to commits in
  these repos.
- A redhat.com `Signed-off-by` needs the Jira key as a prefix in the PR
  title or commit subject, or the CI signoff check fails.
- Run clang-format before every commit (there is a local
  `.git/hooks/pre-commit` for this in the driver repo - reinstall it if the
  clone is recreated).

## Code comments

Keep code comments short (1-3 lines), explaining only the non-obvious why -
not what the code does.
