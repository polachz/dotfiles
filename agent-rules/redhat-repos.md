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

## Branch and PR naming

- The branch actually opened as a PR is `<JIRA-KEY>-<short-kebab-case-
  description>` (e.g. `RHEL-243268-netkvm-validate-num-buffers`) - the Jira
  key plus a short slug, so branches are distinguishable at a glance. Past
  PRs used the bare key alone; new branches should add the slug.
- PR title is `<JIRA-KEY>: <component>: <short description>` (e.g.
  `RHEL-243268: NetKVM: validate num_buffers range in merged buffer
  processing`) - matches the HEAD commit subject. See
  https://github.com/virtio-win/kvm-guest-drivers-windows/pulls/zpolach-rh
  for the established pattern across past PRs (predates the branch slug
  convention above).
- Local (occasionally origin-pushed) checkpoint branches made while
  interactively splitting/rewriting commits - e.g.
  `RHEL-243268-split-before-maxulong` - are scratch safety snapshots for the
  zero-drift diff check in Commit granularity, not PR branches; the
  `-split`/`-split-before-*`/`-orig*` suffixes mark them as such and they're
  never the branch a PR is opened from.

## Filing a main Jira issue (RHEL project)

When asked to file a new bug (e.g. a follow-up finding scoped out of a
current fix), create it with the Atlassian MCP tools against cloudId
`redhat.atlassian.net`, matching the established format - see RHEL-256869
and RHEL-256099 as reference examples.

- Project `RHEL`, issue type `Bug`.
- Summary: `<driver>: fix <short description>` - lowercase driver/component
  prefix (`viostor`, `vioscsi`, `NetKVM`, ...), same convention as commit
  subjects and PR titles.
- Description (markdown, one block per distinct problem location, repeat
  for multiple):
  ```
  ### **File:** <path/to/file>

  **Location:** Lines <X-Y>

  ```c
  <the exact current code snippet, from origin/master>
  ```

  **Issue:** <precise technical explanation of why it's wrong - cite spec
  constraints, bit widths, byte offsets, concurrency model, etc.; this is
  what distinguishes a reviewer-grade report from a vague bug summary>
  ```
  Optionally close with a short paragraph pointing at the right fix
  direction (not a full patch).
- `additional_fields`: `components: [{name: "virtio-win"}]`,
  `Severity: "Moderate"` (reassess upward only for an actual crash/data-
  corruption path, not a theoretical/dead-code one), `AssignedTeam:
  "rhel-virt-windows"`, `Architecture: ["All"]`, `Regression: "No"`.
- `assignee` = the reporter's own accountId (self-filed from code review);
  `priority` = `Normal` unless told otherwise.
- No parent/Epic Link by default - the two reference issues have none.
  Only set one if the user names a specific epic.
- No AI-assistance disclosure line in the description by default - the two
  reference issues don't have one (contrast with older issues like
  RHEL-173360, which predate this convention). Only add one if asked.
- If the new issue is a split-out/related finding from an issue already
  being worked (like this one), link them with `createJiraIssueLink`
  (discovered via `mcp__atlassian__discover` if not already loaded) using
  link type name `Related` (not `Relates` - the exact type name matters
  and `discover`/the tool's error response lists the valid ones).
- Ask the user first when unsure about: severity, parent/epic linkage, AI
  disclosure, or which other issues (if any) to link - these are the
  points earlier issues in this project have varied on.

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
