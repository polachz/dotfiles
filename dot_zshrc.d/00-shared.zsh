#!/usr/bin/env zsh
# Shared (bash+zsh) portable content — same files bash's ~/.bashrc.d/*
# auto-sourcing picks up. Listed explicitly (not globbed) to skip bash-only
# files (99-prompt.sh: PS1 escapes, 01-bash-history.sh: HISTCONTROL/HISTFILESIZE
# have no zsh equivalent). 80-functions-common.sh was excluded until
# 2026-08-01 for using `export -f` (confirmed no-op/broken in zsh) — fixed,
# now shared (see CONCEPT_ROADMAP.md §3.8.1).
for _zpfn_f in "$HOME/.bashrc.d/00-colors.sh" "$HOME/.bashrc.d/05-env-generated.sh" "$HOME/.bashrc.d/50-aliases-generated.sh" "$HOME/.bashrc.d/50-aliases-power.sh" "$HOME/.bashrc.d/80-functions-common.sh" "$HOME/.bashrc.d/git-aliases" "$HOME/.bashrc.d/chezmoi-aliases"; do
    [ -f "${_zpfn_f}" ] && [ -r "${_zpfn_f}" ] && source "${_zpfn_f}"
done

# Profile subdir content (personal/work) — same loader logic as bash's
# 00-loader.sh; .chezmoiignore.tmpl ensures only the active profile's subdir
# reaches disk on a given machine. The (N) glob qualifier is zsh-specific —
# without it, zsh treats a no-match glob (e.g. an empty work/ dir) as a fatal
# error and aborts the rest of this file, unlike bash which just no-ops.
for _zpfn_dir in "$HOME/.bashrc.d/"*/(N); do
    [ -d "${_zpfn_dir}" ] || continue
    for _zpfn_f in "${_zpfn_dir}"*(N); do
        [ -f "${_zpfn_f}" ] && [ -r "${_zpfn_f}" ] && source "${_zpfn_f}"
    done
done
unset _zpfn_dir _zpfn_f
