#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
rm -r -- "$test_dir/services"
mkdir "$test_dir/services"
ln -s "$source_dir/services/Clipboard.qml" "$test_dir/services/Clipboard.qml"
cp "$source_dir/tests/Clipboard.qml" "$test_dir/shell.qml"
cp "$source_dir/tests/fixtures/clipboard-commands.sh" "$test_dir/bin/cliphist"
chmod +x "$test_dir/bin/cliphist"
ln -s cliphist "$test_dir/bin/wl-copy"
ln -s cliphist "$test_dir/bin/clipboard-cache-check"
export CAELESTIA_CLIPBOARD_TEST_DIRECTORY="$test_dir"
export XDG_RUNTIME_DIR="$test_dir/runtime"
mkdir -m 700 "$XDG_RUNTIME_DIR"
mkdir "$XDG_RUNTIME_DIR/caelestia-clipboard"
for filename in 9007199254740993.png 100.jpeg 9007199254740993.jpeg 42.png 43.jpeg 44.gif 45.bmp 46.tiff unrelated.txt notes.png 42.PNG 43.png.backup .123.png.tmp; do
    touch "$XDG_RUNTIME_DIR/caelestia-clipboard/$filename"
done
mkdir "$XDG_RUNTIME_DIR/caelestia-clipboard/47.png"
touch "$XDG_RUNTIME_DIR/caelestia-clipboard/47.png/child" "$test_dir/outside.png" "$XDG_RUNTIME_DIR/42.png"
ln -s "$test_dir/outside.png" "$XDG_RUNTIME_DIR/caelestia-clipboard/48.png"
printf 'wl-copy-failure' > "$test_dir/wl-copy-failure.bin"
printf '103\n' > "$test_dir/expected-text-delete.bin"
printf '9007199254740993\n' > "$test_dir/expected-image-delete.bin"
run_test
printf 'cliphist\t-preview-width\t400\tlist\ncliphist\tdecode\t103\ncliphist\tdecode\t9007199254740993\ncliphist\tdecode\t404\ncliphist\tdecode\t13\ncliphist\tdelete\ncliphist\tdelete\ncliphist\t-preview-width\t400\tlist\ncliphist\tdelete\ncliphist\t-preview-width\t400\tlist\ncliphist\t-preview-width\t400\tlist\ncliphist\t-preview-width\t400\tlist\ncliphist\t-preview-width\t400\tlist\n' > "$test_dir/expected-commands.log"
rg '^cliphist' "$test_dir/commands.log" > "$test_dir/cliphist-commands.log"
cmp -- "$test_dir/expected-commands.log" "$test_dir/cliphist-commands.log"
copy_calls=$(rg --count '^wl-copy$' "$test_dir/commands.log")
if [[ $copy_calls != 3 ]]; then
    printf 'Failed decode must not invoke wl-copy: expected 3 copy calls, received %s\n' "$copy_calls" >&2
    exit 1
fi
mapfile -t commands < "$test_dir/commands.log"
[[ ${#commands[@]} == 19 ]]
printf 'clipboard-cache-check\tinitial\nclipboard-cache-check\tfailed\nclipboard-cache-check\tempty\n' > "$test_dir/expected-cache-checks.log"
rg '^clipboard-cache-check' "$test_dir/commands.log" > "$test_dir/cache-checks.log"
cmp -- "$test_dir/expected-cache-checks.log" "$test_dir/cache-checks.log"
printf 'Привет\ttext\nsecond line\r\n\000trailing\n\n' > "$test_dir/expected-text.bin"
printf '\211PNG\r\n\032\n\000\377\200\000binary\n' > "$test_dir/expected-image.bin"
cmp -- "$test_dir/expected-text.bin" "$test_dir/copy-0.bin"
cmp -- "$test_dir/expected-image.bin" "$test_dir/copy-1.bin"
[[ ! -e $test_dir/copy-2.bin ]]
mapfile -t decode_files < "$test_dir/decode-files.log"
[[ ${#decode_files[@]} == 4 ]]
for decoded_file in "${decode_files[@]}"; do
    [[ ! -e $decoded_file ]]
done
cmp -- "$test_dir/expected-image-delete.bin" "$test_dir/delete-input.bin"
[[ ! -e $test_dir/injected ]]
[[ ! -e $XDG_RUNTIME_DIR/caelestia-clipboard/9007199254740993.png ]]
[[ ! -e $XDG_RUNTIME_DIR/caelestia-clipboard/9007199254740993.jpeg ]]
[[ ! -e $XDG_RUNTIME_DIR/caelestia-clipboard/888.gif ]]
for filename in unrelated.txt notes.png 42.PNG 43.png.backup .123.png.tmp 47.png/child 48.png; do
    [[ -e $XDG_RUNTIME_DIR/caelestia-clipboard/$filename ]]
done
[[ -f $test_dir/outside.png && -f $XDG_RUNTIME_DIR/42.png ]]
printf 'Clipboard commands preserve payload bytes and validated IDs\n'
