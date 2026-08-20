# Pretty-print JSON via jq (workstation-only package, see packages.yaml).
# Works both piped and with a file argument — jq falls back to stdin when
# given zero file args.
function json --description 'Pretty-print JSON via jq'
    if not command -v jq >/dev/null 2>&1
        echo "json: jq not installed (jq is a workstation-only package, see packages.yaml)" >&2
        return 1
    end
    jq . $argv
end
