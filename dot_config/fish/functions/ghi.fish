# Merge and regex-search shell history for a pattern. `gh` (the short name) was removed
# 2026-09-03 to stop shadowing the real GitHub CLI unconditionally — this is
# the only remaining name.
function ghi --description 'Merge and regex-search shell history for a pattern'
    history merge
    history | grep $argv
end
