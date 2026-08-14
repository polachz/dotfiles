# Aliases, environment variables & functions reference

**Not yet auto-generated** (`CONCEPT_ROADMAP.md` §3.4 plans to generate this
file from `.chezmoidata/{aliases,env}/**/*.yaml` directly — not built yet).
This is a hand-maintained snapshot; if it drifts from the YAML, the YAML is
the source of truth.

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

## Common scope — aliases (`.chezmoidata/aliases/common/`)

Present on every profile/OS (an entry's `command` can still vary by OS — see
the `darwin`/`windows` columns below where relevant).

### Navigation (`nav.yaml`)

| Command | Expands to | Description |
|---------|-----------|-------------|
| `..` | `cd ..` | Up one directory |
| `...` | `cd ../..` | Up two |
| `....` | `cd ../../..` | Up three |
| `.....` | `cd ../../../..` | Up four |
| `hh` | `cd ~` | Home directory |
| `ee` | `cd /etc` | `/etc` |
| `-` | `cd -` | Previous directory |

### ls variants (`ls.yaml`)

| Command | Linux | macOS | Windows | Description |
|---------|-------|-------|---------|-------------|
| `ll` | `ls -l --color` | `ls -l -G` | skipped | Long format |
| `la` | `ls -A --color` | `ls -A -G` | skipped | Include hidden |
| `lla` | `ls -Al --color` | `ls -Al -G` | skipped | Long + hidden |
| `ld` | `ls -d --color */` | `ls -d -G */` | skipped | Directories only |
| `lld` | `ls -ld --color */` | `ls -ld -G */` | skipped | Directories only, long |
| `lh` | `ls -ld --color .[^.]* ..?*` | `ls -ld -G .[^.]* ..?*` | skipped | Hidden entries only |
| `llh` | same as `lh`, long | same, long | skipped | Hidden entries only, long |
| `lt` | `ls --human-readable --size -1 -S --classify` (all OSes) | | | Sorted by size, classified |
| `lm` | `ls -t -1 --color` | `ls -t -1 -G` | skipped | Sorted by modification time |

Colored grep — **`kind: alias`** (not `abbr`), since there's nothing to
reveal, just added flags:

| Command | Expands to |
|---------|-----------|
| `grep` | `grep --color=auto` |
| `fgrep` | `fgrep --color=auto` |
| `egrep` | `egrep --color=auto` |

### Miscellaneous (`misc.yaml`)

| Command | Linux | macOS | Description |
|---------|-------|-------|-------------|
| `gh` | `history \| grep` | same | Search shell history |
| `count` | `find . -type f \| wc -l` | same | Count files in tree |
| `makeme` | `sudo chown $USER:$USER` | same | Take ownership of a file |
| `makeroot` | `sudo chown 0:0` | same | Give a file to root |
| `sha` | `shasum -a 256` | same | SHA-256 a file |
| `ping` (`kind: alias`) | `ping -c 5` | same | Ping 5× then stop (Windows-like) |
| `ports` | `netstat -tulanp` | `lsof -iTCP -sTCP:LISTEN -n -P` (Windows: skipped) | All listening ports |
| `week` | `date +%V` | same | ISO week number |

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

## Common scope — environment variables (`.chezmoidata/env/common/`)

| Variable | Value | Purpose |
|----------|-------|---------|
| `EDITOR` | `nano` | Default editor |
| `LANG` / `LC_ALL` | `en_US.UTF-8` | US English, UTF-8 |
| `PYTHONIOENCODING` | `UTF-8` | Force UTF-8 Python I/O |
| `MANPAGER` | `less -X` | Don't clear screen after a man page |
| `LESS_TERMCAP_*` | (ANSI colors) | Colorized man pages |

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
`00-colors.sh`). [starship](https://starship.rs/) layers on top if
installed (`99-starship-init.zsh` / `dot_config/fish/conf.d/starship-init.fish`),
without replacing this baseline.

---

## Personal scope (`~/.bashrc.d/personal/`, bash only — not yet ported to zsh/fish)

Loaded only when the active profile is `personal`. Not yet reviewed for
whether this content should move to `common/` (per `CONCEPT_ROADMAP.md`
§3.6, most of it isn't actually personal-specific) — no personal machine
exists yet to validate against, so left as-is.

### Git (`git-aliases`)

| Command | Expands to | Description |
|---------|-----------|-------------|
| `g` | `git` | Git |
| `gcm` | `git commit -m` | Commit with message |
| `gst` | `git status` | Status |
| `gam` | `git add -u` | Stage modified + deleted |
| `ga` | `git add` | Stage files |

### Chezmoi (`chezmoi-aliases`)

Also exports `CHZ_DEPLOYMENT_PROFILE="personal"` (a bash-only, hardcoded
leftover from before `.deployment.profile` existed as chezmoi template
data — redundant but harmless).

| Command | Expands to | Description |
|---------|-----------|-------------|
| `ch` | `history -a && chezmoi` | chezmoi (history flushed first, since chezmoi may restart the shell) |
| `chd` | `history -a && chezmoi cd` | chezmoi source directory |

### Developer shortcuts (`dev-shortcuts`)

| Command | Expands to | Description |
|---------|-----------|-------------|
| `e` | `${EDITOR}` | Open `$EDITOR` |
| `ali` | `${EDITOR} ~/.bashrc.d/personal/git-aliases` | Edit the git aliases file |

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
