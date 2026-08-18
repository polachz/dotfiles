# Find and kill whatever process is listening on a TCP port — genuine
# macOS/Linux tool split, see dot_bashrc.d/85-functions-extra.sh for why
# (macOS's fuser has no network-port awareness at all, verified live).
function killport --description 'Kill whatever process listens on a TCP port'
    if test (count $argv) -eq 0
        echo "Usage: killport <port>" >&2
        return 1
    end
    if test (uname) = Darwin
        set -l pid (lsof -nP -iTCP:$argv[1] -sTCP:LISTEN -t 2>/dev/null)
        if test -z "$pid"
            echo "killport: nothing listening on port $argv[1]" >&2
            return 1
        end
        echo $pid | xargs kill -9
        echo "killport: killed PID(s) $pid on port $argv[1]"
    else
        fuser -k $argv[1]/tcp
    end
end
