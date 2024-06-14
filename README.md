# dotfiles
My Dotfiles managed by Chezmoi

Install From scratch:

Without git, ssh etc:

sh -c "$(wget -qO- https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"

or 

sh -c "$(curl -fsSL https://raw.githubusercontent.com/polachz/dotfiles/main/bootstrap.sh)"

Supported Env variables:

CHZ_BOOTSTRAP_ONE_SHOT

CHZ_BOOTSTRAP_DRY_RUN

CHZ_DOTFILES_DEBUG - exported variable. Enable debug messages in whole scripts. Not means chezmoi --debug !!!

CHZ_BOOTSTRAP_VERBOSE

-- deprecated ---
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply polachz

Switch to SSH is now provided automatically by chezmoi scripts

Deployment types:
- server
- workstation

Boolean attributes:
- gui
- vm

VM types:

- virtualbox
- vmware
- qemu





