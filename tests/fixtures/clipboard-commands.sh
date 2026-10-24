#!/usr/bin/env bash
set -euo pipefail

directory=$CAELESTIA_CLIPBOARD_TEST_DIRECTORY
command=${0##*/}
arguments=""
if (($# > 0)); then
    printf -v arguments '\t%s' "$@"
fi
printf '%s%s\n' "$command" "$arguments" >> "$directory/commands.log"

if [[ $command == clipboard-cache-check ]]; then
    preview_directory="$XDG_RUNTIME_DIR/caelestia-clipboard"
    case $1 in
        initial)
            [[ -f $preview_directory/9007199254740993.png && -f $preview_directory/100.jpeg ]]
            for filename in 9007199254740993.jpeg 42.png 43.jpeg 44.gif 45.bmp 46.tiff; do
                [[ ! -e $preview_directory/$filename ]]
            done
            ;;
        failed) [[ -f $preview_directory/777.png ]] ;;
        empty) [[ ! -e $preview_directory/100.jpeg && ! -e $preview_directory/777.png ]] ;;
        *) exit 12 ;;
    esac
elif [[ $command == wl-copy ]]; then
    cat > "$directory/copy-input.bin"
    if cmp -s -- "$directory/copy-input.bin" "$directory/wl-copy-failure.bin"; then
        exit 9
    fi
    count=0
    if [[ -f $directory/copies ]]; then
        read -r count < "$directory/copies"
    fi
    cp -- "$directory/copy-input.bin" "$directory/copy-$count.bin"
    printf '%s\n' "$((count + 1))" > "$directory/copies"
elif [[ $# == 3 && $1 == -preview-width && $2 == 400 && $3 == list ]]; then
    count=0
    if [[ -f $directory/lists ]]; then
        read -r count < "$directory/lists"
    fi
    ((count += 1))
    printf '%s\n' "$count" > "$directory/lists"
    case $count in
        4) touch "$XDG_RUNTIME_DIR/caelestia-clipboard/777.png"; exit 7 ;;
        5) printf 'opening db: please store something first\n' >&2; exit 1 ;;
        6) touch "$XDG_RUNTIME_DIR/caelestia-clipboard/888.gif"; exit 0 ;;
    esac
    entries=(
        $'9007199254740993\t[[ binary data 3 KiB png 32x24 ]]'
        $'103\tПривет WORLD\tindented'
        $'102\timage/png is text'
        $'101\t$(touch injected) `touch injected`'
        $'100\t[[ binary data 3 KiB jpeg 48x32 ]]'
        $'99\t[[ binary data 12 B application/octet-stream ]]'
        $'98\t[[ binary data 3 KiB png 32x24 ]] trailing'
        $'97\t'
        $'not-an-id\ttext'
        $'1;touch injected\ttext'
        $'-1\ttext'
        $'\ttext'
        '96 missing separator'
    )
    for entry in "${entries[@]}"; do
        if [[ $entry == $'103\t'* && -f $directory/deleted-text ]]; then
            continue
        fi
        if [[ $entry == $'9007199254740993\t'* && -f $directory/deleted-image ]]; then
            continue
        fi
        printf '%s\n' "$entry"
    done
elif [[ $# == 2 && $1 == decode ]]; then
    decoded_file=$(readlink -- "/proc/$$/fd/1")
    if [[ ! -f $decoded_file || $decoded_file != "$XDG_RUNTIME_DIR/"* || $(stat -c %a -- "$decoded_file") != 600 ]]; then
        printf 'Decode must write to a private runtime file\n' >&2
        exit 11
    fi
    printf '%s\n' "$decoded_file" >> "$directory/decode-files.log"
    case $2 in
        103) printf 'Привет\ttext\nsecond line\r\n\000trailing\n\n' ;;
        9007199254740993) printf '\211PNG\r\n\032\n\000\377\200\000binary\n' ;;
        404) printf 'partial decode'; exit 7 ;;
        13) printf 'wl-copy-failure' ;;
        *) exit 10 ;;
    esac
elif [[ $# == 1 && $1 == delete ]]; then
    cat > "$directory/delete-input.bin"
    if cmp -s -- "$directory/delete-input.bin" "$directory/expected-text-delete.bin"; then
        touch "$directory/deleted-text"
    elif cmp -s -- "$directory/delete-input.bin" "$directory/expected-image-delete.bin"; then
        touch "$directory/deleted-image"
    else
        exit 8
    fi
else
    exit 10
fi
