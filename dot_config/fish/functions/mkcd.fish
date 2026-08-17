# Create a directory (and any missing parents) and cd into it in one step.
function mkcd
    mkdir -p -- $argv[1]
    and cd -- $argv[1]
end
