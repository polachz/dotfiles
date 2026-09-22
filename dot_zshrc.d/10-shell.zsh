#!/usr/bin/env zsh
# Set SHELL to the executable for this interactive zsh session.
# A child shell sets its own value; exiting it leaves the parent's value intact.
if [[ -o interactive ]]; then
    if [[ ${ZSH_ARGZERO:-} == */zsh && ${ZSH_ARGZERO} == /* && -x ${ZSH_ARGZERO} ]]; then
        export SHELL="${ZSH_ARGZERO}"
    elif [[ -x ${commands[zsh]:-} ]]; then
        export SHELL="${commands[zsh]}"
    else
        _zpfn_zsh_path="$(command -v zsh 2>/dev/null)"
        [[ -n ${_zpfn_zsh_path} ]] && export SHELL="${_zpfn_zsh_path}"
        unset _zpfn_zsh_path
    fi
fi
