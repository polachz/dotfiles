# Daily workflow — chezmoi + Age + EJSON

Operator-facing guide for day-to-day work with this dotfiles repo.
Covers common scenarios, edge cases, security risks, and recovery
patterns.

For first-time setup or key chain generation, see
[`ENCRYPTION_SETUP.md`](./ENCRYPTION_SETUP.md). For the README overview,
see [`README.md`](./README.md).

## The two-repo mental model

This repo lives on disk in **two places** simultaneously, and confusing
them is the source of most workflow bugs:

| Path | Role | Edit here? |
|------|------|-----------|
| `~/devel/homelab/dotfiles/` | **Dev repo** — where you edit, commit, push | ✅ YES |
| `~/.local/share/chezmoi/` | **Managed source** — chezmoi's working copy, pulled from GitHub | ❌ NO |
| `~/` (HOME) | **Deploy target** — rendered files (`~/.gitconfig`, `~/.bashrc.d/...`) | ❌ NO |

Golden rule: **edit in dev repo, push to GitHub, `chezmoi update` on each
machine.** Editing the managed source or the rendered HOME files
short-circuits the flow and leads to silent drift.

---

## Daily workflow scenarios

### S1. Change a managed file (e.g. `dot_bashrc.d/shared/50-aliases-misc.sh`)

```bash
cd ~/devel/homelab/dotfiles
$EDITOR dot_bashrc.d/shared/50-aliases-misc.sh
git add -p && git commit -m "aliases: add 'gst' shortcut"
git push

# On each machine (including this one):
chezmoi update -v
```

**Common mistakes:**
- Editing `~/.bashrc.d/shared/50-aliases-misc.sh` directly in HOME →
  next `chezmoi apply` detects the drift and (interactively) prompts;
  in non-interactive runs it silently overwrites.
- Editing in `~/.local/share/chezmoi/` → next `chezmoi update` either
  loses the change (autostash drop) or fails with merge conflict.

**Verify:**
```bash
chezmoi diff                # must be empty after update
chezmoi verify && echo OK
```

### S2. Change a value in evault (mail, git user, etc.)

The values in `secrets/<profile>/evault` are read by chezmoi templates
at apply time (via `ejsonValue`). Change the value → push → other
machines pick it up automatically on `chezmoi update`.

```bash
# Decrypt → edit → re-encrypt (with the helper)
edit-evault personal --repo ~/devel/homelab/dotfiles

cd ~/devel/homelab/dotfiles
git diff secrets/personal/evault    # encrypted blob diff (nonces change)
git add secrets/personal/evault
git commit -m "evault: update personal git email"
git push

# Other machines:
chezmoi update -v
```

**Templates do not need to change** — they call `ejsonValue` dynamically.
Only the data layer (evault) changes.

**Common mistakes:**
- Manual `ejson decrypt > /tmp/evault.json`, edit, forget to shred
  `/tmp/evault.json` → plaintext on disk.
- Re-encrypt with wrong `_public_key` → unreachable blob (recoverable
  only if you still have the old EJSON key in `~/.config/chezmoi/keys/`).
