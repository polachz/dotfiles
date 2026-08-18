# Chezmoi shortcuts — fish port of dot_bashrc.d/chezmoi-aliases (2026-08-18,
# see CONCEPT_ROADMAP.md §3.6). No `history -a` needed here, unlike bash/zsh:
# fish writes history live after every command by default, so there's
# nothing to lose if chezmoi apply triggers a shell restart — the bash/zsh
# version's whole reason for existing doesn't apply, hence a plain abbr
# instead of a hand-copied `history -a` idiom that would be a no-op here.
abbr -a -- ch chezmoi
abbr -a -- chd 'chezmoi cd'
