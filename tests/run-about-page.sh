#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
cp "$source_dir/tests/fixtures/Hypr.qml" "$test_dir/services/Hypr.qml"
cp "$source_dir/tests/fixtures/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
cp "$source_dir/tests/AboutPage.qml" "$test_dir/shell.qml"
run_test
