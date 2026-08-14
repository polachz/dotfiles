# Starship is an optional layer on top of the classic prompt — it only
# activates if actually installed. Loads last (conf.d files autoload in
# alphabetical order, "starship-init" sorts after "aliases").
if command -q starship
    starship init fish | source
end
