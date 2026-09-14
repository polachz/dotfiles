# Adding an SSH host

How-to for adding (or editing) an entry in `~/.ssh/config` through this repo.
For the *why* behind this design (fragment directory instead of a single
managed file, precedence rules, the Windows `Include` workaround), see
[`ARCHITECTURE.md` § SSH configuration](./ARCHITECTURE.md#6-ssh-configuration).

## The short version

`~/.ssh/config` itself is never owned by chezmoi (see
[`ARCHITECTURE.md` § Never-own-rc-files](./ARCHITECTURE.md#4-never-own-rc-files)) —
it just includes everything under `~/.ssh/conf.d/*.conf`. To add a host, you
create a small fragment file directly in `~/.ssh/conf.d/`, then hand it to
chezmoi with `chezmoi add`.

## 1. Pick a filename

```
~/.ssh/conf.d/NN-scope-description.conf
```

| Part | Meaning |
|---|---|
| `NN-` | Numeric prefix controlling order. SSH uses **first-match-wins**, so lower number = higher precedence. Keep host-specific fragments low (`50-`), broad `Host *` catch-alls high (`90-`, see `90-common.conf`). |
| `-work-` / `-personal-` | Include this substring in the name to scope the fragment to one profile only — `.chezmoiignore.tmpl` masks out any `*-work-*.conf` / `*-personal-*.conf` fragment on the other profile's machines. Omit it (like `90-common.conf`) for a fragment that should exist on both profiles. |
| description | Free text, whatever's memorable. |

Examples already in the repo: `private_50-work-labvms.conf`,
`private_50-work-redhat.conf`, `private_90-common.conf`.

## 2. Write the fragment

Plain OpenSSH config syntax, nothing chezmoi-specific:

```sshconfig
Host newvm
  HostName newvm.example.com
  User myuser
  IdentityFile ~/.ssh/id_ed25519
```

Create it directly at the real path so you can test it immediately:

```bash
$EDITOR ~/.ssh/conf.d/60-work-newvm.conf
ssh -G newvm   # sanity-check the resolved config before adding it
```

## 3. Add it to chezmoi

**Plain (not secret — hostnames/users you don't mind in a public repo):**

```bash
chezmoi add ~/.ssh/conf.d/60-work-newvm.conf
```

**Encrypted (contains something you don't want readable in git — internal
hostname, IP, jump-host details, etc.):**

```bash
chezmoi add --encrypt ~/.ssh/conf.d/60-work-newvm.conf
```

Either way this writes straight into the source repo
(`~/.local/share/chezmoi/private_dot_ssh/conf.d/...` — the source dir *is*
the repo you commit from, see
[`DAILY_WORKFLOW.md` § The repo model](./DAILY_WORKFLOW.md#the-repo-model)).
`--encrypt` produces a filename with both the `encrypted_` and `private_`
attributes, e.g. `encrypted_private_60-work-newvm.conf` — the `.conf`
extension is preserved either way, so both the bash `Include
~/.ssh/conf.d/*.conf` line and the Windows fragment-concatenation script
pick it up automatically. No script changes needed for either case.

## 4. Commit and push

```bash
chd
git add private_dot_ssh/conf.d/*60-work-newvm.conf
git commit -m "ssh: add newvm host"
git push
```

## 5. Editing a fragment later

For a plain fragment, just edit the real file in `~/.ssh/conf.d/` (or the
source file via `chd`) — either is fine, they're the same content.

For an **encrypted** fragment, don't hand-edit the source file (it's
ciphertext). Use:

```bash
chezmoi edit ~/.ssh/conf.d/60-work-newvm.conf
```

This decrypts to a temp file, opens `$EDITOR`, and re-encrypts on save.

## Verify

```bash
chezmoi apply --dry-run -v      # no surprises
ssh -G newvm                    # confirm the effective resolved config
```

## Removing a host

See [`DAILY_WORKFLOW.md` § S4. Remove a dotfile from management](./DAILY_WORKFLOW.md#s4-remove-a-dotfile-from-management) —
same mechanics apply to a single `conf.d` fragment as to any other managed file.
