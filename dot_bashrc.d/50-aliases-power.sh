#!/usr/bin/env bash
# Power management shortcuts — reboot, halt, shutdown.

if [ $UID -ne 0 ]; then
   alias reboot='sudo /sbin/reboot'
   alias poweroff='sudo /sbin/poweroff'
   alias halt='sudo /sbin/halt'
   alias shutdown='sudo /sbin/shutdown'
   alias shutdownnow='sudo /sbin/shutdown -h now'
else
   alias shutdownnow='/sbin/shutdown -h now'
fi

# Run root shell
alias root='sudo -i'

# Reload the shell (i.e. invoke as a login shell)
alias reload="exec ${SHELL} -l"
