#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
cp "$source_dir/tests/fixtures/Hypr.qml" "$test_dir/services/Hypr.qml"
cp "$source_dir/tests/fixtures/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
cp "$source_dir/tests/${1:-ClipboardLauncher.qml}" "$test_dir/shell.qml"
if [[ ${1:-} == ClipboardBounds.qml ]]; then
    export CAELESTIA_CLIPBOARD_MANY_ENTRIES=1
fi
if [[ ${1:-} == ClipboardShortcut.qml ]]; then
    rm "$test_dir/components"
    cp -r "$source_dir/components" "$test_dir/components"
    cat > "$test_dir/components/misc/CustomShortcut.qml" <<'QML'
import QtQml
import qs.services

QtObject {
    id: shortcut
    property string name
    property string description
    signal pressed()
    signal released()
    Component.onCompleted: ShellState.shortcuts.push(shortcut)
}
QML
    rm "$test_dir/services/ShellState.qml"
    cat > "$test_dir/services/ShellState.qml" <<'QML'
pragma Singleton
import Quickshell
import qs.components

Singleton {
    property var shortcuts: []
    property ScreenState state: ScreenState {
        modelData: Quickshell.screens[0]
    }

    function forActive(): ScreenState {
        return state;
    }
}
QML
fi
cat > "$test_dir/bin/cliphist" <<'SH'
#!/bin/sh
case "$*" in
    *list)
        if [ "${CAELESTIA_CLIPBOARD_MANY_ENTRIES:-}" = 1 ]; then
            index=1
            while [ "$index" -le 24 ]; do
                printf '%s\tClipboard sample %s\n' "$index" "$index"
                index=$((index + 1))
            done
        else
            printf '102\tBeta clipboard sample\n101\tAlpha clipboard sample\n'
        fi
        ;;
    'decode 102') sleep 0.2; printf 'exact beta payload';;
    *) exit 1;;
esac
SH
cat > "$test_dir/bin/wl-copy" <<'SH'
#!/bin/sh
cat > "$XDG_CACHE_HOME/copied"
SH
chmod +x "$test_dir/bin/cliphist" "$test_dir/bin/wl-copy"
run_test
if [[ ${1:-ClipboardLauncher.qml} != ClipboardBounds.qml && ${1:-} != ClipboardShortcut.qml ]]; then
    [[ $(cat "$test_dir/cache/copied") == 'exact beta payload' ]]
fi
