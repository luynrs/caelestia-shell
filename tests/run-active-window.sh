#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
mkdir -p "$XDG_CONFIG_HOME/caelestia"
printf '%s\n' '{"bar":{"activeWindow":{"showOnHover":false},"popouts":{"activeWindow":false}}}' > "$XDG_CONFIG_HOME/caelestia/shell.json"
cp "$source_dir/tests/fixtures/Hypr.qml" "$test_dir/services/Hypr.qml"
cp "$source_dir/tests/fixtures/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
cp "$source_dir/tests/ActiveWindow.qml" "$test_dir/shell.qml"
run_test
