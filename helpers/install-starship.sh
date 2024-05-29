#!/usr/bin/env bash


sudo curl -sS https://starship.rs/install.sh | sh -s -- --force

echo 'eval "$(starship init bash)"' > "${HOME}/.bashrc.d/starship"
