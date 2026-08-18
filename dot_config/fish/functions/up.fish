# cd up N directories (default 1) — complements the fixed-depth `..`/
# `...`/`....`/`.....` nav abbreviations with an arbitrary depth.
function up --description 'cd up N directories (default 1)'
    set -l n 1
    if test (count $argv) -gt 0
        set n $argv[1]
    end
    set -l target .
    for i in (seq 1 $n)
        set target $target/..
    end
    cd $target
end
