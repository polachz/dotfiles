# git clone then cd into the resulting directory.
function gclone --description 'git clone and cd into the resulting directory'
    if test (count $argv) -eq 0
        echo "Usage: gclone <url>" >&2
        return 1
    end
    set -l dir (basename $argv[1] .git)
    git clone $argv[1]; and cd $dir
end
