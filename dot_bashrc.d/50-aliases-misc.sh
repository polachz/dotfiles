#!/usr/bin/env bash
# Miscellaneous shortcuts — count files, history search, file ownership, networking.

# Show history items only with specified pattern
alias gh='history | grep'

# Count all files in current directory tree
alias count='find . -type f | wc -l'

# Set owner of the file to current user
alias makeme='sudo chown $USER:$USER'

# Set owner of the file to root
alias makeroot='sudo chown 0:0'

alias sha='shasum -a 256 '

# Reduce ping count to 5 tries (same as on Windows)
alias ping='ping -c 5'

# Display all listening ports on this machine
alias ports='netstat -tulanp'

# Get week number
alias week='date +%V'

# Allow sudo for other aliases
alias sudo='sudo '

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'
