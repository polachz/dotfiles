# Set SHELL only for interactive fish sessions. `status fish-path` resolves
# the executable used to start this fish process, including versioned installs.
if status is-interactive
    set -gx SHELL (status fish-path)
end
