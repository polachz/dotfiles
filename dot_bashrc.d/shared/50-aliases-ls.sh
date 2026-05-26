#!/usr/bin/env bash
# ls variants — list files and folders with various filters.

# Detect which `ls` flavor is in use
if ls --color > /dev/null 2>&1; then # GNU `ls`
    colorflag="--color"
else # macOS `ls`
    colorflag="-G"
fi

# List all files and folders in long format
alias ll="ls -l ${colorflag}"

# List files and folders (include hidden ones) in long format
alias la="ls -A ${colorflag}"
# List all files (and folders include hidden ones) in long format
alias lla="ls -Al ${colorflag}"

# List only directories
alias ld="ls -d ${colorflag} */"
# List only directories in long format
alias lld="ls -ld ${colorflag} */"

# List only hidden files and directories
alias lh="ls -ld ${colorflag} .[^.]* ..?*"
# List only hidden files and directories in long format
alias llh="ls -ld ${colorflag} .[^.]* ..?*"

# List folder content sorted by size with item type classification
alias lt='ls --human-readable --size -1 -S --classify'

# List files sorted by modification date — last modified first
alias lm='ls -t -1 ${colorflag}'

# Colored grep
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
