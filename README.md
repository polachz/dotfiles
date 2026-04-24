# dotfiles

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/). The repository contains shell configuration, utility scripts, and encrypted private data for multiple deployment types (server, workstation, work environment).

`bootstrap.sh` is a self-contained installer — it requires only `curl` or `wget` to start, downloads chezmoi automatically, and walks you through an interactive setup.

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
- **Age encryption key** at `~/.config/chezmoi/zamecek.txt` — required to decrypt private files. This is the only manual prerequisite; everything else is derived from it automatically during the first run.
- **`age` binary** — required to decrypt `zamecek` (passphrase-based symmetric encryption, which chezmoi's built-in Age does not support). On Linux it is installed automatically by the bootstrap script via dnf/apt. On other platforms install it manually beforehand ([github.com/FiloSottile/age](https://github.com/FiloSottile/age/releases/latest)).
- **EJSON** (`ejson` binary on PATH) — required if the vault (`evault`) contains EJSON-encrypted data. Install from [github.com/Shopify/ejson/releases](https://github.com/Shopify/ejson/releases/latest).
- SSH key configured in GitHub — required only if you want to push changes back after installation (the bootstrap switches the remote from HTTPS to SSH automatically).

---

## Installation

```bash
# Using wget
sh -c "$(wget -qO- https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"

# Using curl
sh -c "$(curl -fsSL https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"
```

The installer presents an interactive menu to select a deployment profile. To skip the menu, pass the profile directly:

```bash
CHZ_DEPLOYMENT_STRING_ID=server CHZ_BOOTSTRAP_ONE_SHOT=1 \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"
```

---

## Deployment profiles

The profile controls which packages are installed, which files are deployed, and which user groups are configured.

| ID | Environment | GUI | Typical use |
|---|---|---|---|
| `server` | personal | no | Minimal VM or remote server |
| `workstation` | personal | no | Headless personal machine |
| `workstation` + gui | personal | yes | Desktop / laptop |
| `nxp` | work | no | Work server / embedded dev machine |
| `nxp` + gui | work | yes | Work desktop with GUI tools |

**VM type** (auto-detected via `systemd-detect-virt`, can be overridden):

| Value | Effect |
|---|---|
| `virtualbox` | Installs VirtualBox guest tools, adds user to `vboxsf` group |
| `vmware` | Installs VMware guest tools |
| `qemu` | QEMU/KVM guest setup |
| _(none)_ | Bare metal, no guest tools |

---

## Bootstrap options

### CLI flags

| Flag | Description |
|---|---|
| `-o`, `--one-shot` | Non-interactive: auto-select `server` profile |
| `-i`, `--deployment-id <id>` | Specify deployment ID (`server`, `workstation`, `nxp`, …) |
| `-d`, `--dry-run` | Show what would change without applying |
| `-a`, `--apply` | Force apply (overrides dry-run default on re-runs) |
| `-v`, `--verbose` | Verbose output |
| `--debug` | Enable debug logging in all dotfile scripts (`set -x`) |
| `--chezmoi-debug` | Pass `--debug` to chezmoi itself |
| `-r`, `--reinit` | Clear chezmoi state and re-apply from scratch |

### Environment variables

| Variable | Description |
|---|---|
| `CHZ_DEPLOYMENT_STRING_ID` | Deployment profile ID (same values as `--deployment-id`) |
| `CHZ_BOOTSTRAP_ONE_SHOT` | Set to `1` to skip interactive menu (selects `server`) |
| `CHZ_BOOTSTRAP_DRY_RUN` | Set to `1` to run in dry-run mode |
| `CHZ_BOOTSTRAP_VERBOSE` | Set to `1` for verbose output |
| `CHZ_DOTFILES_DEBUG` | Set to `1` to enable `set -x` debug mode in all scripts |

> `CHZ_DOTFILES_DEBUG` is different from `--chezmoi-debug`. The former enables shell-level tracing in dotfile scripts; the latter enables chezmoi's internal debug output.

---

## What gets installed and configured

### Bash configuration (`~/.bashrc.d/`)

Loaded automatically from `~/.bashrc`. Each concern lives in its own file:

| File | Contents |
|---|---|
| `aliases` | 70+ aliases — navigation (`..`, `...`), git (`g`, `gcm`, `gst`), listing (`ll`, `la`, `lt`), system (`ports`, `reboot`) |
| `exports` | `EDITOR=nano`, locale (`en_US.UTF-8`), history size, colored man pages |
| `functions` | Helpers: GitHub latest-release URL/version fetcher, systemd service check, `$EDITOR` wrapper |
| `colours.sh` | ANSI color definitions, custom PS1 prompt (color-coded by root/non-root) |
| `chezmoi.tmpl` | Exports `CHZ_DEPLOYMENT_STRING_ID` for scripts |
| `wsl2_ssh_agent_support` | WSL2 only: Windows SSH agent forwarding via `npiperelay.exe` + `socat` |
| `nxp_env`, `qnx800` | Work environment only: QNX SDK paths, iMX/NXP embedded dev aliases |

### Utilities installed to `~/.local/bin/`

| Script | Description |
|---|---|
| `extract` | Universal archive extractor (`.tar.gz`, `.zip`, `.bz2`, `.rar`, `.Z`, …) |
| `find-file` | Recursive file finder by glob pattern |
| `simple-server` | Python3 HTTP server (default port 8888) |
| `imxcon` | Serial terminal wrapper for `/dev/ttyUSB{N}` (uses `tio`) |
| `qnx_components` | QNX package manager: list, diff, and install QNX components |
| `oldkernelkill.sh` | Fedora: removes old kernel packages via `dnf` |

### System packages

Installed via the package manager detected from `/etc/os-release`:

- **All profiles**: `git`, `openssl`
- **Workstation**: `tio` (serial terminal)
- **GUI workstation**: `keepassxc`, `doublecmd-gtk`
- **VirtualBox VM**: VirtualBox guest additions
- **VMware VM**: open-vm-tools

### User groups

| Group | Condition |
|---|---|
| `wheel` | Always (sudo access) |
| `dialout` | Workstation — serial port access (RPI, NXP boards) |
| `vboxsf` | VirtualBox VM — shared folder access |

### Other

- Git remote is automatically switched from HTTPS to SSH after the first run (enables `git push` without a password).
- Chezmoi config (`~/.config/chezmoi/chezmoi.yaml`) is set to `chmod 0600`.

---

## Day-to-day usage

After installation, chezmoi is available at `~/.local/bin/chezmoi` (added to `PATH`). The `ch` alias is also available.

```bash
# See what would change
chezmoi diff

# Apply changes from the repo
chezmoi apply

# Open the source directory
chezmoi cd

# Edit a managed file and apply in one step
chezmoi edit ~/.bashrc --apply

# Pull latest changes from GitHub and apply
chezmoi update
```

Useful aliases defined by the dotfiles:

```bash
ch   # chezmoi
chd  # chezmoi diff
```

---

## Encryption

Private files are stored encrypted using two complementary tools: **Age** and **EJSON** (Shopify, for structured JSON data).

Age is used in two distinct roles: the external `age` binary decrypts `zamecek` using a passphrase (chezmoi's built-in Age does not support passphrases), and chezmoi's built-in Age handles all subsequent file encryption using the extracted key file.

### How it works

The bootstrap automatically resolves the full decryption chain on first run, starting from a single prerequisite — the Age key at `~/.config/chezmoi/zamecek.txt`:

```
~/.config/chezmoi/zamecek.txt   (Age key — manual prerequisite)
         │
         │ age decrypt
         ▼
    zamecek (repo)  →  confirms key is valid
         │
         │ chezmoi decrypt (Age)
         ▼
    ezamecek (repo)  →  ~/.config/chezmoi/keys/<key_id>   (EJSON private key)
         │
         │ ejson decrypt
         ▼
    evault (repo)   →  structured private data
```

Everything after the first step is handled automatically by `run_once_before_init_age.sh.tmpl` during `chezmoi apply`.

### Encrypted files in the repo

| File | Tool | Contents |
|---|---|---|
| `zamecek` | Age | Encrypted copy of the Age key passphrase |
| `ezamecek` | Age | EJSON private key (encrypted with Age) |
| `evault` | EJSON | Structured private data (API tokens, SSH config, …) |

### Editing the vault

To modify `evault`, decrypt it manually, edit, then re-encrypt:

```bash
# Find the EJSON key path
ch data | grep keys

# Decrypt
ejson -k <key_folder_path> decrypt evault > evault_dec

# Edit evault_dec, then re-encrypt
ejson -k <key_folder_path> encrypt evault_dec
mv evault_dec evault
```

---

## Repository structure

```
.
├── bootstrap.sh                    # Self-contained installer (curl/wget entry point)
├── .chezmoi.yaml.tmpl              # Chezmoi config template (deployment variables)
├── .chezmoiversion                 # Required chezmoi version (2.47.0)
├── .chezmoiignore.tmpl             # Environment-specific file exclusions
├── .chezmoidata/
│   └── packages.yaml               # Package lists per profile and package manager
├── .chezmoiscripts/
│   ├── run_once_before_init_age.sh.tmpl          # One-time: Age key setup
│   ├── run_onchange_install-packages.sh.tmpl     # Re-runs when package list changes
│   └── run_onchange_user-settings.sh.tmpl        # Re-runs when user/group settings change
├── .chezmoitemplates/
│   ├── scripts-library             # Shared bash utilities (logging, OS detection)
│   ├── install-os-package          # Package install abstraction (dnf/apt)
│   ├── is-os-command-available     # Command existence check template
│   └── is-package-installed        # Package installation check template
├── dot_bashrc.d/                   # Bash config modules → ~/.bashrc.d/
├── private_dot_local/bin/          # Utility scripts → ~/.local/bin/
├── helpers/                        # Manual setup helpers (not applied by chezmoi)
│   ├── install-starship.sh         # Install Starship prompt from GitHub releases
│   └── install-vscode.sh           # Set up VSCode yum repo on Fedora
├── evault                          # Encrypted private data (Age)
├── ezamecek                        # Encrypted EJSON keys (Age)
└── zamecek                         # Encrypted vault passphrase (Age)
```

---

## License

MIT
