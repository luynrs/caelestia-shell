#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
cp "$source_dir/tests/fixtures/Hypr.qml" "$test_dir/services/Hypr.qml"
cp "$source_dir/tests/fixtures/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
cp "$source_dir/tests/ClipboardPreview.qml" "$test_dir/shell.qml"
case ${WAYLAND_DISPLAY:-} in
    /*) ;;
    *) export WAYLAND_DISPLAY="${XDG_RUNTIME_DIR:?}/${WAYLAND_DISPLAY:?}" ;;
esac
export XDG_RUNTIME_DIR="$test_dir/runtime"
mkdir -m 700 "$XDG_RUNTIME_DIR"
cat > "$test_dir/bin/cliphist" <<'SH'
#!/bin/sh
if [ "$1" = decode ] && [ "$2" = 201 ]; then
    printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGNgYPgPRAAFAgH/wSuWnwAAAABJRU5ErkJggg==' | base64 --decode
else
    exit 1
fi
SH
chmod +x "$test_dir/bin/cliphist"
run_test
[[ -f $XDG_RUNTIME_DIR/caelestia-clipboard/201.png ]]
