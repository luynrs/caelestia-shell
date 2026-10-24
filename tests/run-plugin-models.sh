#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/walls/a" "$test_dir/walls/b" "$test_dir/bulk"
touch "$test_dir/walls/root.txt" "$test_dir/walls/a/first.txt" "$test_dir/walls/b/second.txt"
for index in {1..1024}; do
    : > "$test_dir/bulk/$index.txt"
done
printf 'P3\n1 1\n255\n255 0 0\n' > "$test_dir/red.ppm"
printf 'P3\n1 1\n255\n0 0 255\n' > "$test_dir/blue.ppm"
cp "$source_dir/tests/${1:-PluginModels.qml}" "$test_dir/shell.qml"
CAELESTIA_TEST_DIRECTORY="$test_dir" timeout 15 "${QS_TEST_BIN:-qs}" --no-color -p "$test_dir"
