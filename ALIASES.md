# Aliases & Functions Reference

Every alias and function deployed to a workstation by these dotfiles,
grouped by theme. The source files live in `dot_bashrc.d/` and land in
`~/.bashrc.d/` after `chezmoi apply`.

Three scopes load in order (see `dot_bashrc.d/00-loader.sh`):

| Scope | Directory | Loaded on |
|-------|-----------|-----------|
| Shared | `~/.bashrc.d/shared/` | every profile |
| Personal | `~/.bashrc.d/personal/` | `profile = personal` only |
| Top-level | `~/.bashrc.d/*` (flat files) | every profile |

> **Shared vs. homelab VMs.** The `shared/` scope is vendored into the
> homelab automation repo and also deployed to homelab VMs. VMs get an
> *additional* server-only set (systemd / podman / network helpers) that
> is **not** part of these dotfiles — see
> `homelab-automation/docs/user-guide/customization/aliases-reference.md`.

---

## Shared scope (`~/.bashrc.d/shared/`)

Universal — present on every machine and every homelab VM.

### Colors (`00-colors.sh`)

Defines ANSI escape variables for use by the prompt and any function that
wants colored output. No aliases — just variables.

- Foreground: `FG_BLACK`, `FG_RED`, `FG_GREEN`, `FG_YELLOW`, `FG_BLUE`,
  `FG_PURPLE`, `FG_CYAN`, `FG_LIGHTGRAY`, `FG_DARKGRAY`, and the bright
  `FG_L*` variants (`FG_LRED`, `FG_LGREEN`, …), plus `FG_WHITE` and
  `FG_NO_COLOR`.
- Background: the matching `BG_*` set (`BG_BLACK` … `BG_WHITE`), plus
  `BK_NO_COLOR`.

### Navigation (`50-aliases-nav.sh`)

| Command | Expands to | Description |
|---------|-----------|-------------|
| `..` | `cd ..` | Up one directory |
| `...` | `cd ../..` | Up two |
| `....` | `cd ../../..` | Up three |
| `.....` | `cd ../../../..` | Up four |
| `hh` | `cd ~` | Home directory |
| `ee` | `cd /etc` | `/etc` |
| `-` | `cd -` | Previous directory |

### ls variants (`50-aliases-ls.sh`)

Color flag is auto-detected (`--color` on GNU, `-G` on macOS).

| Command | Expands to | Description |
|---------|-----------|-------------|
| `ll` | `ls -l` | Long format |
| `la` | `ls -A` | Include hidden |
| `lla` | `ls -Al` | Long + hidden |
| `ld` | `ls -d */` | Directories only |
| `lld` | `ls -ld */` | Directories only, long |
| `lh` | `ls -ld .[^.]* ..?*` | Hidden entries only |
| `llh` | `ls -ld .[^.]* ..?*` | Hidden entries only, long |
| `lt` | `ls --size -1 -S --classify -h` | Sorted by size, classified |
| `lm` | `ls -t -1` | Sorted by modification time |

Colored grep is also set here:

| Command | Expands to |
|---------|-----------|
| `grep` | `grep --color=auto` |
| `fgrep` | `fgrep --color=auto` |
| `egrep` | `egrep --color=auto` |

### Miscellaneous (`50-aliases-misc.sh`)

| Command | Expands to | Description |
|---------|-----------|-------------|
| `gh` | `history \| grep` | Search shell history |
| `count` | `find . -type f \| wc -l` | Count files in tree |
| `makeme` | `sudo chown $USER:$USER` | Take ownership of a file |
| `makeroot` | `sudo chown 0:0` | Give a file to root |
| `sha` | `shasum -a 256` | SHA-256 a file |
| `ping` | `ping -c 5` | Ping 5× then stop (Windows-like) |
| `ports` | `netstat -tulanp` | All listening ports |
| `week` | `date +%V` | ISO week number |
| `sudo` | `sudo ` | Trailing space so the *next* word is alias-expanded |
| `path` | `echo -e ${PATH//:/\\n}` | One `PATH` entry per line |

