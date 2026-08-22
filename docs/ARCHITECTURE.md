# Architecture

Design rationale behind this dotfiles repo — chezmoi + Age + EJSON, multi-OS
(macOS, Linux, Windows), multi-shell (bash, zsh, fish, PowerShell 7). This
document describes the **current, stable design** and the reasoning behind
it. It intentionally does not narrate how each piece was discovered, tested,
or debugged — that history lives in `git log` (commit messages in this repo
already explain "why", not just "what") and, while the rework is still
active, in `../CONCEPT_ROADMAP.md`.

See [`../README.md`](../README.md) for day-one usage, [`DAILY_WORKFLOW.md`](./DAILY_WORKFLOW.md)
for operator runbooks, [`ENCRYPTION_SETUP.md`](./ENCRYPTION_SETUP.md) for key
setup/rotation, and [`ALIASES.md`](./ALIASES.md) for the alias/function
reference.

## 1. Two independent identity/deployment axes, plus GUI presence

Three facts are resolved once per machine (at `chezmoi init` time, cached in
`~/.config/chezmoi/chezmoi.yaml`, never committed) and available in every
template as `.deployment.profile` / `.deployment.role` / `.deployment.has_gui`:

| Axis | Values | Meaning |
|---|---|---|
| `profile` | `personal` / `work` | Identity — separate Age/EJSON keys, separate secrets, separate git/SSH identity. Cryptographically isolated (a personal machine physically cannot decrypt work secrets). |
| `role` | `workstation` / `server` | **Purpose** of the machine: is this where a person interactively works/develops, or infrastructure that just runs (homelab VM, CI runner)? Orthogonal to `profile` — a server uses the same identity/keys as any other machine of that profile, `role` only changes package selection and behavior. |
| `has_gui` | `true` / `false` | **Technical fact**: does a display/desktop session actually exist? Nothing more. |

**`role` and `has_gui` are independent, not one derived from the other.**
Anchoring examples: a Windows Server with Desktop Experience installed is
`server` + `has_gui: true`; a typical Linux server is `server` +
`has_gui: false`; a headless dev box reached only via SSH/VS Code Remote is
`workstation` + `has_gui: false` — it's still an interactive development
machine, just without a physical display attached (the terminal font/glyphs
in that case belong on the *client* machine, not this headless box).

Aliases, environment variables, and the native shell prompt are always
relevant regardless of GUI (they work identically over SSH or in a GUI
terminal) — only genuinely GUI-dependent things (Ghostty, Bitwarden desktop,
Windows Terminal, GUI-only packages) are gated on `has_gui`. `role=server`
today deliberately receives almost no packages beyond `vm_guest_tools` — a
conscious minimalism, expanded only as real server use cases arrive, not a
gap.

## 2. Scope isolation (profile × OS × role)

`.chezmoiignore.tmpl` masks files so that only the active profile's/role's/
OS's variants ever reach disk on a given machine — physical absence, not
just a runtime condition. The encrypted blobs for the *other* profile travel
with the repo clone but can never be decrypted without the matching Age key.

The mechanism used to encode scope into the source tree depends on what the
target format actually needs:

