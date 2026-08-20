# Search shell history for a pattern. Only present on disk at all when the
# real GitHub CLI isn't on PATH at chezmoi apply time — masked out via
# .chezmoiignore.tmpl otherwise, since fish's autoload mechanism prefers
# ANY function file present here over an external binary of the same name,
# regardless of a runtime check inside the function body (unlike bash/zsh,
# which can check `command -v gh` live on every new shell — see
# dot_bashrc.d/85-functions-extra.sh). See ghi.fish for the
# always-available fallback name. User's call, 2026-08-20.
function gh --description 'Search shell history for a pattern'
    history | grep $argv
end
