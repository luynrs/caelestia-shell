#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
cp "$source_dir/tests/fixtures/Hypr.qml" "$test_dir/services/Hypr.qml"
cp "$source_dir/tests/fixtures/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
rm "$test_dir/modules"
mkdir -p "$test_dir/modules/bar/popouts"
for module in "$source_dir/modules/"*; do
    if [[ ${module##*/} != bar ]]; then
        ln -s "$module" "$test_dir/modules/"
    fi
done
for module in "$source_dir/modules/bar/"*; do
    if [[ ${module##*/} != popouts ]]; then
        ln -s "$module" "$test_dir/modules/bar/"
    fi
done
if [[ ${1:-} == TrayHover.qml ]]; then
    cp "$source_dir/tests/fixtures/HyprReadOnly.qml" "$test_dir/services/Hypr.qml"
    rm "$test_dir/modules/bar/components"
    mkdir "$test_dir/modules/bar/components"
    for component in "$source_dir/modules/bar/components/"*; do
        case ${component##*/} in
            Tray.qml|TrayItem.qml) ;;
            *) ln -s "$component" "$test_dir/modules/bar/components/" ;;
        esac
    done
    sed -e '/^import Quickshell.Services.SystemTray$/a import qs.modules.bar.popouts as Popouts' -e 's/SystemTray.items.values/Popouts.TrayRegistry.items.values/g' "$source_dir/modules/bar/components/Tray.qml" > "$test_dir/modules/bar/components/Tray.qml"
    sed 's/property SystemTrayItem modelData/property var modelData/g' "$source_dir/modules/bar/components/TrayItem.qml" > "$test_dir/modules/bar/components/TrayItem.qml"
fi
for module in "$source_dir/modules/bar/popouts/"*; do
    case ${module##*/} in
        Content.qml|TrayMenu.qml) ;;
        *) ln -s "$module" "$test_dir/modules/bar/popouts/" ;;
    esac
done
sed -e 's/property QsMenuHandle/property QtObject/g' -e 's/property QsMenuEntry/property QtObject/g' -e 's/QsMenuOpener {/TrayMenuOpener {/g' "$source_dir/modules/bar/popouts/TrayMenu.qml" > "$test_dir/modules/bar/popouts/TrayMenu.qml"
sed -e 's/SystemTray.items.values/TrayRegistry.items.values/g' -e 's/property SystemTrayItem modelData/property var modelData/g' "$source_dir/modules/bar/popouts/Content.qml" > "$test_dir/modules/bar/popouts/Content.qml"
cp "$source_dir/tests/fixtures/TrayMenuOpener.qml" "$test_dir/modules/bar/popouts/TrayMenuOpener.qml"
cp "$source_dir/tests/fixtures/TrayRegistry.qml" "$test_dir/modules/bar/popouts/TrayRegistry.qml"
printf 'singleton TrayRegistry 1.0 TrayRegistry.qml\n' > "$test_dir/modules/bar/popouts/qmldir"
for module in "$test_dir/modules/bar/popouts/"*.qml; do
    if [[ ${module##*/} != TrayRegistry.qml ]]; then
        printf '%s 1.0 %s\n' "$(basename -- "$module" .qml)" "${module##*/}" >> "$test_dir/modules/bar/popouts/qmldir"
    fi
done
mkdir "$test_dir/fixtures"
cp "$source_dir/tests/fixtures/TrayMenuHandle.qml" "$test_dir/fixtures/TrayMenuHandle.qml"
cp "$source_dir/tests/${1:-TrayMenuMotion.qml}" "$test_dir/shell.qml"
run_test
