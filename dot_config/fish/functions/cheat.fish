# Quick cheatsheet lookup via cheat.sh.
function cheat --description 'Quick cheatsheet lookup via cheat.sh'
    curl -s "cheat.sh/$argv[1]"
end
