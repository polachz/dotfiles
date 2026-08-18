# Pretty-print JSON via jq (workstation-only package, see packages.yaml).
# Works both piped and with a file argument — jq falls back to stdin when
# given zero file args.
function json --description 'Pretty-print JSON via jq'
    jq . $argv
end
