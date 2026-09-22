#!/usr/bin/env bash
# Keep user-local tools reachable in bash sessions. Repeated sourcing is safe.
if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
  export PATH="${HOME}/.local/bin${PATH:+:${PATH}}"
fi
