#!/usr/bin/env bash
# Shared interactive bash+zsh function library, layer 2 extras (see
# CONCEPT_ROADMAP.md §3.8.1 for the tier model — same rules as
# 80-functions-common.sh: no `set -e`/`pipefail`, sourced into a live
# interactive shell). Split into its own file rather than appended to
# 80-functions-common.sh since these are optional conveniences, not the
# original reviewed core set.

# Extract almost any archive based on its file extension. `tar xf` alone
# (no -z/-j/-J) auto-detects gzip/bzip2/xz compression on both bsdtar
# (macOS) and GNU tar (Linux) — verified live, no need to match the flag to
# the extension. `-k`/`--keep` on the single-file compressors so the
# original archive survives (verified present on macOS's gzip/bzip2 too,
# not just GNU).
function unpack {
  if [ -z "$1" ] || [ ! -f "$1" ]; then
    echo "unpack: '$1' is not a valid file" >&2
    return 1
  fi
  case "$1" in
    *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) tar xf "$1" ;;
    *.zip) unzip "$1" ;;
    *.rar) unrar x "$1" ;;
    *.7z)  7z x "$1" ;;
    *.gz)  gunzip -k "$1" ;;
    *.bz2) bunzip2 -k "$1" ;;
    *.xz)  unxz -k "$1" ;;
    *.Z)   uncompress "$1" ;;
    *)
      echo "unpack: don't know how to extract '$1'" >&2
      return 1
      ;;
  esac
}

# Copy a file/dir to a timestamped .bak sibling.
function backup {
  if [ -z "$1" ]; then
    echo "Usage: backup <path>" >&2
    return 1
  fi
  cp -r "$1" "$1.bak-$(date +%Y%m%d-%H%M%S)"
}

# Serve the current directory over plain HTTP. Relies on python3 being on
# PATH — not a tracked package in this repo (deliberately, see
# CONCEPT_ROADMAP.md §7), so fail with a clear message rather than a cryptic
# "command not found" three lines down.
function serve {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "serve: python3 not found on PATH" >&2
    return 1
  fi
  python3 -m http.server "${1:-8000}"
}

# Quick weather report via wttr.in. Empty arg = auto-detect location by IP.
function weather {
  curl -s "wttr.in/${1}"
}

# git clone then cd into the resulting directory.
function gclone {
  if [ -z "$1" ]; then
    echo "Usage: gclone <url>" >&2
    return 1
  fi
  local dir
  dir=$(basename "$1" .git)
  git clone "$1" && cd "$dir"
}

# Print $PATH one entry per line. Named `pathlist`, not `path` — fish 3.6+
# has a builtin `path` command (path manipulation), a plain function named
# `path` would shadow it there; kept the same name across all shells rather
# than diverging just for this one.
function pathlist {
  echo "$PATH" | tr ':' '\n'
}

# cd up N directories (default 1) — complements the fixed-depth `..`/
# `...`/`....`/`.....` nav aliases with an arbitrary depth.
function up {
  local n="${1:-1}" path="" i
  for ((i = 0; i < n; i++)); do
    path="../$path"
  done
  cd "$path" || return
}

# Find and kill whatever process is listening on a TCP port. Genuine
# macOS/Linux tool split, not just a flag difference — verified live that
# macOS's fuser is the POSIX file/mount-point variant (no network-port
# awareness at all), NOT Linux psmisc's `fuser <port>/tcp`, so this can't be
# one shared command like the `ports` alias's lsof/netstat split.
function killport {
  if [ -z "$1" ]; then
    echo "Usage: killport <port>" >&2
    return 1
  fi
  if [ "$(uname)" = "Darwin" ]; then
    local pid
    pid=$(lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null)
    if [ -z "$pid" ]; then
      echo "killport: nothing listening on port $1" >&2
      return 1
    fi
    echo "$pid" | xargs kill -9
    echo "killport: killed PID(s) $pid on port $1"
  else
    fuser -k "$1"/tcp
  fi
}

# Pretty-print JSON via jq (workstation-only package, see packages.yaml —
# deliberately not python3's json.tool, an untracked/unguaranteed
# dependency). Works both piped (`cmd | json`) and with a file argument
# (`json file.json`) — jq itself falls back to stdin when given zero file
# args, no branching needed here.
function json {
  if ! command -v jq >/dev/null 2>&1; then
    echo "json: jq not installed (jq is a workstation-only package, see packages.yaml)" >&2
    return 1
  fi
  jq . "$@"
}

# Delete local git branches already merged into the repo's default branch.
# Detects the default branch from origin's HEAD; falls back to `main` if
# there's no origin (or it's not set up) — either way `main`/`master` and
# the current branch are always excluded as an extra safety net, not just
# whatever the default-branch detection happens to return.
function gclean {
  local default_branch
  default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [ -z "$default_branch" ]; then
    default_branch="main"
  fi
  git branch --merged "$default_branch" | grep -v "^\*" | grep -vE "^[[:space:]]*(${default_branch}|main|master)\$" | while read -r branch; do
    git branch -d "$branch"
  done
}

# Quick cheatsheet lookup via cheat.sh.
function cheat {
  curl -s "cheat.sh/$1"
}
