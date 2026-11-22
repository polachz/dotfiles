function lock-bw --description 'Lock Bitwarden and clear the shell session key'
    command bw lock
    set -l bw_lock_rc $status
    set -eg BW_SESSION
    return $bw_lock_rc
end
