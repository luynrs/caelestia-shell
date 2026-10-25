#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
if [[ ${1:-} == SidebarHover.qml ]]; then
    mkdir -p "$XDG_CONFIG_HOME/caelestia"
    printf '%s\n' '{"sidebar":{"showOnHover":true,"minHoverThreshold":30},"utilities":{"enabled":true}}' > "$XDG_CONFIG_HOME/caelestia/shell.json"
    rm "$test_dir/services/Notifs.qml"
    cat > "$test_dir/services/Notifs.qml" <<'QML'
pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property bool dnd: false
    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(notification => !notification.closed)
    readonly property list<NotifData> popups: list.filter(notification => notification.popup)
    function hasFullscreen(): bool { return false; }
}
QML
fi
cp "$source_dir/tests/fixtures/HyprReadOnly.qml" "$test_dir/services/Hypr.qml"
ln -s "$source_dir/services/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
cp "$source_dir/tests/${1:-BarGeometry.qml}" "$test_dir/shell.qml"
run_test
