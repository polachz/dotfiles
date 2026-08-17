# Switch the active Starship prompt theme for the current shell session —
# session-only (sets $STARSHIP_CONFIG); add a call to this in config.fish
# yourself if you want a theme to persist across new shells. See
# dot_config/starship/{atomic,jandedobbeleer}.toml for the available
# alternates to the default ~/.config/starship.toml (Pastel Powerline).
function starship-theme
    switch "$argv[1]"
        case pastel default ""
            set -e STARSHIP_CONFIG
        case atomic jandedobbeleer
            set -gx STARSHIP_CONFIG "$HOME/.config/starship/$argv[1].toml"
        case '*'
            echo "Usage: starship-theme <pastel|atomic|jandedobbeleer>" >&2
            return 1
    end
end
