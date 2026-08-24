# Native prompt, color-coded by uid (root=red, user=green) — fish
# equivalent of dot_bashrc.d/99-prompt.sh / dot_zshrc.d/99-prompt.zsh.
# `set_color --bold <name>` emits the same two SGR parameters (bold + base
# color) as those files' raw `\033[01;3xm` escapes, just in the opposite
# order within the sequence — every ANSI terminal treats SGR parameters as
# unordered, so the rendered color is identical, verified byte-for-byte via
# `set_color --bold red` vs `\033[01;31m`.
#
# Fish autoloads this lazily, only the first time a prompt is actually drawn
# and no fish_prompt is already defined in the session. Oh My Posh's
# dot_config/fish/conf.d/ohmyposh-init.fish (if oh-my-posh is installed)
# sources its own fish_prompt definition at shell startup, before any prompt
# is ever drawn — so this file is a true fallback, not a competing override,
# same layering model as the classic prompt vs. Oh My Posh on bash/zsh.
function fish_prompt
    set -l user_color green
    fish_is_root_user; and set user_color red

    set_color --bold $user_color
    echo -n $USER
    set_color --bold magenta
    echo -n '@'
    set_color --bold cyan
    echo -n "$hostname "
    set_color --bold blue
    echo -n (basename $PWD)
    set_color normal
    echo -n '$ '
end
