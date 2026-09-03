# Search shell history for a pattern. `gh` (the short name) was removed
# 2026-09-03 to stop shadowing the real GitHub CLI unconditionally — this is
# the only remaining name.
function ghi --description 'Search shell history for a pattern'
    history | grep $argv
end
