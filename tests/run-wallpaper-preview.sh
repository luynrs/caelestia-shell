#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
cp "$source_dir/tests/fixtures/Hypr.qml" "$test_dir/services/Hypr.qml"
ln -s "$source_dir/services/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
cp "$source_dir/tests/WallpaperPreview.qml" "$test_dir/shell.qml"
for name in first second closing failure; do
    ln -s "$source_dir/assets/wallpaper.webp" "$test_dir/cache/$name"
done
rm "$test_dir/bin/caelestia"
cat > "$test_dir/bin/caelestia" <<'SH'
#!/bin/sh
if [ "$1" != wallpaper ] || [ "$2" != -p ]; then
    exit 0
fi
case ${3##*/} in
    first|closing) sleep 0.2; primary=ff0000 ;;
    second) primary=0000ff ;;
    failure) exit 1 ;;
    *) exit 2 ;;
esac
printf '{"name":"dynamic","flavour":"test","mode":"dark","colours":{"primary":"%s"}}\n' "$primary"
SH
chmod +x "$test_dir/bin/caelestia"
run_test
