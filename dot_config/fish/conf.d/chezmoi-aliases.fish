# Chezmoi shortcuts — fish port of dot_bashrc.d/chezmoi-aliases (2026-08-18,
# see CONCEPT_ROADMAP.md §3.6). No `history -a` needed here, unlike bash/zsh:
# fish writes history live after every command by default, so there's
# nothing to lose if chezmoi apply triggers a shell restart — the bash/zsh
# version's whole reason for existing doesn't apply.
#
# `ch` is a function, not a plain abbr like `chd` (2026-08-20) — `ch update`
# specifically auto-reloads the shell afterward (`exec $SHELL -l`, same
# mechanism as the `reload` alias), otherwise newly added/changed
# functions/aliases from the pulled commits aren't visible until the shell
# is manually restarted. An abbr can't express that conditional. Trade-off:
# abbr expands visibly on the command line before you press enter, a
# function doesn't — accepted for the reload behavior this needs.
function ch --description 'Invoke chezmoi, auto-reload the shell after a successful update'
    chezmoi $argv
    set -l ch_status $status
    if test "$argv[1]" = update -a "$ch_status" -eq 0
        exec $SHELL -l
    end
    return $ch_status
end
# Plain `cd`, NOT `chezmoi cd` — that's chezmoi's own subcommand, a
# separate process that can't change ITS PARENT shell's directory (no
# process can), so it launches a whole new nested shell instead. Repeated
# `chd` without remembering to `exit` each one stacks up nested shells
# (confirmed live 2026-08-20). `chezmoi source-path` is a plain query (just
# prints the path), so `cd`-ing to its output in the current shell avoids
# nesting entirely.
abbr -a -- chd 'cd (chezmoi source-path)'