| Mechanism | Used by | How scope is encoded |
|---|---|---|
| Directory tree | `dot_bashrc.d/{personal,work}/`, `dot_config/private_git/` | Subdirectory, masked in `.chezmoiignore.tmpl` by path |
| Filename | `private_dot_ssh/conf.d/` | Scope embedded in the filename (SSH's `Include` needs one flat directory) |
| `.chezmoidata/` YAML key | `.chezmoidata/aliases/`, `.chezmoidata/env/` | Scope is a YAML key, not the file path — see §7 |

Adding a new axis (or gating anything new on an existing one) follows the
same pattern — either add a masking condition to `.chezmoiignore.tmpl`, e.g.:

```gotmpl
{{ if eq .deployment.role "server" }}
.config/ghostty
{{ end }}
```

or gate a script's rendered *content* the same way, e.g.
`run_onchange_install-packages.sh.tmpl` branching on `.deployment.vm_type`.
There is only ever one mechanism (`.deployment.*` template data + `{{ if }}`
branches) — never a parallel, format-specific one.

## 3. Configuration composition

Two orthogonal concerns, easy to conflate:

**Include support.** If the target format has a native include mechanism
(git `[include]`, SSH `Include`, Ghostty `config-file = ?path`), chezmoi
just places/masks fragments and lets the tool compose them. If the format
has no native include (e.g. npmrc), composition happens at `chezmoi apply`
time via `.chezmoitemplates/` partials, one `.tmpl` calling
`{{ template "fragment-name" . }}` per common/profile/OS fragment.

**Precedence, once multiple fragments exist:**

| Format | Winner | Ordering |
|---|---|---|
| git | Last `[include]`/`[includeIf]` wins a conflicting key | File order: common → profile → profile+OS → `includeIf` host |
| SSH | **First** matching wins (except cumulative directives like `IdentityFile`) | Numeric filename prefix, lowest number first — most specific gets the lowest number |
| Ghostty | Last `config-file` wins (same direction as git) | Static file lists includes common → profile → profile+OS |

`known_hosts` is excluded from this pattern entirely — SSH manages it itself
at runtime; treating it as a seed/merged file would fight that.

## 4. Never-own-rc-files

`~/.bashrc`, `~/.zshrc`, `~/.ssh/config`, and `~/.gitconfig` are **never**
fully owned by chezmoi, even though each has (or can accumulate) important
content chezmoi didn't put there — SDK/tool init lines, `git lfs`/credential
manager edits, existing `Host` blocks. A static or templated full-file
replacement would silently destroy that content.

Instead, chezmoi owns a dedicated subdirectory (`~/.bashrc.d/`,
`~/.zshrc.d/`, `~/.ssh/conf.d/`, `~/.config/git/**/*.gitconfig`), and a
small, idempotent `run_after_ensure-*-sourcing.sh.tmpl` /
`run_after_ensure-gitconfig-includes.sh.tmpl` script appends one
`source`/`Include`/`[include]` block to the real file — only if not already
present, self-healing on every apply (e.g. if an OS reinstall resets
`~/.bashrc`). git needs this per-block rather than per-file (no
directory-glob include exists), so its script is idempotent per include
block, not just per file.

zsh has no OS-provided auto-sourcing convention at all (unlike Fedora's
default `~/.bashrc`, which already sources `~/.bashrc.d/*` top-level), so its
ensure-script always appends the block. `~/.zshrc.d/00-shared.zsh` sources an
explicit, curated subset of `~/.bashrc.d/*` that is byte-identical between
bash and zsh (colors, generated env/aliases) — never a blind glob, since
some files (prompt, `export -f`-based functions) are bash-only and would
break zsh at startup.

PowerShell's `$PROFILE` (specifically `CurrentUserCurrentHost`) follows the
identical pattern: user/OS-owned file, one idempotent dot-source block
appended by `run_after_ensure-powershell-profile-sourcing.ps1.tmpl`, pointing
at a fully chezmoi-owned `Documents/PowerShell/dotfiles.d/`.

## 5. Git configuration

```
dot_config/private_git/
  common.gitconfig
  {personal,work}/{common,linux,mac,windows}.gitconfig
  {personal,work}/hosts/{github,...}.gitconfig
```

Composed via `[include]` (common → profile → profile+OS, last wins on
conflict) plus per-host `[includeIf "hasconfig:remote.*.url:<pattern>"]`
(git ≥2.36) for host-specific overrides — e.g. a GitHub "keep my email
private" noreply address that differs per profile's GitHub account. Two
`includeIf` blocks are needed per host (SCP-style `git@host:*/**` and
`https://host/**`) since SCP-style URLs need `*/**`, not a bare `**`, to
match multi-segment paths after the colon. The fallback `[user]` block must
appear *before* any `includeIf` block in the file, or a later static block
would clobber what the conditional include set.

`~/.gitconfig` itself stays user/OS-owned (§4) — the include/includeIf
blocks are appended idempotently, one block at a time, by
`run_after_ensure-gitconfig-includes.sh.tmpl` (PowerShell:
`run_after_ensure-gitconfig-includes.ps1.tmpl`, same mechanism, git for
Windows tilde-expands `path =` the same way).

Per-profile `{personal,work}/common.gitconfig.tmpl` and
`hosts/github.gitconfig.tmpl` pull `user.name`/`user.email`/GitHub noreply
email from the profile's EJSON evault via `.chezmoitemplates/evault-field`
(the first real consumer of evault-secret-injection, §7) — this makes git
identity require an already-unlocked EJSON key at apply time; a missing key
fails the whole `chezmoi apply` loudly on these files rather than silently
rendering empty. To change identity values, use `edit-evault` — never edit
the rendered `~/.config/git/...` files directly.

## 6. SSH configuration

```
private_dot_ssh/conf.d/
  50-work-redhat.conf     # Host *.redhat.com — GSSAPI
  50-work-labvms.conf     # lab VM shortcuts
  90-common.conf          # most general, numbered last (fallback)
```

SSH's `Include` uses **first-match-wins** semantics (the opposite of git),
so more specific fragments need a *lower* numeric filename prefix to sort
first. Scope/OS is encoded in the filename, not a subdirectory, since
`Include *.conf` needs one flat directory (masked in `.chezmoiignore.tmpl`
by filename glob).

`~/.ssh/config` stays user/OS-owned (§4); the ensure-script appends
`Host *` immediately followed by `Include ~/.ssh/conf.d/*.conf` — the
`Host *` reset is required, not decorative: OpenSSH silently scopes an
`Include` to whatever `Host`/`Match` block precedes it in the file, so
without an unconditional reset first, any pre-existing `Host` block earlier
in the real config would suppress the included fragments for non-matching
hosts.

The common fragment sets `SetEnv TERM=xterm-256color` for every host — works
around Ghostty setting `TERM=xterm-ghostty`, which remote hosts without a
matching terminfo entry (typical minimal/homelab servers) choke on. This is
more robust than Ghostty's own `shell-integration-features=ssh-env,ssh-terminfo`,
which only helps for interactive `ssh` shell invocations, not cron/git/scp/
rsync/mosh.

**Windows**: `Include` is not usable at all in Win32-OpenSSH (any absolute
or tilde path hangs `ssh.exe` indefinitely; relative paths silently no-op) —
confirmed across both the in-box client and the latest upstream release, a
real, persistent Win32-OpenSSH bug rather than a version-specific issue.
`run_after_ensure-sshconfig-sourcing.ps1.tmpl` works around this by directly
embedding the fragment content into `$HOME\.ssh\config`, inside a managed
`# BEGIN/END dotfiles conf.d` block regenerated on every apply.

## 7. Alias & environment variable data model

Aliases and environment variables are each defined **once**, in YAML under
`.chezmoidata/{aliases,env}/`, then rendered per-shell at `chezmoi apply`
time into plain, non-templated shell files.

Files under `.chezmoidata/` merge into the template data root by filename
alphabetical order; **file location is purely for human organization** — the
scope and category are keys in the YAML content itself, not derived from the
path. Category names must be globally unique across the whole repo: a name
collision silently *overwrites* one category's list with another's
(alphabetically-later file wins), it does not merge.

```yaml
# scope and category are YAML keys — the file path is just organization
aliases:
  common:
    categories:
      ls:
        - name: ll
          command:
            default: "ls -l --color"
            darwin: "ls -l -G"
            windows: skip        # doesn't exist on this OS at all
          kind: abbr             # default; "alias" only for flag-only additions
          description: List all files and folders in long format
```

`command`/`value` is a plain string, or an OS-keyed map with a `default` and
per-OS overrides; `skip` means the entry doesn't exist on that OS at all
(distinct from an empty/false value). A shared `.chezmoitemplates/resolve-os-value`
partial implements this default+override+skip resolution once, called
identically by every per-shell renderer.

`kind: abbr` (fish default) expands visibly on space keypress — history
stores the expanded command, not an opaque shortcut, and destructive
commands are visible before pressing enter. `kind: alias` is reserved for
same-name flag additions with nothing to reveal (`grep --color=auto`,
`ping -c 5`).

**Renderers**, one per shell target, all reading the same `.chezmoidata`:

| Shell(s) | Renderer | Notes |
|---|---|---|
| bash + zsh | `dot_bashrc.d/{50-aliases,05-env}-generated.sh.tmpl` | `alias`/`export` syntax is byte-identical between bash and zsh, so they share one renderer/output file, not two |
| fish | `dot_config/fish/conf.d/{aliases,env}.fish.tmpl` | Fish autoloads `conf.d/*.fish` natively — no loader file needed |
| PowerShell 7 | `Documents/PowerShell/dotfiles.d/{50-aliases,05-env}-generated.ps1.tmpl` | Always `function name { command @args }`, never `Set-Alias` (which can't bind fixed arguments) |

A handful of PowerShell rendering rules exist because of real parser
constraints, not style preference: splatting `@args` is only valid
immediately after invoking an actual cmdlet/command — not after a bare
property access (`.Count`), a dot-source, or an `if/else` block — a syntax
error there breaks parsing of the *entire* generated file, not just one
function. Where `$args` has no natural place, a harmless trailing
`; $args | Out-Null` is appended to avoid the auto-append entirely. Pipeline
input isn't forwarded into a plain function automatically, so aliases like
`grep` that need it are marked `pipes_stdin: true` and get an explicit
`$input |` prefix. Function names shadow same-named external binaries in
PowerShell (unlike bash's one-level alias-expansion protection), so wrapping
`ping` requires calling `ping.exe` explicitly to avoid infinite recursion.

**Documentation generation.** `docs/ALIASES.md`'s alias/env tables are
generated directly from `.chezmoidata/{aliases,env}/**/*.yaml` between
`<!-- GENERATED:... -->` markers — everything outside those markers is
hand-maintained prose. Regenerate via `edit-aliases-core` (see
[`DAILY_WORKFLOW.md`](./DAILY_WORKFLOW.md) for the full add/edit workflow).

## 8. Shared function/script library — three layers

Real logic (loops, conditionals, argument parsing) doesn't fit the plain
command-string alias model above and is written once per shell instead,
organized into three layers by how it's consumed:

1. **Build/script layer** (`.chezmoitemplates/scripts-library`) — bash,
   strict `set -euo pipefail`. Inlined as text into every `run_*.tmpl`
   provisioning script and standalone `PATH` scripts (`edit-evault`-style)
   via `{{ template "scripts-library" }}` at `chezmoi apply` time — never
   sourced at runtime. Safe here because each consumer is a one-shot
   subprocess; a single failing command should abort the whole script.
2. **Interactive bash+zsh layer** (`dot_bashrc.d/80-functions-common.sh`) —
   sourced into a live interactive shell, so it must never use `set -e`.
   zsh shares this file via an explicit curated list in
   `dot_zshrc.d/00-shared.zsh` (not a blind glob) — `export -f` is broken in
   zsh, so functions here rely only on plain `function name { ... }`
   definitions, which behave identically in both shells.
3. **Fish-native layer** — no code sharing is possible; a fish equivalent of
   a shared function is a separate, hand-written `dot_config/fish/functions/*.fish`
   file with the same name/interface.

**Stateless vs. stateful functions**, a second, orthogonal split: a function
that only computes and prints output (doesn't need to `cd` or set an env var
that survives in the calling shell) can be one POSIX script in `PATH`
(`private_dot_local/bin/`), called identically from every shell. A function
that must mutate the calling shell's state (`cd`, `export`/`set -gx`) needs a
thin native wrapper per shell that calls the shared script for the heavy
logic and applies the result in its own context — the pattern already used
by `edit-aliases`/the WSL2 SSH-agent bridge.

## 9. Terminal, prompt, and editor

**Native prompt** (root=red, user=green) is a first-class, universally
deployed baseline — not something Oh My Posh replaces. It matters because a
local terminal's prompt engine has zero effect on a remote SSH session's
shell; only what's actually deployed on the remote machine controls its own
prompt. Implemented natively per shell (bash `PS1`, zsh `PROMPT`, fish
`fish_prompt`) since none share syntax, though bash/zsh do share the same
`$FG_*` color variables.

**Oh My Posh** layers on top wherever installed (zsh/fish/PowerShell, not
bash), initialized late enough in each rc file to override the native
`PROMPT`/`fish_prompt` — without removing the native fallback for shells or
machines where it isn't installed. The theme file
(`dot_config/oh-my-posh/atomic.omp.json`) is vendored directly in the repo
rather than referenced via a package-manager bundled theme path, since that
path differs across brew/dnf/winget.

**`sudo`/root and `$HOME`**: bare `sudo <shell>` behavior around `$HOME`
differs by platform — macOS preserves the caller's `$HOME`, but Fedora's
`Defaults always_set_home` resets it to `/root` even without `-i` (and
`sudo -E` does not override this). Once `$HOME` points at `/root`, root has
*no* deployed dotfiles at all (chezmoi only deploys for the invoking user).
The `root` alias uses bare `sudo $SHELL` (not `sudo -i`, which always resets
`$HOME` on every platform), and on Linux,
`run_after_ensure-root-environment-mirror.sh.tmpl` (not role-gated — applies
to `role=server` too) reads `$SUDO_USER` at runtime and live-sources that
user's real `~/.bashrc.d`/`~/.zshrc.d`/fish config, temporarily pointing
`$HOME` at the invoking user just long enough for tools like Oh My Posh to
resolve their config path correctly, then restoring `$HOME` to `/root`
afterward. This adds no new privilege — a sudoer could already run anything
from their own dotfiles as root manually; it just automates it.

**Ghostty** (macOS/Linux only, no Windows build) composes
`common.conf` → `{profile}/common.conf` → `{profile}/{os}.conf` via its
native `config-file = ?path` include (silent no-op on a missing fragment,
later overrides earlier — same direction as git). Deployed only when
`has_gui: true`. **Windows Terminal** plays the equivalent role on Windows,
via its native ["fragment extension"](https://learn.microsoft.com/windows/terminal/json-fragment-extensions)
mechanism — a purely additive profile (fixed GUID, never regenerated) rather
than touching the real MSIX-packaged, JSONC `settings.json` directly; setting
it as the default profile is deliberately out of scope (would require
parsing/rewriting that JSONC file safely).

**Editor** (nano/vim) config has no secrets and is fully shared across
profiles — no scope-split machinery needed.

## 10. Package/tool installation model

`.chezmoidata/packages.yaml` is **tool-first**: one list per tool, with
per-manager (`dnf`/`apt`/`brew`/`winget`) name overrides, rather than one
list per package manager. `dnf`/`apt`/`brew` default to the tool's own
`name` when omitted; `winget` always needs an explicit value (string ID or a
map for extra install flags) since there's no sensible default to derive.
`skip` means that manager doesn't have the tool at all — a tool with `skip`
everywhere except one manager is simply platform-exclusive, no separate
mechanism needed.

Per-tool filters:
- `roles: [...]` — installs only when `.deployment.role` is in the list;
  omitted defaults to both roles.
- `requires_gui: true` (default `false`) — independent filter on
  `.deployment.has_gui`.
- `vm_types: [...]` — installs only on the matching `.deployment.vm_type`
  (auto-detected, e.g. via `systemd-detect-virt` on Linux).
- `copr: <owner>/<repo>` (dnf only) — enables the COPR repo before install,
  for tools with no default Fedora package (e.g. Ghostty).

Installed via `run_onchange_install-packages.sh.tmpl` (dnf/apt/brew, bash) or
`run_onchange_install-packages.ps1.tmpl` (winget, PowerShell) — **a separate
script per OS family, not one script with an OS branch**: `.sh` has no
default interpreter registered on Windows at all (chezmoi's own default-
interpreter table only knows `.ps1`/`.py`/`.rb`/`.pl`/`.nu`), so every
`.chezmoiscripts/*.sh.tmpl` script's entire body — including the shebang —
is wrapped in `{{- if ne .chezmoi.os "windows" -}}...{{- end -}}`, rendering
to zero bytes (and being skipped by chezmoi) on Windows. The PowerShell
sibling carries the equivalent `eq .chezmoi.os "windows"` guard and shares
the same `resolve-package-entry`/`render-winget-install` template partials
against the identical `packages.yaml` data.

## 11. Windows-specific considerations

**Prefer user scope over machine scope wherever possible.** A `role: server`
deployment may target a Windows machine where the operator has no admin
rights at all — this is a standing principle for *any* future Windows work
(winget installs, registry writes, font installs), not just packages: always
try the per-user variant first (`--scope user`, `HKCU`, `%LOCALAPPDATA%`),
machine-scope only when a tool genuinely requires it, and then as a
consciously documented exception (e.g. `powershell7`, which needs a machine-
scope `wix` install to register as `DefaultShell`).

**Elevation cannot be assumed to work at all under SSH-driven automation.**
Native Windows `sudo.exe` (11 24H2+) still requires UAC consent on a "secure
desktop" — a real interactive/console or RDP session. A plain SSH exec
(password or key auth) runs outside the interactive window station, so UAC
has nowhere to prompt: `sudo` fails immediately and cleanly ("not allowed to
run sudo"), while the older `Start-Process -Verb RunAs` fails silently
(reports success, never actually launches). This is true even for an account
that is a local Administrator. No `run_once`/`run_onchange` script may
assume elevation is available; `makeme`/`makeroot` try native `sudo.exe`
first and fall back to the `RunAs` popup only on older Windows, but neither
path is assumed to succeed under non-interactive automation.

**SSH `Include` doesn't work; git config includes do.** See §5/§6 above —
git for Windows honors `$HOME` and tilde-expansion identically to Unix, so
its include mechanism needed no special-casing, while SSH's needed a
completely different embed-the-content-directly approach.

## 12. Test environment (UTM lab VMs)

Development and verification happen against local UTM VM clones, one
read-only template per OS (macOS, Linux/Fedora, Windows), never the
templates themselves. The working cycle: clone the template, bootstrap and
test on the clone, delete the clone once verified. `utmctl` (Homebrew)
scripts the whole clone/start/stop/delete cycle without the UTM GUI.

## 13. Deferred / explicitly out of scope

- **Fully automated/headless secret bootstrap for servers** (no human typing
  an Age passphrase over SSH) — a future direction would use a secret
  manager (e.g. Bitwarden headless CLI) to hand a server an already-unlocked
  key, since `age decrypt --passphrase` deliberately reads only from a
  controlling terminal and cannot be satisfied by piping input.
- **Editor config for a GUI/AI-assisted editor** (evaluated: Zed) — will
  likely need its own scope-split and secrets handling (API keys, differing
  company AI policy) once actually adopted; not designed preemptively.
- **PowerShell abbreviation-style expansion** (fish's `abbr` behavior) — the
  `kind` field in the alias schema is designed so this can be added later
  purely in the PowerShell renderer, with no data-model change.
- **SSH-key git commit signing** — deliberately deferred until explicitly
  requested.
- **`apt`/Debian-Ubuntu support and WSL2** — both are tracked as independent
  future work, out of scope for the current pass across macOS/Fedora/
  Windows.

## 14. Verifying a change end-to-end

For any change to this repo's mechanisms (not day-to-day alias/config edits
— see [`DAILY_WORKFLOW.md`](./DAILY_WORKFLOW.md) for those):

1. Clone the relevant OS's UTM lab template, boot it, SSH in.
2. Bootstrap per the top of [`../README.md`](../README.md); confirm
   `chezmoi apply` exits cleanly and `chezmoi apply --dry-run --verbose` is
   quiet afterward.
3. For aliases/env: open a fresh shell, confirm the expected
   aliases/abbreviations/env vars exist with the right OS-specific value.
4. For git/SSH: `git config --list --show-origin` shows values from the
   expected fragment; `ssh -G <host>` shows the expected effective resolved
   config.
5. For packages: confirm only the role/GUI/vm-type-relevant set installs.
6. Delete the test clone once verified.
