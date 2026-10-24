#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
cp "$source_dir/tests/fixtures/Hypr.qml" "$test_dir/services/Hypr.qml"
cp "$source_dir/tests/fixtures/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
rm "$test_dir/services/Notifs.qml"
cat > "$test_dir/services/Notifs.qml" <<'QML'
pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property list<NotifData> list: []
    readonly property list<NotifData> popups: list.filter(notification => notification.popup)
}
QML
cp "$source_dir/tests/NotificationLifecycle.qml" "$test_dir/shell.qml"
run_test
