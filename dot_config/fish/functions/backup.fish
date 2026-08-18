# Copy a file/dir to a timestamped .bak sibling.
function backup --description 'Copy a path to a timestamped .bak sibling'
    if test (count $argv) -eq 0
        echo "Usage: backup <path>" >&2
        return 1
    end
    cp -r $argv[1] $argv[1].bak-(date +%Y%m%d-%H%M%S)
end
