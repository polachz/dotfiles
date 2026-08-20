# Search shell history for a pattern — same as `gh` (dot_config/fish/functions/gh.fish.tmpl),
# but always available regardless of whether the real GitHub CLI is on PATH. See that file for why
# there are two names.
function ghi --description 'Search shell history for a pattern'
    history | grep $argv
end
