# Aliases, environment variables & functions reference

**Partially auto-generated** (`CONCEPT_ROADMAP.md` §3.4). The blocks between
`<!-- GENERATED:... -->` markers are generated straight from
`.chezmoidata/aliases/` and `.chezmoidata/env/` — regenerate with
`edit-aliases-core` (no args = regen-only mode; give it a YAML file path to
edit + validate + regenerate in one step). Never edit inside those markers by
hand, it's overwritten verbatim on every regeneration. Everything outside the
markers (prose, non-YAML-sourced sections like the personal/zsh-only scopes)
is still hand-maintained.

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

### `git`

| Command | Linux | macOS | Windows | Kind | Description |
|---|---|---|---|---|---|
| `g` | `git` | `git` | `git` | abbr | Git |
| `gcm` | `git commit -m` | `git commit -m` | `git commit -m` | abbr | Commit with message |
| `gcam` | `git commit -am` | `git commit -am` | `git commit -am` | abbr | Commit all tracked changes with message (does not stage new untracked files, unlike git add .) |
| `gp` | `git push` | `git push` | `git push` | abbr | Push |
| `gst` | `git status` | `git status` | `git status` | abbr | Status |
| `gam` | `git add -u` | `git add -u` | `git add -u` | abbr | Stage modified + deleted files |
| `ga` | `git add` | `git add` | `git add` | abbr | Stage files |

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
| `makeme` | `sudo chown $USER:$USER` | `sudo chown $USER:$USER` | `if (Get-Command sudo -ErrorAction SilentlyContinue) { sudo.exe takeown /F "$args" } else { Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command',"takeown /F `"$args`"" }` | abbr | Set file owner to the current user |
| `makeroot` | `sudo chown 0:0` | `sudo chown 0:0` | `if (Get-Command sudo -ErrorAction SilentlyContinue) { sudo.exe takeown /F "$args" /A } else { Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-Command',"takeown /F `"$args`" /A" }` | abbr | Set file owner to root (Windows — Administrators group) |
| `sha` | `shasum -a 256` | `shasum -a 256` | `Get-FileHash -Algorithm SHA256 -Path` | abbr | SHA-256 checksum shortcut |
| `ping` | `ping -c 5` | `ping -c 5` | `ping.exe -n 5` | alias | Ping with a bounded count of 5 |
| `ports` | `netstat -tulanp` | `lsof -iTCP -sTCP:LISTEN -n -P` | `Get-NetTCPConnection -State Listen` | abbr | Show all listening ports on this machine |
| `week` | `date +%V` | `date +%V` | `Get-Date -UFormat %V` | abbr | Print the current ISO week number |
| `e` | `$EDITOR` | `$EDITOR` | `& $env:EDITOR` | abbr | Open $EDITOR |
| `ali` | `edit-aliases-core aliases/common/git.yaml` | `edit-aliases-core aliases/common/git.yaml` | — | abbr | Edit git aliases (dev repo copy, validated + regenerates ALIASES.md) |
| `myip` | `curl -s https://ifconfig.me` | `curl -s https://ifconfig.me` | `curl.exe -s https://ifconfig.me` | abbr | Show this machine's public IP address |

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
| `d` | `cd ~/Devel` | `cd ~/Devel` | `Set-Location C:\Sources` | abbr | Go to the source-code working directory |
| `dl` | `cd ~/Downloads` | `cd ~/Downloads` | `Set-Location ~/Downloads` | abbr | Go to the Downloads directory |
| `dt` | `cd ~/Desktop` | `cd ~/Desktop` | `Set-Location ~/Desktop` | abbr | Go to the Desktop directory |
| `loc` | `cd ~/.local` | `cd ~/.local` | — | abbr | Go to the user-local data directory |
| `lb` | `cd ~/.local/bin` | `cd ~/.local/bin` | — | abbr | Go to the user-local binaries directory |

### `power`

