# dotfiles

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/). Two profiles
(`personal` and `work`) with **cryptographic separation** — a personal machine
physically cannot decrypt work secrets, and vice versa. One data model drives
**three shells** (bash, zsh, fish) plus terminal (Ghostty) and prompt
(Oh My Posh) configuration.

## Documentation

| Doc | Read this when... |
|---|---|
| This file | First-time setup, what gets installed, day-to-day quick reference |
| [`docs/DAILY_WORKFLOW.md`](docs/DAILY_WORKFLOW.md) | Doing anything day-to-day: changing a file, adding an alias, syncing machines, recovering from a broken state |
| [`docs/ALIASES.md`](docs/ALIASES.md) | Looking up (or adding) an alias, environment variable, or shell function |
| [`docs/ENCRYPTION_SETUP.md`](docs/ENCRYPTION_SETUP.md) | Setting up encryption on a new profile, or rotating/recovering keys |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | You need the "why" behind a design decision |

## Quick start — bootstrap

**macOS / Linux** (needs only `curl` or `wget` — downloads chezmoi
automatically and walks you through profile selection):

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"
```

**Windows** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.ps1 | iex
```

See "Installation" below for prerequisites, profile/role/GUI flags, and
Windows-specific notes.

---

## Supported platforms

| Platform | Support |
|---|---|
| macOS (Apple Silicon) | Primary — real work-profile machine |
| Fedora / RHEL (dnf) | Primary |
| Debian / Ubuntu (apt) | Partial (see [`docs/ARCHITECTURE.md` § Never-own-rc-files](docs/ARCHITECTURE.md#4-never-own-rc-files) for a known `~/.bashrc.d` auto-sourcing gap, self-healed) |
| WSL2 (Windows Subsystem for Linux) | Supported (includes Windows SSH agent relay) |
| Native Windows / PowerShell | Supported via `bootstrap.ps1`, except git identity (see below — no EJSON binary for Windows yet) |

Shells: **bash**, **zsh**, **fish** — one shared alias/env-variable data
model renders into all three. Native prompt (root=red/user=green) is
universal; [Oh My Posh](https://ohmyposh.dev/) layers on top wherever it's
installed (zsh/fish/PowerShell — not bash).

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
- **macOS only**: bootstrap headlessly installs Xcode Command Line Tools
  (needed for `git`, and — confirmed live — also hard-required by Homebrew's
  own `.pkg` installer preinstall check) if missing, then self-installs
  [Homebrew](https://brew.sh/) via its official `.pkg` installer.
- SSH key configured in GitHub — required only if you want to push changes
  back after installation.

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

`bootstrap.sh` only resolves the **profile** (personal/work) — the two
newer, orthogonal init-time facts, **role** (`workstation`/`server`) and
**has_gui** (whether to deploy GUI-only config like Ghostty), are resolved
directly by chezmoi itself the first time it runs, env-var-first:

```bash
DOTFILES_ROLE=server DOTFILES_HAS_GUI=false \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)" -- --profile work
```

If `DOTFILES_ROLE`/`DOTFILES_HAS_GUI` aren't set, chezmoi prompts
interactively (once — cached in `~/.config/chezmoi/chezmoi.yaml`, never
committed to the repo). `DOTFILES_PROFILE` also works as a direct chezmoi-level
override, equivalent to `bootstrap.sh --profile`.

### Windows

`bootstrap.ps1` is the PowerShell sibling of `bootstrap.sh` — same flags/env
vars (`-DotfilesProfile`/`-Role`/`-Gui`/`-Branch`, `CHZ_DEPLOYMENT_*`), same
interactive menus if you omit them. Installs `chezmoi`/`git` via `winget`
(no manual prerequisite installs needed).

```powershell
irm https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.ps1 | iex
```

Or download and run with flags to skip the menus:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.ps1 -OutFile bootstrap.ps1
.\bootstrap.ps1 -DotfilesProfile work -Role workstation -Gui yes
```

**Known limitation**: there's no EJSON binary for Windows yet, so the
encrypted evault chain (currently used only for per-profile git identity —
`user.name`/`user.email`) can't resolve. `bootstrap.ps1` detects this
specific, expected failure and works around it automatically — everything
else (shell aliases/functions/prompt, Oh My Posh, winget packages) still
ends up fully configured. Git identity itself stays unset until Windows
EJSON support is built (tracked in [`CONCEPT_ROADMAP.md`](./CONCEPT_ROADMAP.md)).

---

## Profiles, role, and GUI — three independent axes

| Axis | Values | Meaning |
|---|---|---|
| **Profile** | `personal` / `work` | Identity — separate Age/EJSON keys, separate secrets, separate git/SSH identity. Cryptographically isolated. |
| **Role** | `workstation` / `server` | Orthogonal to profile — same identity/keys, different package selection. Every tool in `.chezmoidata/packages.yaml` declares which role(s) it installs on (default: both) — see [`docs/ARCHITECTURE.md` § Package/tool installation model](docs/ARCHITECTURE.md#10-packagetool-installation-model). |
| **has_gui** | `true` / `false` | Orthogonal to role — a workstation can be headless. Gates GUI-only config/packages — Ghostty in `.chezmoiignore.tmpl`, plus any package with `requires_gui: true` (Bitwarden, Windows Terminal, Total Commander). Shell-level config (aliases, env, prompt, Oh My Posh) deploys regardless. |

Each profile has:
- Its own shell config subdirectory (`~/.bashrc.d/{personal,work}/`,
  `~/.zshrc.d/{personal,work}/`)
- Its own encrypted secrets vault (`secrets/personal/evault` or `secrets/work/evault`)
- Its own Age key pair (`age_key_personal.age` / `age_key_work.age`)
- Its own EJSON key pair (`ejson_key_personal.age` / `ejson_key_work.age`)
- Its own git identity fragment (`~/.config/git/{personal,work}/common.gitconfig`)
- Its own SSH config fragments (`~/.ssh/conf.d/*-{personal,work}-*.conf`)

`.chezmoiignore.tmpl` ensures only the active profile's files reach disk on a
given machine. The encrypted blobs for the OTHER profile come along with the
repo clone, but they can't be decrypted without the matching Age key.

---

## Bootstrap options

### CLI flags

| Flag | Description |
|---|---|
| `-p`, `--profile <personal\|work>` | Pre-select profile (skip menu) |
| `--role <workstation\|server>` | Pre-select machine role (skip menu) |
| `--gui <yes\|no>` | Pre-select GUI presence (skip menu) |
| `--sudo <yes\|no>` | Do you have sudo/root access on this machine? (always asks if omitted — a shared server you're not admin on is a common case) `no` skips every root-only step (package install, group membership, the `/root` shell mirror) instead of trying and prompting for a password that will never come; everything else still applies |
| `-b`, `--branch <name>` | Clone/checkout this git branch instead of the default branch (e.g. to bootstrap from a work-in-progress branch not yet merged to main) |
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
| `CHZ_DEPLOYMENT_PROFILE` | Profile selector (`personal` or `work`) — same as `--profile`. Bridged internally to `DOTFILES_PROFILE` before invoking chezmoi. |
| `CHZ_DEPLOYMENT_ROLE` | Role selector (`workstation` or `server`) — same as `--role`. Bridged internally to `DOTFILES_ROLE`. |
| `CHZ_HAS_GUI` | GUI presence (`yes` or `no`) — same as `--gui`. Bridged internally to `DOTFILES_HAS_GUI` (`true`/`false`). |
| `CHZ_HAS_ROOT` | Sudo/root availability (`yes` or `no`) — same as `--sudo`. Bridged internally to `DOTFILES_HAS_ROOT` (`true`/`false`) and, like the three above, cached into `chezmoi.yaml` at init time (`promptBoolOnce`) — asked once, never re-prompted on a plain `chezmoi update`. |
| `CHZ_BOOTSTRAP_BRANCH` | Same as `--branch` |
| `CHZ_BOOTSTRAP_DRY_RUN` | Set to `1` to run in dry-run mode |
| `CHZ_BOOTSTRAP_VERBOSE` | Set to `1` for verbose output |
| `CHZ_DOTFILES_DEBUG` | Set to `1` to enable `set -x` debug mode in dotfile scripts |
| `DOTFILES_PROFILE` / `DOTFILES_ROLE` / `DOTFILES_HAS_GUI` / `DOTFILES_HAS_ROOT` | Read directly by chezmoi's `.chezmoi.yaml.tmpl` — set these yourself to bypass bootstrap.sh's menus entirely (e.g. CI, lab VM automation) |

---

## What gets installed and configured

### Shells: shared data, per-shell rendering

Aliases (`.chezmoidata/aliases/**/*.yaml`) and environment variables
(`.chezmoidata/env/**/*.yaml`) are defined **once**, in YAML, then rendered
per-shell at `chezmoi apply` time — the deployed files are plain,
non-templated shell scripts, only regenerated when the source YAML changes:

| Shell | Renderer | Deployed to |
|---|---|---|
| bash + zsh (shared — `alias`/`export` syntax is identical) | `dot_bashrc.d/50-aliases-generated.sh.tmpl`, `dot_bashrc.d/05-env-generated.sh.tmpl` | `~/.bashrc.d/{50-aliases-generated.sh,05-env-generated.sh}`, sourced from zsh too via `~/.zshrc.d/00-shared.zsh` |
| fish | `dot_config/fish/conf.d/{aliases,env}.fish.tmpl` | `~/.config/fish/conf.d/` (fish autoloads `conf.d/*.fish`) |

Per-entry `command`/`value` can be a plain string or an OS-keyed map (with
`skip` for "doesn't apply on this OS") — resolved by the shared
`.chezmoitemplates/resolve-os-value` partial.

**`~/.bashrc`, `~/.zshrc`, and `~/.ssh/config`/`~/.gitconfig` are never fully
owned by chezmoi** — each already has, or can accumulate, genuinely
important non-dotfiles content (shell rc files pick up SDK/tool init lines;
`~/.gitconfig` gets edited by `git lfs`, credential managers, etc.). Instead,
an idempotent, self-healing `run_after_ensure-*-sourcing.sh.tmpl` /
`run_after_ensure-gitconfig-includes.sh.tmpl` script appends a small
`source`/`Include`/`[include]` block **only if missing**, and everything
else lives in a dedicated, fully chezmoi-owned location:

| Owned by chezmoi | Never touched |
|---|---|
| `~/.bashrc.d/`, `~/.zshrc.d/` | `~/.bashrc`, `~/.zshrc` (just gets one sourcing block appended once) |
| `~/.ssh/conf.d/*.conf` | `~/.ssh/config` (just gets `Host *` + `Include` appended once) |
| `~/.config/git/**/*.gitconfig` | `~/.gitconfig` (gets `[include]`/`[includeIf]` blocks appended, one per fragment, self-healing per block) |

### Bash configuration (`~/.bashrc.d/`)

Universal files live at the top level of `~/.bashrc.d/` and are loaded by
Fedora's default `~/.bashrc` (which sources top-level files but does not
recurse) — on distros without that convention (e.g. Ubuntu 24.04 LTS),
`run_after_ensure-bashrc-sourcing.sh.tmpl` adds the equivalent sourcing block
itself. Profile-specific files live in subdirectories, sourced by
`~/.bashrc.d/00-loader.sh`:

| File | Purpose |
|---|---|
| `00-colors.sh` | ANSI color codes (`FG_*`, `BG_*`) |
| `01-bash-history.sh` | `HISTSIZE`/`HISTFILESIZE`/`HISTCONTROL`/`HISTIGNORE` |
| `05-env-generated.sh` | Generated from `.chezmoidata/env/` (see above) |
| `50-aliases-generated.sh` | Generated from `.chezmoidata/aliases/` (see above), includes power management (reboot/halt/shutdown/reload) |
| `80-functions-common.sh` | `color` — ANSI escape helper. Also shared into zsh. |
| `99-prompt.sh` | PS1 (root=red, user=green) |
| `wsl2_ssh_agent_support` | WSL2 only: Windows SSH agent forwarding |
| `personal/`, `work/` | Profile-specific aliases (git shortcuts, chezmoi shortcuts, home-dir shortcuts — currently only under `personal/`, `work/` is an empty placeholder) |

### Zsh configuration (`~/.zshrc.d/`)

zsh has no OS-provided auto-sourcing convention at all, so
`run_after_ensure-zshrc-sourcing.sh.tmpl` always appends the sourcing block.
zsh can't blindly share bash's files (`export -f` is broken in zsh, PS1
syntax differs) — `00-shared.zsh` explicitly sources the subset that *is*
byte-identical (colors, generated env/aliases, `80-functions-common.sh`):

| File | Purpose |
|---|---|
| `00-loader.zsh` | Profile subdir loader (personal/work) |
| `00-shared.zsh` | Sources the zsh-compatible subset of `~/.bashrc.d/*` |
| `01-history.zsh` | zsh-native `SAVEHIST`/`HISTFILE`/`setopt HIST_IGNORE_*` |
| `10-path.zsh` | `PATH` additions |
| `10-bitwarden-ssh-agent.zsh` | macOS Bitwarden desktop SSH agent socket |
| `99-prompt.zsh` | zsh-native prompt (same colors as bash's `99-prompt.sh`, different syntax — can't be shared) |
| `99-theme-init.zsh` | `eval "$(oh-my-posh init zsh --config ...)"` if installed (named "theme-init", not "ohmyposh-init" — has to sort after `99-prompt.zsh` alphabetically so its `PROMPT` assignment wins) |
| `work/10-gcloud.zsh`, `work/10-vertex-ai.zsh` | Work-only: Google Cloud SDK + Claude Code Vertex AI env vars |

### Fish configuration (`~/.config/fish/conf.d/`)

Fish autoloads everything in `conf.d/*.fish`, so there's no loader file —
just the generated `aliases.fish`/`env.fish` (see above, rendered as `abbr`
by default so history stores the expanded command) plus
`ohmyposh-init.fish` (`oh-my-posh init fish --config ... | source`, if installed).
`functions/fish_prompt.fish` provides the native root=red/user=green
fallback prompt (bash/zsh's `99-prompt.sh`/`.zsh` equivalent) — fish
autoloads it lazily only if `ohmyposh-init.fish` hasn't already defined
`fish_prompt` at shell startup, so it's a true fallback, never a competing
override.

### Terminal & prompt

- **[Ghostty](https://ghostty.org/)** (`dot_config/private_ghostty/`) — only
  deployed when `has_gui: true` and OS is macOS/Linux (no Windows build).
  Composed via Ghostty's native `config-file = ?path` include (silent no-op
  on a missing fragment): `common.conf` → `{profile}/common.conf` →
  `{profile}/{os}.conf`, later overrides earlier.
- **[Oh My Posh](https://ohmyposh.dev/)** (`dot_config/oh-my-posh/atomic.omp.json`)
  — a single theme file vendored directly in the repo (not a package-manager
  bundled theme path, which differs across brew/dnf/winget installs), used
  identically by every shell's init. Deployed everywhere (shell-level, works
  over SSH too), layers on top of the native prompt above wherever it's
  actually installed — zsh/fish/PowerShell (not bash), including PowerShell
  (`Documents/PowerShell/dotfiles.d/99-ohmyposh-init.ps1`, install via
  `winget install --id JanDeDobbeleer.OhMyPosh`).
- **PSReadLine fish-style autosuggestions** (PowerShell only,
  `Documents/PowerShell/dotfiles.d/90-psreadline.ps1`) — bundled with
  PowerShell 7, nothing extra to install. `-PredictionSource History
  -PredictionViewStyle ListView`, guarded to skip when the console doesn't
  support it (e.g. `$PROFILE` loaded with redirected output).
- **Windows Terminal** (`AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/`)
  — only deployed when `has_gui: true` and OS is Windows. Uses Windows
  Terminal's native ["fragment
  extension"](https://learn.microsoft.com/windows/terminal/json-fragment-extensions)
  mechanism to add a `Dotfiles` profile (font-size only, same minimal scope
  as Ghostty above) without ever touching the user's real, MSIX-packaged,
  JSONC `settings.json`. Purely additive (own fixed GUID, never an
  `"updates"` reference) — no conflict with existing profiles possible.
  Setting it as the default profile is out of scope (see
  [`docs/ARCHITECTURE.md` § Terminal, prompt, and editor](docs/ARCHITECTURE.md#9-terminal-prompt-and-editor))
  — pick it manually from the profile dropdown.
- **macOS Terminal.app** — only `role: workstation` + `has_gui: true`. Not
  otherwise managed by this repo (no config file to own), but its default
  and startup profile get the same JetBrainsMono Nerd Font as Ghostty, set
  via AppleScript (`osascript`). The first `chezmoi apply` that touches
  Terminal.app triggers a one-time macOS Automation permission prompt that
  can't be granted non-interactively — self-heals on the next apply after
  it's allowed. See [`docs/ARCHITECTURE.md` § Terminal, prompt, and
  editor](docs/ARCHITECTURE.md#9-terminal-prompt-and-editor) for a real
  AppleScript dictionary bug found along the way.

### SSH config (`~/.ssh/conf.d/`)

Fragments are matched by filename (`Include` needs a flat directory, unlike
git), numbered so the most specific wins (SSH is first-match-wins, the
opposite of git):

| File | Scope | Purpose |
|---|---|---|
| `50-work-redhat.conf` | work | GSSAPI settings for `*.redhat.com` |
| `50-work-labvms.conf` | work | UTM lab test VM shortcuts (`maclab`, `windev`) |
| `90-common.conf` | universal | `SetEnv TERM=xterm-256color` — works around Ghostty's `TERM=xterm-ghostty` breaking remote hosts without a matching terminfo entry |

On Windows, `Include` doesn't work at all in Win32-OpenSSH (verified live —
it hangs `ssh.exe` indefinitely on absolute/tilde paths, silently no-ops on
relative ones, on both the in-box client and the latest upstream release) —
`run_after_ensure-sshconfig-sourcing.ps1.tmpl` embeds the fragment content
directly into `$HOME\.ssh\config` instead, inside a managed
`# BEGIN/END dotfiles conf.d` block regenerated on every apply.

### Git config (`~/.config/git/`)

| File | Scope | Purpose |
|---|---|---|
| `common.gitconfig` | universal | Empty — no OS/profile-independent setting identified yet |
| `{personal,work}/common.gitconfig.tmpl` | per-profile | `[user]` name/email (fallback identity) — **sourced from the profile's EJSON evault** (`git.user`/`git.email`), not plaintext |
| `{personal,work}/hosts/github.gitconfig.tmpl` | per-profile | Per-host override for GitHub remotes (`includeIf hasconfig:remote.*.url:...`) — `[user] email` from the evault's `git.github_email` (GitHub "keep my email private" noreply address) |

**First real use of the evault-secret-injection mechanism** (see
[`docs/ARCHITECTURE.md` § Git configuration](docs/ARCHITECTURE.md#5-git-configuration)) — these
four files are `.tmpl` and call `.chezmoitemplates/evault-field`, which shells out to `ejson
decrypt` at apply-time. This means **git identity now requires an already-unlocked EJSON key**
for that profile (`run_once_before_init_age.sh.tmpl` sets this up, runs before file application
in the same apply) — a real behavior change from before, when git config was plain, secret-free
text that worked with zero prerequisites. Missing key → the whole `chezmoi apply` fails loudly on
these files, not a silent empty value.

Same fragments on Windows too (`run_after_ensure-gitconfig-includes.ps1.tmpl`)
— git for Windows honors `$HOME` and tilde-expands `path =` values itself,
so the include/includeIf mechanism works unchanged there, unlike SSH.

To change identity values, `edit-evault {personal,work}` and edit the `git.user`/`git.email`/
`git.github_email` fields — never edit the rendered `~/.config/git/...` files directly (chezmoi
would overwrite them, and the source `.tmpl` files no longer contain any plaintext identity to
edit anyway).

### Utilities installed to `~/.local/bin/`

| Script | Description |
|---|---|
| `edit-evault` | Decrypt → edit → re-encrypt evault via tmpfs (`edit-evault personal\|work`) |
| `extract` | Universal archive extractor (`.tar.gz`, `.zip`, `.bz2`, `.rar`, `.Z`, …) |
| `find-file` | Recursive file finder by glob pattern |
| `simple-server` | Python3 HTTP server (default port 8888) |
| `imxcon` | Serial terminal wrapper for `/dev/ttyUSB{N}` (uses `tio`) |
| `oldkernelkill.sh` | Fedora: removes old kernel packages via `dnf` |

### System packages

Tool-first model in `.chezmoidata/packages.yaml` — one list per tool, with
per-manager (`dnf`/`apt`/`brew`/`winget`) name overrides, a `roles` filter
(workstation/server), an optional `requires_gui`/`vm_types` filter, and an
optional `copr` (dnf) install step. `dnf`/`apt`/`brew` default to the tool's
`name` when omitted; `winget` always needs an explicit ID (string or a map
for extra flags like `installer_type`/`scope`); `skip` means that manager
doesn't have it — see [`docs/ARCHITECTURE.md` § Package/tool installation
model](docs/ARCHITECTURE.md#10-packagetool-installation-model) for the full
field reference. Installed via `run_onchange_install-packages.sh.tmpl`
(dnf/apt/brew, bash) or `run_onchange_install-packages.ps1.tmpl` (winget,
PowerShell — bash has no default interpreter on Windows, see that section).

- **Common** (workstation only): `git`
- **Workstation tools**: `oh-my-posh` (dnf/brew/winget — no default apt repo
  yet), `bitwarden` (GUI password manager, `requires_gui`), `powershell7`
  (Windows-only, `installer_type: wix`), `ghostty` (Linux/macOS only, dnf via
  COPR `scottames/ghostty`), `windows-terminal` (Windows-only, install only —
  `settings.json` config is a follow-up task), `totalcmd` (Windows-only,
  `Ghisler.TotalCommander`)
- **VirtualBox VM**: VirtualBox guest additions (auto-detected via `systemd-detect-virt`)
- **VMware VM**: open-vm-tools (auto-detected)

Deferred: a proper apt repo/GitHub-release fallback for `oh-my-posh` on
Debian/Ubuntu (no default apt package) — `.chezmoitemplates/get-github-latest-verson`
exists but isn't wired in yet.

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
The `ch` alias is also available on the personal profile.

```bash
# See what would change
chezmoi diff

# Apply changes from the repo
chezmoi apply

# Open the source directory
chezmoi cd

# Pull latest changes from GitHub and apply
chezmoi update
```

Alias/env changes are **data-only** — edit the YAML in
`.chezmoidata/{aliases,env}/` directly, or use `edit-aliases-core
aliases/common/<file>.yaml` (validates + regenerates `docs/ALIASES.md`
automatically), then `chezmoi apply`/`chezmoi update`.

For the complete, theme-grouped list of every alias, environment variable,
and function — universal and personal — see [`docs/ALIASES.md`](docs/ALIASES.md).

For comprehensive operator guidance — daily workflow scenarios, edge
cases, recovery patterns, the repo model, and security risks specific to the
commit/push flow — see [`docs/DAILY_WORKFLOW.md`](docs/DAILY_WORKFLOW.md).

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

**Partially wired up**: git identity (`git.user`/`git.email`/`git.github_email`,
see "Git config" above) is the first real consumer, pulling values out of the
evault via `.chezmoitemplates/evault-field` at apply time. The equivalent
mechanism for plain environment variables (`secret: true`/`evault_key`
fields in `.chezmoidata/env/`) is designed but not implemented yet.

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

Use the `edit-evault` helper installed at `~/.local/bin/edit-evault` (a
PowerShell function of the same name on Windows):

```bash
edit-evault personal
edit-evault work

# Point at a different repo instead of the default (one-off, or
# export DOTFILES_REPO once per shell to make it the default)
edit-evault personal --repo ~/Devel/dotfiles
```

The script decrypts into `/dev/shm` (tmpfs, never on disk), opens
`$EDITOR` (defaults to `nano`), then re-encrypts and writes back to the
repo — by default chezmoi's own source-path (a real git repo, `chd`/
`chezmoi cd` drops you into it to commit/push), or `--repo`/
`$DOTFILES_REPO` if you keep a separate clone. Cleanup is automatic — even
on Ctrl-C the plaintext is shredded.

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

See [`docs/ENCRYPTION_SETUP.md`](docs/ENCRYPTION_SETUP.md) for the full step-by-step
guide — covers key generation for a fresh profile, encryption of the Age +
EJSON chain, populating the evault, and a verification script that
exercises the entire decrypt chain end-to-end (including cross-profile
isolation checks).

### Rotating keys (passphrase, Age key, EJSON key)

The chain has three independent layers and each can be rotated
separately. The evault content only depends on the EJSON key — rotating
the passphrase or just the Age key pair does **not** require re-sealing
the evault. See
[`docs/ENCRYPTION_SETUP.md` → Rotating keys](docs/ENCRYPTION_SETUP.md#rotating-keys)
for the scenario table and the four flows (A: passphrase only, B: Age
key only, C: EJSON key with evault re-seal, D: full re-key).

---

## Repository structure

```
.
├── docs/
│   ├── ARCHITECTURE.md              # Design rationale — read this for the "why"
│   ├── DAILY_WORKFLOW.md            # Operator runbook — day-to-day scenarios, recovery
│   ├── ENCRYPTION_SETUP.md          # Key generation, verification, rotation
│   └── ALIASES.md                   # Generated alias/env/function reference
├── CONCEPT_ROADMAP.md               # Working notes for the ongoing rework — not final documentation
├── bootstrap.sh                     # Self-contained installer (curl/wget entry point, macOS/Linux)
├── bootstrap.ps1                    # Self-contained installer (Windows, PowerShell)
├── .chezmoi.yaml.tmpl               # Chezmoi config template (profile/role/has_gui, crypto vars)
├── .chezmoiversion                  # Required chezmoi version
├── .chezmoiignore.tmpl              # Per-profile/OS/GUI masking rules
├── .chezmoidata/
│   ├── packages.yaml                # Tool-first package list (roles/requires_gui/vm_types/per-manager overrides)
│   ├── aliases/common/*.yaml        # Shared alias data (bash+zsh+fish renderers)
│   └── env/common/*.yaml            # Shared env-variable data
├── .chezmoiscripts/
│   ├── run_once_before_init_age.sh.tmpl          # Profile-aware Age + EJSON unlock (non-Windows only)
│   ├── run_onchange_install-packages.sh.tmpl     # dnf/apt/brew install, re-runs on package list change (non-Windows only)
│   ├── run_onchange_install-packages.ps1.tmpl    # winget install, same data (Windows only)
│   ├── run_onchange_after_user-settings.sh.tmpl  # Group membership + git remote switch (non-Windows only)
│   ├── run_after_ensure-bashrc-sourcing.sh.tmpl  # Idempotent ~/.bashrc.d sourcing (non-Windows only)
│   ├── run_after_ensure-zshrc-sourcing.sh.tmpl   # Idempotent ~/.zshrc.d sourcing (non-Windows only)
│   ├── run_after_ensure-sshconfig-sourcing.sh.tmpl    # Idempotent ~/.ssh/conf.d Include (non-Windows only)
│   ├── run_after_ensure-gitconfig-includes.sh.tmpl    # Idempotent ~/.gitconfig includes (non-Windows only)
│   ├── run_after_ensure-sshconfig-sourcing.ps1.tmpl   # Embeds conf.d content directly — Include is broken on Win32-OpenSSH (Windows only)
│   ├── run_after_ensure-gitconfig-includes.ps1.tmpl   # Same include/includeIf blocks as bash (Windows only)
│   └── run_after_ensure-powershell-profile-sourcing.ps1.tmpl  # Idempotent $PROFILE dotfiles.d sourcing (Windows only)
├── .chezmoitemplates/
│   ├── scripts-library              # Shared bash utilities (logging, sudo wrapper, OS detection)
│   ├── resolve-os-value             # Shared OS-value resolver (aliases/env)
│   ├── resolve-package-entry        # dnf/apt/brew name resolution for packages.yaml
│   ├── render-winget-install        # Full `winget install ...` command builder for packages.yaml
│   ├── install-os-package           # Single-package install abstraction (dnf/apt/brew, used outside packages.yaml e.g. for `age`)
│   └── get-github-{latest-verson,head-revision}
├── dot_bashrc.d/                    # Bash config → ~/.bashrc.d/
├── dot_zshrc.d/                     # Zsh config → ~/.zshrc.d/
├── dot_config/
│   ├── fish/conf.d/                 # Fish config → ~/.config/fish/conf.d/
│   ├── private_ghostty/             # Ghostty config → ~/.config/ghostty/
│   ├── private_git/                 # Git config fragments → ~/.config/git/
│   └── oh-my-posh/atomic.omp.json   # → ~/.config/oh-my-posh/atomic.omp.json
├── private_dot_ssh/conf.d/          # SSH config fragments → ~/.ssh/conf.d/
├── private_dot_local/bin/           # Utility scripts → ~/.local/bin/
├── Documents/PowerShell/dotfiles.d/ # PowerShell aliases/env/prompt (Windows only) → Documents\PowerShell\dotfiles.d\
├── AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/  # Windows Terminal fragment (Windows only, GUI only)
├── secrets/
│   ├── personal/evault              # EJSON-encrypted personal data
│   └── work/evault                  # EJSON-encrypted work data
├── helpers/                         # Manual setup helpers (not applied by chezmoi;
│   │                                 install-vscode.sh is legacy)
│   └── setup-encryption.sh
├── ejson_key_personal.age           # Age-encrypted personal EJSON key
├── ejson_key_work.age               # Age-encrypted work EJSON key
├── age_key_personal.age             # Age-encrypted personal Age key (passphrase-protected)
└── age_key_work.age                 # Age-encrypted work Age key (passphrase-protected)
```

---

## License

MIT
