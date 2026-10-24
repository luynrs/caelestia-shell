#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
rules_path=${CAELESTIA_XKB_RULES_PATH:-/usr/share/X11/xkb/rules/base.lst}
source "$source_dir/tests/fixtures/harness.sh"
cp "$source_dir/tests/fixtures/HyprReadOnly.qml" "$test_dir/services/Hypr.qml"
cp "$source_dir/tests/fixtures/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
cp "$source_dir/tests/KbLayoutModel.qml" "$test_dir/shell.qml"
mkdir "$test_dir/rules"
ln -s "${rules_path%.lst}.xml" "$test_dir/rules/base.xml"
ln -s "${rules_path%/*}/evdev.xml" "$test_dir/rules/evdev.xml"
test -f "$test_dir/rules/base.xml"
test -f "$test_dir/rules/evdev.xml"
export CAELESTIA_XKB_RULES_PATH="$test_dir/rules/base.lst"
export LC_ALL=C.UTF-8
cat > "$test_dir/bin/hyprctl" <<'SH'
#!/bin/sh
case "$*" in
    '-j getoption input:kb_layout')
        if [ "${KB_LAYOUT_TEST_SOURCE:-option}" = option ]; then
            printf '%s\n' '{"str":"us(dvorak),ru,gb,zz"}'
        elif [ "$KB_LAYOUT_TEST_SOURCE" = duplicates ]; then
            printf '%s\n' '{"str":"us,us,ru"}'
        else
            printf '%s\n' '{}'
        fi ;;
    '-j devices')
        if [ "${KB_LAYOUT_TEST_SOURCE:-option}" = duplicates ]; then
            printf '%s\n' '{"keyboards":[{"main":false,"layout":"de","active_layout_index":0},{"main":true,"layout":"us,us,ru","active_layout_index":2}]}'
        else
            printf '%s\n' '{"keyboards":[{"main":false,"layout":"de","active_layout_index":0},{"main":true,"layout":"us(dvorak),ru,gb,zz","active_layout_index":1}]}'
        fi ;;
    *) exit 1 ;;
esac
SH
chmod +x "$test_dir/bin/hyprctl"
run_test
! rg --quiet 'Process failed to start' "$test_dir/output.log"
export KB_LAYOUT_TEST_SOURCE=duplicates
run_test
! rg --quiet 'Process failed to start' "$test_dir/output.log"
rm "$test_dir/rules/base.xml"
export KB_LAYOUT_TEST_SOURCE=devices
run_test
! rg --quiet 'Process failed to start' "$test_dir/output.log"
