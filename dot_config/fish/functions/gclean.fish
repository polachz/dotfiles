# Delete local git branches already merged into the repo's default branch —
# see dot_bashrc.d/85-functions-extra.sh for the detection/safety-net logic,
# identical here just fish syntax.
function gclean --description 'Delete local git branches merged into the default branch'
    set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace 'refs/remotes/origin/' '')
    if test -z "$default_branch"
        set default_branch main
    end
    for branch in (git branch --merged $default_branch | string trim)
        if test "$branch" = "$default_branch"; or test "$branch" = main; or test "$branch" = master; or string match -q '\**' -- $branch
            continue
        end
        git branch -d $branch
    end
end
