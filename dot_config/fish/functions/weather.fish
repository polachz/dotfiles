# Quick weather report via wttr.in. Empty arg = auto-detect by IP — an
# out-of-range fish list index ($argv[1] on an empty $argv) yields an empty
# string rather than erroring, so this needs no explicit empty-arg check.
function weather --description 'Quick weather report via wttr.in'
    curl -s "wttr.in/$argv[1]"
end
