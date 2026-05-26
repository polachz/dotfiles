#!/usr/bin/env bash
# Nested subdir loader.
#
# Fedora's default ~/.bashrc sources top-level files in ~/.bashrc.d/ but
# does NOT recurse into subdirectories. This script (named 00-* so it
# loads first) sources files from shared/ + personal/ OR work/ subdirs.
#
# Profile selection: chezmoi's .chezmoiignore.tmpl ensures only one of
# personal/ or work/ exists on a given machine.

for _zpfn_subdir in shared personal work; do
    _zpfn_dir="$HOME/.bashrc.d/${_zpfn_subdir}"
    [ -d "${_zpfn_dir}" ] || continue
    for _zpfn_f in "${_zpfn_dir}"/*; do
        [ -f "${_zpfn_f}" ] && [ -r "${_zpfn_f}" ] && . "${_zpfn_f}"
    done
done

unset _zpfn_subdir _zpfn_dir _zpfn_f
