#!/usr/bin/env bash
# Profile subdir loader.
#
# Fedora's default ~/.bashrc sources top-level files in ~/.bashrc.d/ but does
# NOT recurse into subdirectories. Universal files (colors, aliases, prompt,
# exports, …) live at the top level and load via that default mechanism. This
# script (named 00-* so it loads early) sources files from any profile subdir
# that is present — currently personal/ or work/, but any new subdir is picked
# up automatically.
#
# Profile selection: chezmoi's .chezmoiignore.tmpl ensures only the active
# profile's subdir reaches disk on a given machine.

for _zpfn_dir in "$HOME/.bashrc.d/"*/; do
    [ -d "${_zpfn_dir}" ] || continue
    for _zpfn_f in "${_zpfn_dir}"*; do
        [ -f "${_zpfn_f}" ] && [ -r "${_zpfn_f}" ] && . "${_zpfn_f}"
    done
done

unset _zpfn_dir _zpfn_f
