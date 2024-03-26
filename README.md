# dotfiles
My Dotfiles managed by Chezmoi

Install From scratch:

Without git, ssh etc:

sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply polachz

Then switch to ssh

chezmoi cd && git remote set-url origin git@github.com:polachz/dotfiles.git