- Reference a field in a template that doesn't exist in evault →
  template render error (see [E7](#e7-template-render-error-missing-evault-field)).

**Verify:**
```bash
chezmoi execute-template '{{ (include .ejson_vault | fromJson).git.email }}'
# → prints the new email
chezmoi diff                # shows the rendered template diff
```

### S3. Add a new dotfile to management

```bash
# Existing file in HOME — let chezmoi import it
chezmoi add ~/.gitconfig                # plain file
chezmoi add --template ~/.gitconfig     # as template
chezmoi add --encrypt ~/.ssh/id_ed25519 # encrypted (Age)
```

`chezmoi add` writes to `~/.local/share/chezmoi/` (the managed source).
You must then **propagate to the dev repo** so it gets committed:

```bash
cp ~/.local/share/chezmoi/dot_gitconfig.tmpl ~/devel/homelab/dotfiles/
cd ~/devel/homelab/dotfiles
git add dot_gitconfig.tmpl
git commit -m "gitconfig: add template"
git push
```

**Naming conventions** (the source filename controls the target):

| Source filename | HOME target | Notes |
|-----------------|-------------|-------|
| `dot_foo` | `~/.foo` | Plain file |
| `dot_foo.tmpl` | `~/.foo` (rendered) | Go template |
| `private_dot_foo` | `~/.foo` mode 600 | Owner-only read |
| `executable_dot_foo` | `~/.foo` mode +x | |
| `encrypted_private_dot_ssh/encrypted_id_ed25519` | `~/.ssh/id_ed25519` mode 600 | Age-encrypted in repo |
| `symlink_dot_foo` | `~/.foo` → symlink target | |

**Common mistakes:**
- Adding a file directly into the dev repo without the `dot_` prefix —
  chezmoi will ignore it (won't render to HOME).
- Adding a secret without `--encrypt`.
- Forgetting to copy from managed source into dev repo → next
  `chezmoi update` resets the source dir and your addition is lost.

**Verify:**
```bash
chezmoi managed | grep gitconfig    # appears in the managed list
chezmoi apply --dry-run -v          # no surprises
```

### S4. Remove a dotfile from management

Three modes, very different blast radius — pick deliberately:

| Command | Effect on source | Effect on HOME |
|---------|------------------|----------------|
| `chezmoi forget ~/.foo` | Deleted | **Kept** (file orphaned) |
| `chezmoi destroy ~/.foo` | Deleted | **Deleted** |
| Add to `.chezmoiignore` | Kept (ignored) | **Kept** (no longer managed) |

Recommended for "stop managing, also wipe from HOME":

```bash
chezmoi forget ~/.foo                       # remove from source
echo '.foo' >> ~/devel/homelab/dotfiles/.chezmoiremove
# .chezmoiremove patterns get rm'd from HOME on next apply

cd ~/devel/homelab/dotfiles
git add -A
git commit -m "stop managing .foo"
git push
# Other machines: chezmoi update
```

**Common mistakes:**
- Confusing `forget` with `destroy`. Reflex check: "do I lose data?"
  `destroy` = yes.
- Removing only from source without `.chezmoiremove` → orphan HOME file
  on every machine.

### S5. Switch profile (personal ↔ work)

`promptStringOnce` writes `data.deployment.profile` into
`~/.config/chezmoi/chezmoi.yaml` once. Switching requires resetting that
+ purging the wrong profile's keys.

```bash
# Wipe profile-bound state
rm ~/.config/chezmoi/chezmoi.yaml
rm -f ~/.config/chezmoi/age_*.key
rm -rf ~/.config/chezmoi/keys/*

# Re-prompt for profile + re-decrypt keys
chezmoi init      # prompts: Profile (personal/work)?
chezmoi apply -v
```

**Caveat: orphans from the previous profile stay in HOME.**
`.chezmoiignore` does not delete; `~/.bashrc.d/personal/` survives a
switch to `work`. Clean up:

```bash
rm -rf ~/.bashrc.d/personal     # if switched to work, vice versa
```

Or codify in `.chezmoiremove.tmpl`:

```gotmpl
{{ if eq .deployment.profile "work" }}
.bashrc.d/personal
{{ end }}
{{ if eq .deployment.profile "personal" }}
.bashrc.d/work
{{ end }}
```

### S6. Update from upstream

**Recommended (preview before applying):**

```bash
chezmoi git -- pull --autostash --rebase     # pull only
chezmoi diff                                  # preview
chezmoi apply -v                              # apply if happy
```

**Quick (one-shot):** `chezmoi update -v` (= pull + apply).

**Common mistakes:**
- `cd ~/.local/share/chezmoi && git pull` without `chezmoi apply` →
  source and HOME drift apart silently.
- Pulling a commit that changes a `run_onchange_*.tmpl` re-runs that
  script. For `run_onchange_install-packages.sh.tmpl` this means
  package install runs again — idempotence is load-bearing.

**Verify:** `chezmoi verify && echo OK`

### S7. Sync changes between machines

Workflow with multiple workstations:

```
Machine A:                        Machine B:
  edit in dev repo
  git commit && git push
                                    chezmoi update -v
                                    # → pulls + applies
```

If both A and B edit the same source file before sync, `chezmoi update`
on the second machine fails with a git rebase conflict. Resolve:

```bash
cd ~/.local/share/chezmoi
git status                  # see conflicting files
$EDITOR <conflicted-file>
git add <file>
git rebase --continue
chezmoi apply -v
```

Or bail out: `git rebase --abort`.

**Prevention:** before editing on any machine, `chezmoi update` first.
Treat one machine as "edit primary" by convention.

### S8. Bootstrap a new machine

See [`README.md`](./README.md#bootstrap-options) for full details. Short
version:

```bash
curl -fsLS https://get.chezmoi.io | sh
chezmoi init https://github.com/<you>/dotfiles.git
# → prompts for profile (personal/work)
# → run_once script prompts for Age passphrase, decrypts keys
chezmoi diff           # review what will be written
chezmoi apply -v
```

**Don't** `chezmoi init --apply <repo>` (one-step) — `--apply` skips the
diff review, so you can't see what's about to land in HOME.

### S9. Test a change before commit

| Command | What it does |
|---------|--------------|
| `chezmoi diff` | Text diff of HOME vs. rendered source |
| `chezmoi apply --dry-run -v` | Log "would do X" without modifying HOME |
| `chezmoi execute-template < some.tmpl` | Render one template, print to stdout |
| `chezmoi cat <target>` | Print final content of a managed target |
| `chezmoi data` | Dump entire template context (sanity-check evault values) |
| `chezmoi verify` | Exit 0 if HOME matches source, 1 otherwise |

**Dry-run caveat:** scripts (`run_once_*`, `run_onchange_*`) do **not**
execute in `--dry-run`, but template rendering does — so template
errors surface, but side effects of scripts don't.

**Important — chezmoi reads from managed source, not dev repo.** So
`chezmoi diff` in the dev repo shows nothing useful until you `git push`
+ `chezmoi update`. Three ways to test locally:

```bash
# Render one template, no writes
chezmoi execute-template < dot_gitconfig.tmpl

# Diff against the dev repo instead of managed source
chezmoi -S ~/devel/homelab/dotfiles diff

# Apply from dev repo (use sparingly — see warning below)
chezmoi -S ~/devel/homelab/dotfiles apply
```

**Warning on `-S <dev-repo>` apply:** after applying from dev repo, a
regular `chezmoi update` reverts you to whatever is in the public repo.
Fine for quick iteration, dangerous for permanent state.

---

## Edge cases

### E1. Edit managed file directly in HOME

- **Symptom:** `chezmoi diff` shows your HOME version differs from
  source. Next `chezmoi apply` prompts to overwrite (interactive) or
  silently overwrites (non-interactive).
- **Root cause:** Chezmoi tracks the last-written hash in
  `chezmoistate.boltdb`. Your manual edit creates drift.
- **Fix (pick one):**
  ```bash
  chezmoi re-add ~/.foo            # capture HOME version into source
  chezmoi apply --force ~/.foo     # discard HOME, restore from source
  chezmoi merge ~/.foo             # three-way merge in your $EDITOR
  ```
- **Prevention:** use `chezmoi edit ~/.foo` (opens the source file, not
  HOME); run `chezmoi verify` periodically (systemd timer).

### E2. Edit in `~/.local/share/chezmoi/` instead of dev repo

- **Symptom:** Changes live in managed source but dev repo doesn't know.
  Next `chezmoi update` either drops the change (autostash pop conflict)
  or overwrites it on rebase.
- **Fix:**
  ```bash
  cd ~/.local/share/chezmoi
  git status                          # what's there
  # If commited: git push, then git pull in dev repo
  # If uncommitted: cp to dev repo, commit there, reset managed:
  cp <file> ~/devel/homelab/dotfiles/<file>
  cd ~/.local/share/chezmoi
  git reset --hard origin/main
  ```
- **Prevention:** discipline — edit only in dev repo. Optionally add a
  pre-commit hook in `~/.local/share/chezmoi/.git/hooks/pre-commit`
  that exits 1 ("commit only from dev repo").

### E3. Concurrent edits on multiple machines

- **Symptom:** `chezmoi update` on machine B fails with rebase conflict.
- **Fix:** resolve as ordinary git conflict (see S7).
- **Prevention:** `chezmoi update` before editing.

### E4. State boltdb (`~/.config/chezmoi/chezmoistate.boltdb`)

- **What it stores:**
  - `scriptState` — SHA256 of successfully-run `run_once_*` scripts
  - `entryState` — hashes of `run_onchange_*` and last-written HOME files
- **Symptom: lock timeout** — another chezmoi process is running.
  Fix: `pgrep -af chezmoi`, kill stale.
- **Symptom: "inconsistent state"** — usually two source files mapping
  to the same target. Fix the source conflict.
- **Manual inspection:**
  ```bash
  chezmoi state dump                                    # JSON dump
  chezmoi state get-bucket --bucket=scriptState         # see hashes
  chezmoi state delete-bucket --bucket=scriptState      # force all run_once
  chezmoi state delete-bucket --bucket=entryState       # force all run_onchange
  chezmoi state reset                                    # nuke everything
  ```

### E5. `run_once_*` scripts re-run unexpectedly

- **Re-runs when:** rendered (post-template) script content has a
  different SHA256 than what's in `scriptState`.
- **Does NOT re-run:** on rename without content change.
- **Caveat for this setup:** `run_once_before_init_age.sh.tmpl` embeds
  values from `.chezmoi.yaml.tmpl` (`age_recipient`, `ekey_id`). Rotating
  keys changes the recipients → changes the rendered script hash →
  script re-runs on every machine. This is desired, but worth knowing.

### E6. `run_onchange_*` scripts re-run

- Same hash-based trigger as `run_once`, tracked in `entryState`.
- **Common gotcha:** adding a comment or whitespace to
  `run_onchange_install-packages.sh.tmpl` re-runs the whole package
  install. Idiom for explicit triggers:
  ```bash
  # Force re-run: {{ .someTrigger | sha256sum }}
  ```

### E7. Template render error — missing evault field

- **Symptom:** `chezmoi apply` fails with
  `template: ...: nil pointer evaluating interface {}.field_name`.
- **Root cause:** template calls `(include .ejson_vault | fromJson).fieldX`
  but `fieldX` doesn't exist.
- **Fix:**
  - Add the field: `edit-evault <profile> --repo ~/devel/homelab/dotfiles`
  - Or make template defensive: `{{ with .field }}{{ . }}{{ else }}default{{ end }}`
- **Prevention:** `chezmoi execute-template` in a pre-commit hook.

### E8. Stale rendered file after deleting template

- **Symptom:** removed `dot_foo.tmpl` from source, but `~/.foo` still
  exists.
- **Root cause:** chezmoi has no history — it doesn't know `~/.foo` was
  ever managed.
- **Fix:** `rm ~/.foo` manually, or add `.foo` to `.chezmoiremove`.
- **Discipline:** delete template + `.chezmoiremove` entry in the same
  commit.

### E9. `.chezmoiignore` does not delete

- **Symptom:** added a file to `.chezmoiignore`, but `~/.something`
  still exists in HOME.
- **Root cause:** `.chezmoiignore` only prevents future application —
  it never removes (deliberate safety property).
- **Fix:** add a matching `.chezmoiremove` entry, or `rm ~/.something`.
- **Profile-switch caveat:** `.chezmoiignore.tmpl` masks the other
  profile's files, but old files from the previous profile stay in HOME
  on switch. See S5.

### E10. Permissions drift

- **Symptom:** `chmod 755 ~/.foo`, but `chezmoi apply` resets to 644.
- **Root cause:** the source attribute (`private_`, `executable_`,
  `readonly_`) is authoritative; manual chmod is drift.
- **Fix:**
  - Permanent change: rename source `dot_foo` → `executable_dot_foo`,
    or `chezmoi chattr +executable dot_foo`.
  - One-off: `chezmoi forget ~/.foo` and manage manually.

### E11. Symlink vs. file conversion

- **Symptom:** changed `dot_foo` (file) to `symlink_dot_foo` (symlink),
  but apply doesn't replace.
- **Fix:** `rm ~/.foo` first, then apply.
- **Vim caveat:** vim writes through symlinks by default. If a symlink
  points back into source, an in-HOME edit modifies the source — same
  pattern as E1 but worse.

---

## Security risks (workflow-specific)

For overall encryption operational security, see
[`ENCRYPTION_SETUP.md` → Operational security after deploy](./ENCRYPTION_SETUP.md#operational-security-after-deploy).
This section covers risks specific to the commit/push flow.

### B1. Accidentally committing plaintext evault

- **Scenario:** `ejson decrypt secrets/personal/evault > secrets/personal/evault`
  (overwrote the encrypted blob with plaintext) → `git add` → `git push`.
  Repo is public.
- **Impact:** All secret values are in git history forever. Removing
  from history (`git filter-repo`) does not undo public exposure.
- **Mitigation:**
  - Pre-commit hook that checks every `secrets/*/evault` is still
    EJSON-encrypted (every non-`_`-prefixed string starts with `EJ[`):
    ```bash
    # .git/hooks/pre-commit (or pre-commit framework)
    for f in secrets/*/evault; do
      python3 -c "
    import json, sys
    d = json.load(open('$f'))
    bad = [k for k,v in d.items()
           if not k.startswith('_') and isinstance(v,str) and not v.startswith('EJ[')]
    if bad:
        print(f'PLAINTEXT in $f: {bad}', file=sys.stderr); sys.exit(1)
    "
    done
    ```
  - Never `git add -A` in this repo — use `git add <specific-path>` or
    `git add -p`.
- **Recovery if it happened:** assume all values leaked. Rotate every
  secret in evault (passwords, tokens, signing keys). Re-encrypt evault
  fresh. Force-push history rewrite is mostly cosmetic — copies are
  already cached.

### B2. Accidentally committing plaintext Age or EJSON keys

- **Scenario:** copying `~/.config/chezmoi/age_personal.key` into the
  repo, or accidentally adding `~/.config/chezmoi/keys/<id>`.
- **Impact:** with the plaintext key, anyone can decrypt **all** evault
  versions in git history (current and past). Assume full historical
  compromise.
- **Mitigation:**
  - `.gitignore` patterns:
    ```
    *.key
    keys/
    /age_*.txt
    *.plain
    *.decrypted
    ```
  - Pre-commit hook checking for Age private-key header and 64-hex
    EJSON private:
    ```bash
    if git diff --cached | grep -qE '^AGE-SECRET-KEY-1|^[0-9a-f]{64}$'; then
        echo "Refusing: plaintext key material in staged changes" >&2
        exit 1
    fi
    ```
- **Recovery:** full re-key. See
  [`ENCRYPTION_SETUP.md` → Scenario D](./ENCRYPTION_SETUP.md#scenario-d--full-re-key-age--ejson-both).
  Rotate every secret in evault too — assume they leaked.

### B3. Pushing dev repo without review

- **Scenario:** `git add -A && git commit -m 'wip' && git push` —
  picks up an unintended file (e.g. a `/tmp/evault.json` you copied for
  inspection).
- **Mitigation:**
  - Never `git add -A`. Always `git add -p` or specific paths.
  - Pre-push: `git diff origin/main --stat` for a sanity glance.
  - `.gitignore` for common transient paths: `/tmp/`, `*.json` outside
    `secrets/`, etc.

### B4. Recommended pre-commit stack

For automated enforcement of B1–B3, use [pre-commit](https://pre-commit.com/)
with [gitleaks](https://github.com/gitleaks/gitleaks):

```yaml
# .pre-commit-config.yaml at the repo root
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: local
    hooks:
      - id: evault-shape
        name: evault must stay EJSON-encrypted
        entry: bash -c 'for f in secrets/*/evault; do python3 -c "import json,sys;d=json.load(open(\"$f\"));bad=[k for k,v in d.items() if not k.startswith(\"_\") and isinstance(v,str) and not v.startswith(\"EJ[\")];sys.exit(1 if bad else 0)" || { echo \"plaintext in $f\"; exit 1; }; done'
        language: system
        pass_filenames: false

      - id: chezmoi-template-render
        name: chezmoi dry-run apply (template render check)
        entry: chezmoi -S . apply --dry-run
        language: system
        pass_filenames: false
```

Activate: `pre-commit install` (once per clone).

### B5. GitHub secret scanning coverage

GitHub's secret scanning does **not** have signatures for EJSON `EJ[1:...]`
blobs or Age ciphertext. Your encrypted blobs won't trigger push
protection (good — no false positives), but GitHub also won't catch you
if a plaintext leak doesn't match a known pattern (e.g. plaintext email,
custom token format). Don't rely on GitHub-side detection alone.

---

## Recovery patterns

### R1. Broke `~/.gitconfig` (or any managed file) by manual edit

```bash
chezmoi diff ~/.gitconfig            # see the drift
chezmoi apply --force ~/.gitconfig   # restore from source
```

### R2. `chezmoi apply` failed mid-way

```bash
chezmoi state dump | jq '.scriptState'  # which scripts completed
chezmoi verify                           # which targets are still out-of-state
# Fix the root cause (template error, missing field, etc.)
chezmoi apply -v --keep-going            # continue past errors to see all
```

If a script ran but state was not updated (rare): manually
`chezmoi state delete --bucket=scriptState --key=<hash>` and re-apply.

### R3. Dev repo has commits not yet on GitHub

```bash
cd ~/devel/homelab/dotfiles
git status                # "ahead of origin/main by N"
git log origin/main..HEAD # what's local
git push
# Then on machines: chezmoi update
```

**Opposite (public ahead, dev behind):**

```bash
cd ~/devel/homelab/dotfiles
git stash                 # if you have local changes
git pull --rebase
git stash pop
```

### R4. Deleted a managed file from HOME

```bash
chezmoi verify            # shows missing
chezmoi apply -v          # re-renders and re-creates
```

If the file is encrypted and the key is missing: see
[`ENCRYPTION_SETUP.md` → Recovery scenarios](./ENCRYPTION_SETUP.md#recovery-scenarios).

### R5. Deleted a template but rendered file remains in HOME

```bash
chezmoi managed | grep -v <target>   # confirm: gone from source
ls -la ~/<target>                    # confirm: still in HOME
rm ~/<target>                        # manual cleanup
# Or codify in .chezmoiremove
```

### R6. State db corrupted or locked

```bash
# Lock:
pgrep -af chezmoi                                # find stale process
kill <pid>

# Corruption:
cp ~/.config/chezmoi/chezmoistate.boltdb{,.bak}
chezmoi state reset                              # nukes all script state
# All run_once_* scripts will run again on next apply — idempotence is required
```

Selective wipe:

```bash
chezmoi state delete-bucket --bucket=scriptState     # re-run all run_once
chezmoi state delete-bucket --bucket=entryState      # re-render all entries
```

### R7. Key rotation / compromise

See [`ENCRYPTION_SETUP.md` → Rotating keys](./ENCRYPTION_SETUP.md#rotating-keys).

---

## Long-term maintenance

### Periodic health check

Run weekly (or wire into a systemd timer):

```bash
chezmoi doctor                                 # toolchain (age, git, ejson)
chezmoi verify; echo "verify=$?"               # HOME drift
chezmoi git -- status --porcelain              # managed clone clean?
git -C ~/devel/homelab/dotfiles status --porcelain   # dev clone clean?
chezmoi data | jq .deployment.profile          # right profile?
chezmoi managed | wc -l                        # sanity baseline (should be stable)
```

Exit codes: `verify` returns 0 (clean) or 1 (drift). Wire into a
notification if you want passive monitoring.

### Repo housekeeping

- Managed source dir (`~/.local/share/chezmoi/`) is a normal git repo —
  `.git/objects` grow with history. Once a year: `git -C
  ~/.local/share/chezmoi gc --aggressive --prune=now`.
- State boltdb stays <1 MB in practice. If it ever bloats: `chezmoi
  state reset` (loses all script-run-state; idempotent scripts re-run).
- External cache (if you use `.chezmoiexternal`): lives in
  `~/.cache/chezmoi/`. Manually purge if needed.

---

## Quick reference

```bash
# Daily core loop
chezmoi update -v                  # pull + apply
chezmoi diff                       # what would apply change
chezmoi apply -v                   # apply pending source changes
chezmoi verify                     # any HOME drift?

# Editing
edit-evault <profile> --repo ~/devel/homelab/dotfiles
$EDITOR ~/devel/homelab/dotfiles/<source-file>
git -C ~/devel/homelab/dotfiles {add,commit,push}

# Debugging
chezmoi doctor                     # toolchain health
chezmoi data | jq                  # template context
chezmoi cat ~/.<target>            # rendered content
chezmoi execute-template < <tmpl>  # one-template render
chezmoi state dump | jq            # internal state

# Profile + key flows
chezmoi init                       # re-prompt profile
helpers/setup-encryption.sh        # generate / rotate keys
~/verify-encryption.sh <profile>   # standalone chain check
```

---

## Sources

- [chezmoi — Daily operations](https://www.chezmoi.io/user-guide/daily-operations/)
- [chezmoi — Command overview](https://www.chezmoi.io/user-guide/command-overview/)
- [chezmoi — Use scripts to perform actions](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/)
- [chezmoi — Manage different types of file](https://www.chezmoi.io/user-guide/manage-different-types-of-file/)
- [chezmoi — Encryption](https://www.chezmoi.io/user-guide/encryption/)
- [chezmoi — Troubleshooting FAQ](https://www.chezmoi.io/user-guide/frequently-asked-questions/troubleshooting/)
- [chezmoi — Usage FAQ](https://www.chezmoi.io/user-guide/frequently-asked-questions/usage/)
- [chezmoi — `.chezmoiignore`](https://www.chezmoi.io/reference/special-files/chezmoiignore/)
- [chezmoi — `forget` / `destroy` / `verify` / `state`](https://www.chezmoi.io/reference/commands/)
- [pre-commit framework](https://pre-commit.com/)
- [gitleaks](https://github.com/gitleaks/gitleaks)
