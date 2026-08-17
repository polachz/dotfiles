#!/usr/bin/env bash
# Shared interactive bash+zsh function library (layer 2 — see
# CONCEPT_ROADMAP.md §3.8.1). No `set -e`/`pipefail` here — this gets
# sourced into a live interactive shell, unlike .chezmoitemplates/scripts-library.

# ANSI color escape helper. Usage: color 0 31 (dark red)
##################
# Code # Color   #
##################
#  00  # Off     #
#  30  # Black   #
#  31  # Red     #
#  32  # Green   #
#  33  # Yellow  #
#  34  # Blue    #
#  35  # Magenta #
#  36  # Cyan    #
#  37  # White   #
##################
function color {
  echo "\033[$1;$2m"
}

# Create a directory (and any missing parents) and cd into it in one step.
function mkcd {
  mkdir -p -- "$1" && cd -- "$1"
}
