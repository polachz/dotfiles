# Extract almost any archive based on its file extension — see
# dot_bashrc.d/85-functions-extra.sh for the shared reasoning (tar
# auto-detects compression, -k keeps the original on single-file
# compressors).
function unpack --description 'Extract an archive based on its extension'
    if test (count $argv) -eq 0; or not test -f $argv[1]
        echo "unpack: '$argv[1]' is not a valid file" >&2
        return 1
    end
    switch $argv[1]
        case '*.tar' '*.tar.gz' '*.tgz' '*.tar.bz2' '*.tbz2' '*.tar.xz' '*.txz'
            tar xf $argv[1]
        case '*.zip'
            unzip $argv[1]
        case '*.rar'
            unrar x $argv[1]
        case '*.7z'
            7z x $argv[1]
        case '*.gz'
            gunzip -k $argv[1]
        case '*.bz2'
            bunzip2 -k $argv[1]
        case '*.xz'
            unxz -k $argv[1]
        case '*.Z'
            uncompress $argv[1]
        case '*'
            echo "unpack: don't know how to extract '$argv[1]'" >&2
            return 1
    end
end