| Command | Linux | macOS | Windows | Kind | Description |
|---|---|---|---|---|---|
| `reboot` | `sudo /sbin/reboot` | `sudo /sbin/reboot` | `Restart-Computer -Force` | abbr | Reboot the machine |
| `poweroff` | `sudo /sbin/poweroff` | `sudo /sbin/shutdown -h now` | `Stop-Computer -Force` | abbr | Power off the machine |
| `halt` | `sudo /sbin/halt` | `sudo /sbin/halt` | `Stop-Computer -Force` | abbr | Halt the machine |
| `shutdown` | `sudo /sbin/shutdown` | `sudo /sbin/shutdown` | — | abbr | Shut down the machine (flexible/scheduled form) |
| `shutdownnow` | `sudo /sbin/shutdown -h now` | `sudo /sbin/shutdown -h now` | `Stop-Computer -Force` | abbr | Shut down the machine immediately |
| `root` | `sudo -i` | `sudo -i` | `if (Get-Command sudo -ErrorAction SilentlyContinue) { sudo pwsh } else { Start-Process pwsh -Verb RunAs }; $args \| Out-Null` | abbr | Start a root/elevated shell |
| `reload` | `exec $SHELL -l` | `exec $SHELL -l` | `. $PROFILE; $args \| Out-Null` | abbr | Reload the shell (re-exec as a login shell; PowerShell re-sources $PROFILE instead) |
<!-- GENERATED:aliases-doc-aliases:end -->

**Not yet migrated to the YAML model** (need per-shell native syntax, not a
plain command string — see `.chezmoidata/aliases/common/misc.yaml`'s own
comment): the old `sudo='sudo '` trailing-space trick and the `path` alias
(`${PATH//:/\n}`, bash-only parameter expansion). Currently **not
implemented in any shell** — dropped during migration, not yet rebuilt.

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
below — is broken in zsh). `mkcd` is also implemented separately for fish
(`dot_config/fish/functions/mkcd.fish`) and PowerShell
(`Documents/PowerShell/dotfiles.d/80-functions.ps1`) — a multi-step function
like this doesn't fit the plain-command-substitution alias YAML model, so
it's hand-written once per shell instead.

| Function | Description |
|----------|-------------|
| `color <attr> <code>` | Emit an ANSI escape — e.g. `color 0 31` for dark red |
| `mkcd <path>` | Create a directory (and missing parents) and `cd` into it in one step |

**Removed 2026-08-01** (unused, confirmed with the user during a joint
review): `zpfn_get_github_project_latest_release_download_link`,
`zpfn_get_github_project_latest_release_version_number`,
`zpfn_systemd_service_exists`, `zpfn_edit`. The GitHub-release lookup logic
survives as `github_release_asset_url()` in `.chezmoitemplates/scripts-library`
(build-time helper, for a future GitHub-release package-manager fallback —
not an interactive function anymore).

### Extra convenience functions (`dot_bashrc.d/85-functions-extra.sh`)

Added 2026-08-18. Same reasoning as `mkcd` — real logic (loops, case/switch,
argument parsing), doesn't fit the plain-command-substitution alias model,
so each is hand-written once per shell: bash/zsh share
`dot_bashrc.d/85-functions-extra.sh`, fish gets one file per function under
`dot_config/fish/functions/`, PowerShell versions live in
`Documents/PowerShell/dotfiles.d/80-functions.ps1`. All live-verified
(macOS locally; PowerShell on a disposable `WinLab Template` clone).

