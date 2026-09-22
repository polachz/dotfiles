#!/usr/bin/env bash
# Set SHELL to the executable for this interactive bash session.
# A child shell sets its own value; exiting it leaves the parent's value intact.
case $- in
  *i*)
    if [[ ${BASH:-} == /* && -x ${BASH} ]]; then
      export SHELL="${BASH}"
    else
      _zpfn_bash_path=$(type -P bash 2>/dev/null || true)
      if [[ -n ${_zpfn_bash_path} ]]; then
        export SHELL="${_zpfn_bash_path}"
      fi
      unset _zpfn_bash_path
    fi
    ;;
esac
