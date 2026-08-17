# Aliases, environment variables & functions reference

**Partially auto-generated** (`CONCEPT_ROADMAP.md` §3.4). The blocks between
`<!-- GENERATED:... -->` markers are generated straight from
`.chezmoidata/aliases/` and `.chezmoidata/env/` — regenerate with
`edit-aliases-core` (no args = regen-only mode; give it a YAML file path to
edit + validate + regenerate in one step). Never edit inside those markers by
hand, it's overwritten verbatim on every regeneration. Everything outside the
markers (prose, non-YAML-sourced sections like Power management or the
personal/zsh-only scopes) is still hand-maintained.

**Looking to add a new entry, not just look one up?** See
[`DAILY_WORKFLOW.md` → S10 (alias)](./DAILY_WORKFLOW.md#s10-add-a-new-alias),
[S11 (env var)](./DAILY_WORKFLOW.md#s11-add-a-new-environment-variable), or
[S13 (scope split / include precedence reference)](./DAILY_WORKFLOW.md#s13-the-commonpersonalwork-split-and-include-composition--reference).

Aliases and env vars are defined once in YAML and rendered per-shell
(bash, zsh, fish) at `chezmoi apply` time — see
[`README.md` → Shells: shared data, per-shell rendering](./README.md#shells-shared-data-per-shell-rendering).
`kind: abbr` (fish default) expands visibly on space keypress; bash/zsh have
no `abbr` equivalent, so every entry renders as a plain `alias` there
regardless of `kind`.

---

<!-- GENERATED:aliases-doc-aliases:start (see .chezmoitemplates/generate-aliases-doc-aliases; regenerate with `edit-aliases-core`, no args = regen-only mode — do not edit this block by hand) -->
## Common scope — aliases (`.chezmoidata/aliases/common/`)

### `ls`

| Command | Linux | macOS | Windows | Kind | Description |
|---|---|---|---|---|---|
| `ll` | `ls -l --color` | `ls -l -G` | `Get-ChildItem` | abbr | List all files and folders in long format |
| `la` | `ls -A --color` | `ls -A -G` | `Get-ChildItem -Force` | abbr | List all entries including hidden ones |
| `lla` | `ls -Al --color` | `ls -Al -G` | `Get-ChildItem -Force` | abbr | List all entries including hidden ones, in long format |
| `ld` | `ls -d --color */` | `ls -d -G */` | `Get-ChildItem -Directory` | abbr | List only directories |
| `lld` | `ls -ld --color */` | `ls -ld -G */` | `Get-ChildItem -Directory` | abbr | List only directories, in long format |
| `lh` | `ls -ld --color .[^.]* ..?*` | `ls -ld -G .[^.]* ..?*` | `Get-ChildItem -Hidden` | abbr | List only hidden files and directories |
| `llh` | `ls -ld --color .[^.]* ..?*` | `ls -ld -G .[^.]* ..?*` | `Get-ChildItem -Hidden` | abbr | List only hidden files and directories, in long format |
| `lt` | `ls --human-readable --size -1 -S --classify` | `ls --human-readable --size -1 -S --classify` | `Get-ChildItem \| Sort-Object Length -Descending` | abbr | List folder contents sorted by size, with item type marker |
| `lm` | `ls -t -1 --color` | `ls -t -1 -G` | `Get-ChildItem \| Sort-Object LastWriteTime -Descending` | abbr | List files sorted by modification date, newest first |
| `grep` | `grep --color=auto` | `grep --color=auto` | `Select-String` | alias | Colorized grep (pipes stdin) |
| `fgrep` | `fgrep --color=auto` | `fgrep --color=auto` | `Select-String -SimpleMatch` | alias | Colorized fgrep (pipes stdin) |
| `egrep` | `egrep --color=auto` | `egrep --color=auto` | `Select-String` | alias | Colorized egrep (pipes stdin) |

### `misc`

| Command | Linux | macOS | Windows | Kind | Description |
|---|---|---|---|---|---|
| `gh` | `history \| grep` | `history \| grep` | `Get-History \| Out-String -Stream \| Select-String` | abbr | Search shell history for a pattern (session-scope only, on every shell) |
| `count` | `find . -type f \| wc -l` | `find . -type f \| wc -l` | `Get-ChildItem -Recurse -File \| Measure-Object \| Select-Object -ExpandProperty Count` | abbr | Count all files in the current directory tree |
| `makeme` | `sudo chown $USER:$USER` | `sudo chown $USER:$USER` | `Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command',"takeown /F `"$args`""` | abbr | Set file owner to the current user |
| `makeroot` | `sudo chown 0:0` | `sudo chown 0:0` | `Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command',"takeown /F `"$args`" /A"` | abbr | Set file owner to root (Windows — Administrators group) |
| `sha` | `shasum -a 256` | `shasum -a 256` | `Get-FileHash -Algorithm SHA256 -Path` | abbr | SHA-256 checksum shortcut |
| `ping` | `ping -c 5` | `ping -c 5` | `ping.exe -n 5` | alias | Ping with a bounded count of 5 |
| `ports` | `netstat -tulanp` | `lsof -iTCP -sTCP:LISTEN -n -P` | `Get-NetTCPConnection -State Listen` | abbr | Show all listening ports on this machine |
| `week` | `date +%V` | `date +%V` | `Get-Date -UFormat %V` | abbr | Print the current ISO week number |

### `nav`

| Command | Linux | macOS | Windows | Kind | Description |
|---|---|---|---|---|---|
| `..` | `cd ..` | `cd ..` | `Set-Location ..` | abbr | Go up one directory |
| `...` | `cd ../..` | `cd ../..` | `Set-Location ../..` | abbr | Go up two directories |
| `....` | `cd ../../..` | `cd ../../..` | `Set-Location ../../..` | abbr | Go up three directories |
| `.....` | `cd ../../../..` | `cd ../../../..` | `Set-Location ../../../..` | abbr | Go up four directories |
| `hh` | `cd ~` | `cd ~` | `Set-Location ~` | abbr | Go to home directory |
| `ee` | `cd /etc` | `cd /etc` | `Set-Location C:\Windows\System32\drivers\etc` | abbr | Go to /etc (Windows equivalent — hosts file, protocol/service definitions) |
| `-` | `cd -` | `cd -` | — | abbr | Go to previous directory |
<!-- GENERATED:aliases-doc-aliases:end -->

**Not yet migrated to the YAML model** (need per-shell native syntax, not a
plain command string — see `.chezmoidata/aliases/common/misc.yaml`'s own
comment): the old `sudo='sudo '` trailing-space trick and the `path` alias
(`${PATH//:/\n}`, bash-only parameter expansion). Currently **not
implemented in any shell** — dropped during migration, not yet rebuilt.

### Power management (`dot_bashrc.d/50-aliases-power.sh`, bash/zsh only — not yet in the YAML model)

For a non-root user the destructive commands are wrapped in `sudo`; as
root they run directly.

| Command | Expands to (non-root) | Description |
|---------|----------------------|-------------|
| `reboot` | `sudo /sbin/reboot` | Reboot |
| `poweroff` | `sudo /sbin/poweroff` | Power off |
| `halt` | `sudo /sbin/halt` | Halt |
| `shutdown` | `sudo /sbin/shutdown` | Shutdown |
| `shutdownnow` | `sudo /sbin/shutdown -h now` | Immediate shutdown |
| `root` | `sudo -i` | Root login shell |
| `reload` | `exec ${SHELL} -l` | Re-exec the shell as a login shell |

---

<!-- GENERATED:aliases-doc-env:start (see .chezmoitemplates/generate-aliases-doc-env; regenerate with `edit-aliases-core`, no args = regen-only mode — do not edit this block by hand) -->
## Common scope — environment variables (`.chezmoidata/env/common/`)

### `editor`

| Variable | Linux | macOS | Windows | Description |
|---|---|---|---|---|
| `EDITOR` | `nano` | `nano` | `nano` | Default editor |

### `less_colors`

| Variable | Linux | macOS | Windows | Description |
|---|---|---|---|---|
| `LESS_TERMCAP_mb` | `\e[01;31m` | `\e[01;31m` | — | Begin blinking |
| `LESS_TERMCAP_md` | `\e[01;38;5;74m` | `\e[01;38;5;74m` | — | Begin bold |
| `LESS_TERMCAP_me` | `\e[0m` | `\e[0m` | — | End mode |
| `LESS_TERMCAP_se` | `\e[0m` | `\e[0m` | — | End standout-mode |
| `LESS_TERMCAP_so` | `\e[38;5;246m` | `\e[38;5;246m` | — | Begin standout-mode - info box |
| `LESS_TERMCAP_ue` | `\e[0m` | `\e[0m` | — | End underline |
| `LESS_TERMCAP_us` | `\e[04;38;5;146m` | `\e[04;38;5;146m` | — | Begin underline |

### `locale`

| Variable | Linux | macOS | Windows | Description |
|---|---|---|---|---|
| `LANG` | `en_US.UTF-8` | `en_US.UTF-8` | `en_US.UTF-8` | Prefer US English and use UTF-8 |
| `LC_ALL` | `en_US.UTF-8` | `en_US.UTF-8` | `en_US.UTF-8` | Prefer US English and use UTF-8 |

### `pager`

| Variable | Linux | macOS | Windows | Description |
|---|---|---|---|---|
| `MANPAGER` | `less -X` | `less -X` | — | Don't clear the screen after quitting a manual page |

### `python`

| Variable | Linux | macOS | Windows | Description |
|---|---|---|---|---|
| `PYTHONIOENCODING` | `UTF-8` | `UTF-8` | `UTF-8` | Make Python use UTF-8 encoding for stdin/stdout/stderr |
<!-- GENERATED:aliases-doc-env:end -->

**Not yet migrated to the YAML model** (still bash/zsh-only, in
`dot_bashrc.d/01-bash-history.sh`, no fish equivalent since fish has its own
native history mechanism): `HISTSIZE`, `HISTFILESIZE`, `HISTCONTROL`,
`HISTIGNORE`.

---

## Shared interactive functions (`dot_bashrc.d/80-functions-common.sh`)

Sourced by both bash and zsh (see `CONCEPT_ROADMAP.md` §3.8.1 for the 3-tier
library model and why `export -f` — used by the old, now-removed functions
below — is broken in zsh).

| Function | Description |
|----------|-------------|
| `color <attr> <code>` | Emit an ANSI escape — e.g. `color 0 31` for dark red |

**Removed 2026-08-01** (unused, confirmed with the user during a joint
review): `zpfn_get_github_project_latest_release_download_link`,
`zpfn_get_github_project_latest_release_version_number`,
`zpfn_systemd_service_exists`, `zpfn_edit`. The GitHub-release lookup logic
survives as `github_release_asset_url()` in `.chezmoitemplates/scripts-library`
(build-time helper, for a future GitHub-release package-manager fallback —
not an interactive function anymore).

### Prompt (`99-prompt.sh` / `99-prompt.zsh`)

Native prompt, colorizes `user@host dir$` — red username for root, green
for a normal user (bash: `PS1` with `\[...\]`; zsh: `PROMPT` with `%{...%}`
— can't share syntax, but reuse the same `$FG_*` variables from
`00-colors.sh`). [Oh My Posh](https://ohmyposh.dev/) layers on top if
installed (`99-theme-init.zsh` / `dot_config/fish/conf.d/ohmyposh-init.fish`),
without replacing this baseline.

### Git shortcuts (`git-aliases`)

Moved here from `~/.bashrc.d/personal/` 2026-08-15 — plain git wrapper
aliases apply equally to work machines, nothing personal-specific about
them (`CONCEPT_ROADMAP.md` §3.6).

| Command | Expands to | Description |
|---------|-----------|-------------|
| `g` | `git` | Git |
| `gcm` | `git commit -m` | Commit with message |
| `gst` | `git status` | Status |
| `gam` | `git add -u` | Stage modified + deleted |
| `ga` | `git add` | Stage files |

### Chezmoi shortcuts (`chezmoi-aliases`)

Also moved here 2026-08-15, same reasoning. Used to also export
`CHZ_DEPLOYMENT_PROFILE="personal"` — dropped during the move (hardcoded to
`"personal"`, would've been actively wrong on a work machine, and was
already documented as a redundant leftover from before `.deployment.profile`
existed as real chezmoi template data).

| Command | Expands to | Description |
|---------|-----------|-------------|
| `ch` | `history -a && chezmoi` | chezmoi (history flushed first, since chezmoi may restart the shell) |
| `chd` | `history -a && chezmoi cd` | chezmoi source directory |

---

## Personal scope (`~/.bashrc.d/personal/`, bash only — not yet ported to zsh/fish)

Loaded only when the active profile is `personal`. Git/chezmoi shortcuts
moved out to the shared scope above 2026-08-15 (see `CONCEPT_ROADMAP.md`
§3.6) — what's left here hasn't been reviewed the same way yet, no personal
machine exists to validate against.

### Developer shortcuts (`dev-shortcuts`)

| Command | Expands to | Description |
|---------|-----------|-------------|
| `e` | `${EDITOR}` | Open `$EDITOR` |
| `ali` | `${EDITOR} ~/.bashrc.d/git-aliases` | Edit the git aliases file |

### Home paths (`home-paths`)

| Command | Expands to |
|---------|-----------|
| `loc` | `cd ~/.local` |
| `lb` | `cd ~/.local/bin` |
| `d` | `cd ~/devel` |
| `dl` | `cd ~/Downloads` |
| `dt` | `cd ~/Desktop` |
| `brc` | `cd ~/.bashrc.d` |

---

## WSL2 SSH agent (`wsl2_ssh_agent_support`, universal, runtime-gated)

No aliases. When running under WSL2 (`$WSL_DISTRO_NAME` set), relays the
Windows OpenSSH agent into the WSL session via `npiperelay.exe` + `socat`,
exporting `SSH_AUTH_SOCK`. Requires `npiperelay.exe` at
`C:/wsl/npiperelay/npiperelay.exe` and `socat` installed in WSL. No-ops
silently on native Linux/macOS.

## Zsh-only content (`~/.zshrc.d/`, not shared with bash/fish)

| File | Scope | Purpose |
|---|---|---|
| `10-path.zsh` | common | `PATH` additions |
| `10-bitwarden-ssh-agent.zsh` | common | macOS Bitwarden desktop SSH agent socket (`SSH_AUTH_SOCK`) |
| `work/10-gcloud.zsh` | work | Google Cloud SDK shell integration |
| `work/10-vertex-ai.zsh` | work | `CLAUDE_CODE_USE_VERTEX`/`CLOUD_ML_REGION`/`ANTHROPIC_VERTEX_PROJECT_ID` — makes Claude Code use this machine's corporate Vertex AI project |

---

## Work scope (`~/.bashrc.d/work/`, `~/.zshrc.d/work/`)

Bash side is an empty placeholder (`.gitkeep`) — no work-specific *aliases*
yet, only the zsh-only env vars above.
