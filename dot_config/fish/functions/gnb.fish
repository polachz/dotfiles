# Creates a new git branch and pushes it to the remote with tracking set up
# in one step — see dot_bashrc.d/85-functions-extra.sh for the base-branch
# detection/safety-net logic, identical here just fish syntax.
function gnb --description 'Create a new git branch and push it upstream'
    set -l name $argv[1]
    set -l base $argv[2]
    if test -z "$name"
        echo "usage: gnb <branch-name> [base-branch|@]" >&2
        return 1
    end
    if test -z "$base"
        set base (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace 'refs/remotes/origin/' '')
        test -z "$base"; and set base main
    else if test "$base" = "@"
        set base HEAD
    end
    git rev-parse --verify --quiet $base >/dev/null 2>&1; or set base "origin/$base"
    git switch -c $name $base; or return 1
    git push -u origin $name
end
