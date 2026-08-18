# Serve the current directory over plain HTTP via python3 — same
# untracked-dependency caveat as dot_bashrc.d/85-functions-extra.sh.
function serve --description 'Serve the current directory over HTTP'
    if not command -q python3
        echo "serve: python3 not found on PATH" >&2
        return 1
    end
    set -l port 8000
    if test (count $argv) -gt 0
        set port $argv[1]
    end
    python3 -m http.server $port
end