### Power management (`50-aliases-power.sh`)

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

### Common functions (`80-functions-common.sh`)

All except `zpfn_edit` are `export -f`'d so subshells inherit them.

| Function | Description |
|----------|-------------|
| `zpfn_get_github_project_latest_release_download_link <user/repo> <pattern>` | Download URL of the latest GitHub release asset matching `<pattern>`. Result also stored in `$zpfn_ret_github_download_url`. |
| `zpfn_get_github_project_latest_release_version_number <user/repo> <pattern>` | Version number (tag) of the latest GitHub release. Result also stored in `$zpfn_ret_github_project_version_number`. |
| `zpfn_systemd_service_exists <name>` | Return 0 if `<name>.service` exists, 1 otherwise. |
| `color <attr> <code>` | Emit an ANSI escape — e.g. `color 0 31` for dark red. |
| `zpfn_edit <args…>` | Open `$EDITOR` with the given arguments. |

### Prompt (`99-prompt.sh`)

Sets `PS1`. No aliases — colorizes `user@host dir$`, red username for
root and green for a normal user (uses the `FG_*` variables from
`00-colors.sh`).

---

## Personal scope (`~/.bashrc.d/personal/`)

Loaded only when the active profile is `personal`.

### Git (`git-aliases`)

| Command | Expands to | Description |
|---------|-----------|-------------|
| `g` | `git` | Git |
| `gcm` | `git commit -m` | Commit with message |
| `gst` | `git status` | Status |
| `gam` | `git add -u` | Stage modified + deleted |
| `ga` | `git add` | Stage files |

### Chezmoi (`chezmoi-aliases`)

Also exports `CHZ_DEPLOYMENT_PROFILE="personal"` so scripts can detect
which dotfiles set they are running under.

| Command | Expands to | Description |
|---------|-----------|-------------|
| `ch` | `history -a && chezmoi` | chezmoi (history flushed first, since chezmoi may restart the shell) |
| `chd` | `history -a && chezmoi cd` | chezmoi source directory |

### Developer shortcuts (`dev-shortcuts`)

| Command | Expands to | Description |
|---------|-----------|-------------|
| `e` | `zpfn_edit` | Open `$EDITOR` |
| `ali` | `zpfn_edit ~/.bashrc.d/personal/git-aliases` | Edit the git aliases file |

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

## Top-level scope (`~/.bashrc.d/`)

Flat files loaded on every profile.

### Environment (`exports`)

Not aliases — environment variables.

| Variable | Value | Purpose |
|----------|-------|---------|
| `EDITOR` | `nano` | Default editor (used by `e`, `ali`, `zpfn_edit`) |
| `PYTHONIOENCODING` | `UTF-8` | Force UTF-8 Python I/O |
| `HISTSIZE` / `HISTFILESIZE` | `5000` | Larger shell history |
| `HISTCONTROL` | `ignoreboth` | Drop duplicates + space-prefixed commands |
| `HISTIGNORE` | `ls:cd:cd -:pwd:exit` | Never record these |
| `LANG` / `LC_ALL` | `en_US.UTF-8` | US English, UTF-8 |
| `MANPAGER` | `less -X` | Don't clear screen after a man page |
| `LESS_TERMCAP_*` | (colors) | Colorized man pages |

### WSL2 SSH agent (`wsl2_ssh_agent_support`)

No aliases. When running under WSL2 (`$WSL_DISTRO_NAME` set), relays the
Windows OpenSSH agent into the WSL session via `npiperelay.exe` + `socat`,
exporting `SSH_AUTH_SOCK`. Requires `npiperelay.exe` at
`C:/wsl/npiperelay/npiperelay.exe` and `socat` installed in WSL.

---

## Work scope (`~/.bashrc.d/work/`)

Loaded only when the active profile is `work`. Currently empty (slot
reserved for future work-specific aliases).
