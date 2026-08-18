# Print $PATH one entry per line. Named `pathlist`, not `path` — fish 3.6+
# has a builtin `path` command (path manipulation, verified present in
# 4.8.1) that a function of that name would shadow; kept the same name
# across all shells rather than diverging just for this one. Fish's $PATH
# is already a list variable (unlike bash/zsh's colon-joined string), so
# `string join` is the natural fit here — no tr/split needed at all.
function pathlist --description 'Print $PATH one entry per line'
    string join \n $PATH
end
