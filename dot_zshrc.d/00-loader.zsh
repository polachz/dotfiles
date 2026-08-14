#!/usr/bin/env zsh
# Profile subdir loader — zsh counterpart to dot_bashrc.d/00-loader.sh.
# .chezmoiignore.tmpl ensures only the active profile's subdir reaches disk
# on a given machine. (N) glob qualifier — see dot_zshrc.d/00-shared.zsh for
# why zsh needs it and bash doesn't.
for _zpfn_dir in "$HOME/.zshrc.d/"*/(N); do
    [ -d "${_zpfn_dir}" ] || continue
    for _zpfn_f in "${_zpfn_dir}"*(N); do
        [ -f "${_zpfn_f}" ] && [ -r "${_zpfn_f}" ] && source "${_zpfn_f}"
    done
done
unset _zpfn_dir _zpfn_f
