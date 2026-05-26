# dotfiles

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/). Two profiles
(`personal` and `work`) with **cryptographic separation** — a personal machine
physically cannot decrypt work secrets, and vice versa.

`bootstrap.sh` is a self-contained installer — needs only `curl` or `wget`,
downloads chezmoi automatically, and walks you through profile selection.

---

## Supported platforms

| Platform | Support |
|---|---|
| Fedora / RHEL (dnf) | Primary |
| Debian / Ubuntu (apt) | Partial |
| WSL2 (Windows Subsystem for Linux) | Supported (includes Windows SSH agent relay) |

---

## Prerequisites

- `curl` or `wget`
- Internet access (chezmoi binary is downloaded during bootstrap)
- **Age passphrase** for the chosen profile (one passphrase for personal,
  one for work). Stored in a password manager (1Password, Bitwarden,
  KeePassXC, …) — bootstrap will prompt you on the TTY when decrypting the
  Age key, and you paste it from the password manager. The passphrase
  never touches disk.
- **`age` binary** — required to decrypt `age_key_<profile>.age`. On Linux
  it is installed automatically by the bootstrap script via dnf/apt. On
  other platforms install it manually beforehand
  ([github.com/FiloSottile/age](https://github.com/FiloSottile/age/releases/latest)).
- **EJSON binary** — installed automatically by bootstrap.sh during the first
  run (downloaded from
  [github.com/Shopify/ejson/releases](https://github.com/Shopify/ejson/releases/latest)).
- SSH key configured in GitHub — required only if you want to push changes
  back after installation (bootstrap switches the remote from HTTPS to SSH
  automatically).

---

## Installation

```bash
# Using wget
sh -c "$(wget -qO- https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"

# Using curl
sh -c "$(curl -fsSL https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"
```

The installer prompts for the profile (`personal` or `work`). To skip the
menu, pass the profile directly:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)" -- --profile personal
```

Or via environment variable:

```bash
CHZ_DEPLOYMENT_PROFILE=personal \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"
```

---

## Profiles

| Profile | Use |
|---|---|
| `personal` | Private machines — personal email/git/ssh identity, personal `~/.ssh/config` |
| `work` | Work machines — work email/git/ssh identity, work-specific aliases |

Each profile has:
- Its own bashrc subdirectory (`~/.bashrc.d/personal/` or `~/.bashrc.d/work/`)
- Its own encrypted secrets vault (`secrets/personal/evault` or `secrets/work/evault`)
- Its own Age key pair (`age_key_personal.age` / `age_key_work.age`)
- Its own EJSON key pair (`ejson_key_personal.age` / `ejson_key_work.age`)

`.chezmoiignore.tmpl` ensures only the active profile's files reach disk on a
given machine. The encrypted blobs for the OTHER profile come along with the
repo clone, but they can't be decrypted without the matching Age key.

---

## Bootstrap options

### CLI flags

| Flag | Description |
|---|---|
| `-p`, `--profile <personal\|work>` | Pre-select profile (skip menu) |
| `-d`, `--dry-run` | Show what would change without applying |
| `-a`, `--apply` | Force apply (overrides dry-run default on re-runs) |
| `-v`, `--verbose` | Verbose output |
| `--debug` | Enable debug logging in all dotfile scripts (`set -x`) |
| `--chezmoi-debug` | Pass `--debug` to chezmoi itself |
| `--debug-all` | Both `--debug` and `--chezmoi-debug` |
| `-r`, `--reinit` | Clear chezmoi state and re-apply from scratch |

### Environment variables

| Variable | Description |
|---|---|
| `CHZ_DEPLOYMENT_PROFILE` | Profile selector (`personal` or `work`) — same as `--profile` |
| `CHZ_BOOTSTRAP_DRY_RUN` | Set to `1` to run in dry-run mode |
| `CHZ_BOOTSTRAP_VERBOSE` | Set to `1` for verbose output |
| `CHZ_DOTFILES_DEBUG` | Set to `1` to enable `set -x` debug mode in dotfile scripts |

---

## What gets installed and configured

### Bash configuration (`~/.bashrc.d/`)

Loaded by `~/.bashrc.d/00-loader.sh` (Fedora's default `~/.bashrc` sources top-level
files in `~/.bashrc.d/` but does not recurse into subdirectories — `00-loader.sh`
handles the subdirs).

| Subdirectory | Contents | Loaded when |
|---|---|---|
| `shared/` | Universal: colors, aliases, functions, prompt | Always |
| `personal/` | Personal: git/chezmoi aliases, dev shortcuts, home paths | Profile = personal |
| `work/` | Work-specific aliases and shortcuts | Profile = work |

Top-level files (loaded outside subdirs):
- `exports` — `EDITOR`, locale, history size, colored man pages
- `wsl2_ssh_agent_support` — WSL2 only: Windows SSH agent forwarding

### Shared file inventory (`~/.bashrc.d/shared/`)

| File | Purpose |
|---|---|
| `00-colors.sh` | ANSI color codes (`FG_*`, `BG_*`) |
| `50-aliases-nav.sh` | Directory navigation (`..`, `...`, `hh`, `ee`, `-`) |
| `50-aliases-ls.sh` | ls variants (`ll`, `la`, `lt`, …) + colored grep |
| `50-aliases-misc.sh` | File ownership, count, history search, networking |
| `50-aliases-power.sh` | reboot, halt, shutdown, reload |
| `80-functions-common.sh` | GitHub release helpers, systemd service check, editor wrapper |
| `99-prompt.sh` | PS1 (root=red, user=green) |

### Utilities installed to `~/.local/bin/`

| Script | Description |
|---|---|
| `edit-evault` | Decrypt → edit → re-encrypt evault via tmpfs (`edit-evault personal\|work`) |
| `extract` | Universal archive extractor (`.tar.gz`, `.zip`, `.bz2`, `.rar`, `.Z`, …) |
| `find-file` | Recursive file finder by glob pattern |
| `simple-server` | Python3 HTTP server (default port 8888) |
| `imxcon` | Serial terminal wrapper for `/dev/ttyUSB{N}` (uses `tio`) |
| `qnx_components` | QNX package manager: list, diff, install QNX components |
| `oldkernelkill.sh` | Fedora: removes old kernel packages via `dnf` |

### System packages

Installed via the package manager detected from `/etc/os-release`:

- **Common**: `git`, `openssl`
- **Personal profile**: `tio`, `keepassxc`, `doublecmd-gtk`
- **Work profile**: (none yet — populate `packages.dnf.work` when first work host arrives)
- **VirtualBox VM**: VirtualBox guest additions (auto-detected via `systemd-detect-virt`)
- **VMware VM**: open-vm-tools (auto-detected)

### User groups

| Group | When added |
|---|---|
| `wheel` | Always (sudo access) |
| `dialout` | Always (serial port access — RPI, NXP boards) |
| `vboxsf` | VirtualBox VM only (shared folder access) |

### Other

- Git remote auto-switches from HTTPS to SSH after first run (enables `git push`
  without a password).
- Chezmoi config (`~/.config/chezmoi/chezmoi.yaml`) is set to `chmod 0600`.

---

## Day-to-day usage

After installation, chezmoi is at `~/.local/bin/chezmoi` (added to `PATH`).
The `ch` alias is also available.

```bash
# See what would change
chezmoi diff

# Apply changes from the repo
chezmoi apply

# Open the source directory
chezmoi cd

# Edit a managed file and apply in one step
chezmoi edit ~/.bashrc.d/personal/git-aliases --apply

# Pull latest changes from GitHub and apply
chezmoi update
```

Useful aliases defined by the dotfiles:

```bash
ch   # chezmoi
chd  # chezmoi cd
```

For comprehensive operator guidance — daily workflow scenarios, edge
cases, recovery patterns, the two-repo (dev vs. managed source) mental
model, and security risks specific to the commit/push flow — see
[`DAILY_WORKFLOW.md`](./DAILY_WORKFLOW.md).

---

## Encryption

Private data uses a **per-profile 2-key model** with two encryption tools:
**Age** (file/key encryption) and **EJSON** (Shopify, structured per-key
encryption within a single JSON file).

Age plays two roles:
1. The external `age` binary decrypts `age_key_<profile>.age` using a
   passphrase (chezmoi's built-in Age does not support passphrases).
2. Chezmoi's built-in Age then decrypts `ejson_key_<profile>.age` using the
   extracted Age key.

### How it works

The bootstrap automatically resolves the full decryption chain on first run,
starting from a single prerequisite — the Age passphrase file:

```
[password manager]   (Age passphrase stored — manual prerequisite, never on disk)
         │
         │ paste into chezmoi TTY prompt
         ▼
    age_key_<profile>.age (repo)  →  ~/.config/chezmoi/age_<profile>.key
         │
         │ chezmoi decrypt (Age, using extracted key)
         ▼
    ejson_key_<profile>.age (repo)  →  ~/.config/chezmoi/keys/<ejson_id>
         │
         │ ejson decrypt (referenced via chezmoi template ejsonValue)
         ▼
    secrets/<profile>/evault   →  structured per-key encrypted JSON
```

Everything after the first step is handled automatically by
`run_once_before_init_age.sh.tmpl` during `chezmoi apply`.

### Encrypted files in the repo

| File | Tool | Contents |
|---|---|---|
| `age_key_personal.age` | Age (passphrase-protected) | Personal Age key (encrypted) |
| `age_key_work.age` | Age (passphrase-protected) | Work Age key (encrypted) |
| `ejson_key_personal.age` | Age (Age-key-protected) | Personal EJSON private key |
| `ejson_key_work.age` | Age (Age-key-protected) | Work EJSON private key |
| `secrets/personal/evault` | EJSON | Personal structured private data |
| `secrets/work/evault` | EJSON | Work structured private data |

### Profile isolation

The operator knows only the passphrase for the active profile (e.g. only
the personal passphrase on a personal machine). With that, it can decrypt:
- `age_key_personal.age` → personal Age key
- `ejson_key_personal.age` → personal EJSON key
- `secrets/personal/evault` → personal structured data

It **cannot** decrypt `age_key_work.age` (different passphrase), so the
entire work secret chain stays opaque. Same isolation in reverse on a work
machine.

A compromised personal machine never exposes work secrets — the encrypted
work blobs sit on disk as opaque ciphertext, and the work Age passphrase
is not available to extract the key.

### Editing an evault

Use the `edit-evault` helper installed at `~/.local/bin/edit-evault`:

```bash
# With --repo flag (one-off)
edit-evault personal --repo ~/devel/homelab/dotfiles

# Or set DOTFILES_REPO once per shell
export DOTFILES_REPO=~/devel/homelab/dotfiles
edit-evault personal
edit-evault work
```

The script decrypts into `/dev/shm` (tmpfs, never on disk), opens
`$EDITOR` (defaults to `nano`), then re-encrypts and writes back to the
**development repo** (where you `git commit`). It refuses to write into
chezmoi's managed source-path (`~/.local/share/chezmoi/`) — those edits
would be reset by `chezmoi update`. Cleanup is automatic — even on
Ctrl-C the plaintext is shredded.

If you skip editing (close editor without changes), no re-encrypt happens
and git stays clean. After a real edit, the file is modified in place:
review with `git diff`, commit, and push. On other machines, run
`chezmoi update` to pull and apply.

Manual workflow (if `edit-evault` is unavailable):

```bash
# Find the EJSON key path for the active profile
chezmoi data | grep ejson

# Decrypt to plaintext
ejson -k <key_folder_path> decrypt secrets/<profile>/evault > evault_dec

# Edit evault_dec, then re-encrypt
ejson -k <key_folder_path> encrypt evault_dec
mv evault_dec secrets/<profile>/evault
```

### Generating new keys for a profile (clean slate)

See [`ENCRYPTION_SETUP.md`](./ENCRYPTION_SETUP.md) for the full step-by-step
guide — covers key generation for a fresh profile, encryption of the Age +
EJSON chain, populating the evault, and a verification script that
exercises the entire decrypt chain end-to-end (including cross-profile
isolation checks).

### Rotating keys (passphrase, Age key, EJSON key)

The chain has three independent layers and each can be rotated
separately. The evault content only depends on the EJSON key — rotating
the passphrase or just the Age key pair does **not** require re-sealing
the evault. See
[`ENCRYPTION_SETUP.md` → Rotating keys](./ENCRYPTION_SETUP.md#rotating-keys)
for the scenario table and the four flows (A: passphrase only, B: Age
key only, C: EJSON key with evault re-seal, D: full re-key).

---

## Repository structure

```
.
├── bootstrap.sh                     # Self-contained installer (curl/wget entry point)
├── .chezmoi.yaml.tmpl               # Chezmoi config template (per-profile crypto vars)
├── .chezmoiversion                  # Required chezmoi version
├── .chezmoiignore.tmpl              # Per-profile masking rules
├── .chezmoidata/
│   └── packages.yaml                # Package lists per profile and package manager
├── .chezmoiscripts/
│   ├── run_once_before_init_age.sh.tmpl         # Profile-aware Age + EJSON unlock
│   ├── run_onchange_install-packages.sh.tmpl    # Re-runs when package list changes
│   └── run_onchange_after_user-settings.sh.tmpl # Group membership + git remote switch
├── .chezmoitemplates/
│   ├── scripts-library              # Shared bash utilities (logging, OS detection)
│   ├── install-os-package           # Package install abstraction (dnf/apt)
│   ├── is-os-command-available      # Command existence check template
│   └── is-package-installed         # Package installation check template
├── dot_bashrc.d/                    # Bash config → ~/.bashrc.d/
│   ├── 00-loader.sh                 # Nested subdir loader
│   ├── exports                      # EDITOR, LANG, HISTSIZE, ...
│   ├── wsl2_ssh_agent_support       # WSL2 only
│   ├── shared/                      # Universal subset (deployed to all profiles)
│   ├── personal/                    # Personal profile only
│   └── work/                        # Work profile only
├── private_dot_local/bin/           # Utility scripts → ~/.local/bin/
├── secrets/
│   ├── personal/evault              # EJSON-encrypted personal data
│   └── work/evault                  # EJSON-encrypted work data
├── helpers/                         # Manual setup helpers (not applied by chezmoi)
│   ├── install-starship.sh
│   └── install-vscode.sh
├── ejson_key_personal.age           # Age-encrypted personal EJSON key
├── ejson_key_work.age               # Age-encrypted work EJSON key
├── age_key_personal.age             # Age-encrypted personal Age key (passphrase-protected)
└── age_key_work.age                 # Age-encrypted work Age key (passphrase-protected)
```

---

## Sharing with homelab

The `shared/` subset is the canonical source for the
[`homelab-automation`](https://github.com/polachz/homelab-automation) shell
profile (`shell_profile_shared/`). The homelab project vendors a snapshot of
`dot_bashrc.d/shared/` and deploys it to `/etc/profile.d/` on homelab VMs.

Workflow when modifying shared files:
1. Edit `dot_bashrc.d/shared/<file>` here
2. Commit + push
3. In `homelab-automation`: `homelab shared-shell sync` (pulls and vendors
   the new snapshot)
4. `homelab vm update-shell-profile <vm>` deploys the new content

See [`homelab-automation`](https://github.com/polachz/homelab-automation)
docs for sync mechanism details.

---

## License

MIT