| Function | Description | Notes |
|----------|-------------|-------|
| `unpack <archive>` | Extract almost any archive based on its extension (`.tar`/`.tar.gz`/`.tgz`/`.tar.bz2`/`.zip`/`.rar`/`.7z`/`.gz`/`.bz2`/`.xz`/`.Z`) | Named `unpack`, not `extract` (user's preference) or `unzip`/`untar` (real tool names). `tar xf` alone auto-detects compression on bsdtar/GNU tar/Windows' bundled tar.exe — no per-extension flag needed. `.zip` on Windows uses `Expand-Archive`; `.7z`/`.rar` need those tools present, same as Unix. |
| `backup <path>` | Copy a file/dir to a timestamped `<path>.bak-<timestamp>` sibling | |
| `serve [port]` | Serve the current directory over HTTP via `python3 -m http.server` (default port 8000) | Relies on `python3`/`python` being on PATH — not a tracked dependency in this repo, fails with a clear message if missing rather than a cryptic error. |
| `weather [location]` | Quick weather report via `curl wttr.in/<location>` | Empty arg = auto-detect location by IP. |
| `myip` | Show this machine's public IP address | Plain alias (`.chezmoidata/aliases/common/misc.yaml`), not a function — no arguments needed. |
| `gclone <url>` | `git clone` then `cd` into the resulting directory | |
| `pathlist` | Print `$PATH` one entry per line | Named `pathlist`, not `path` — fish 3.6+ has a builtin `path` command (path manipulation) that a function of that name would shadow. |
| `up [N]` | `cd` up N directories (default 1) | Complements the fixed-depth `..`/`...`/`....`/`.....` nav aliases with an arbitrary depth. |
| `killport <port>` | Find and kill whatever process is listening on a TCP port | Genuine macOS/Linux tool split (not just a flag difference): macOS's `fuser` is the POSIX file/mount-point variant with no network-port awareness at all (verified live) — macOS uses `lsof`, Linux uses `fuser -k <port>/tcp`. Windows uses `Get-NetTCPConnection`/`Stop-Process`. |
| `json [file]` | Pretty-print JSON, piped or from a file argument | Unix via `jq` (new workstation-only package, see `packages.yaml` — deliberately not server, and not `python3 -m json.tool`, an untracked dependency). Windows needs no extra tool — native `ConvertFrom-Json`/`ConvertTo-Json`. |
| `gclean` | Delete local git branches already merged into the repo's default branch | Detects the default branch from `origin/HEAD`, falls back to `main`; the current branch and `main`/`master` are always excluded as an extra safety net regardless of what detection returns. |
| `cheat <topic>` | Quick cheatsheet lookup via `curl cheat.sh/<topic>` | |

Deliberately **not yet implemented**: a random string/password generator —
user has an existing implementation in another project to port the exact
format/syntax from first, tracked as a follow-up, not started.

### Prompt (`99-prompt.sh` / `99-prompt.zsh` / `functions/fish_prompt.fish`)

Native prompt, colorizes `user@host dir$` — red username for root, green
for a normal user (bash: `PS1` with `\[...\]`; zsh: `PROMPT` with `%{...%}`;
fish: `set_color --bold <name>` — none share syntax, but bash/zsh reuse the
same `$FG_*` variables from `00-colors.sh`, and fish's `set_color --bold`
emits the identical two SGR parameters just in a different order, verified
byte-for-byte). [Oh My Posh](https://ohmyposh.dev/) layers on top if
installed (`99-theme-init.zsh` / `dot_config/fish/conf.d/ohmyposh-init.fish`
/ `Documents/PowerShell/dotfiles.d/99-ohmyposh-init.ps1`), without replacing
this baseline — fish's `fish_prompt.fish` is autoloaded lazily by fish
itself, only if Oh My Posh hasn't already defined `fish_prompt` at shell
startup, so it's a true fallback, added 2026-08-18 (previously fish had no
native fallback at all). Root-vs-user recoloring re-verified live against
Oh My Posh itself (not just the classic prompt) on both zsh and fish
2026-08-18 — correctly re-evaluates every prompt via Oh My Posh's own
per-render hook, no shell restart needed, no regression from the earlier
Starship-based behavior.

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

**Ported to fish and PowerShell (2026-08-18)** — same `ch`/`chd` shortcuts,
found missing there during a cross-shell alias audit (same class of gap the
git aliases had before). Not YAML-migrated: the `history -a` idiom above is
bash/zsh-specific (works around history being lost on a chezmoi-triggered
shell restart) and doesn't apply to fish (writes history live, nothing to
flush) or PowerShell — so each shell gets its own trivial hand-written
version instead of forcing a shared command string through the alias model.
See `dot_config/fish/conf.d/chezmoi-aliases.fish` and
`Documents/PowerShell/dotfiles.d/80-functions.ps1`.

---

## Personal scope (`~/.bashrc.d/personal/`)

Now an empty placeholder (`.gitkeep`, mirrors `work/`) — the former
`dev-shortcuts` (`e`, `ali`) and `home-paths` (`loc`, `lb`, `d`, `dl`, `dt`)
content moved to the common `nav`/`misc` tables above 2026-08-18 (none of it
was actually personal-identity-specific — same reasoning as the git aliases'
own earlier migration), gaining fish/PowerShell parity in the process. `brc`
did NOT move there — see below, it needs a different value per shell, which
the OS-keyed alias model can't express.

### Config directory shortcut (`brc`)

Same alias name in every shell, but the target is each shell's own fragment
directory — not expressible in the common OS-keyed alias model (that varies
by OS, not by shell), so it's four small hand-written files instead:

| Shell | File | Target |
|---|---|---|
| bash | `dot_bashrc.d/config-dir-shortcut` | `~/.bashrc.d` |
| zsh | `dot_zshrc.d/05-config-dir-shortcut.zsh` | `~/.zshrc.d` |
| fish | `dot_config/fish/conf.d/config-dir-shortcut.fish` | `~/.config/fish` |
| PowerShell | `Documents/PowerShell/dotfiles.d/80-functions.ps1` | `Documents/PowerShell/dotfiles.d` |

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
