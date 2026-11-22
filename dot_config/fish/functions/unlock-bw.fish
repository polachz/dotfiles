function unlock-bw --description 'Unlock Bitwarden for this shell'
    if set -q fish_trace
        echo 'Disable shell tracing before unlocking.' >&2
        return 1
    end
    if not command -sq bw
        echo 'Bitwarden CLI (bw) is required.' >&2
        return 127
    end
    if test -n "$BW_SESSION"; and command bw unlock --check >/dev/null 2>&1
        return 0
    end
    if not command bw login --check >/dev/null
        echo 'Check your Bitwarden CLI login with bw login.' >&2
        return 1
    end

    set -l bw_key (command bw unlock --raw)
    or return $status
    if test (count $bw_key) -ne 1; or not string match -rq '^[A-Za-z0-9+/=_-]+$' -- "$bw_key"
        echo 'Invalid Bitwarden session response.' >&2
        return 1
    end
    begin
        set -lx BW_SESSION "$bw_key"
        if not command bw unlock --check >/dev/null 2>&1
            echo 'Bitwarden CLI did not accept the new session key.' >&2
            return 1
        end
    end
    set -gx BW_SESSION "$bw_key"
end
