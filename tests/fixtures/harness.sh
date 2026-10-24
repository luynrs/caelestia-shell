test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
for directory in components modules utils assets; do
    ln -s "$source_dir/$directory" "$test_dir/$directory"
done
mkdir -p "$test_dir/services" "$test_dir/bin" "$test_dir/cache" "$test_dir/state/caelestia/wallpaper"
for service in "$source_dir/services/"*; do
    case ${service##*/} in
        Hypr.qml|Weather.qml|Wallpapers.qml) ;;
        *) ln -s "$service" "$test_dir/services/" ;;
    esac
done
sed -e '/^import qs.utils$/a import "." as TestServices' -e 's/Requests\.get/TestServices.Requests.get/g' "$source_dir/services/Weather.qml" > "$test_dir/services/Weather.qml"
cp "$source_dir/tests/fixtures/Requests.qml" "$test_dir/services/Requests.qml"
for state_file in scheme.json wallpaper/path.txt; do
    state_source="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/$state_file"
    if [[ -f $state_source ]]; then
        cp -- "$state_source" "$test_dir/state/caelestia/$state_file"
    fi
done
cat > "$test_dir/bin/command-stub" <<'SH'
#!/bin/sh
case ${0##*/} in
    nmcli) if [ "$1" = "--test-failure" ]; then exit 3; fi ;;
    ddcutil) case "$*" in *getvcp*) printf 'VCP 10 C 50 100\n';; esac ;;
esac
SH
chmod +x "$test_dir/bin/command-stub"
for command in nmcli ddcutil brightnessctl asdbctl caelestia; do
    ln -s command-stub "$test_dir/bin/$command"
done
export PATH="$test_dir/bin:$PATH"
export XDG_CACHE_HOME="$test_dir/cache"
export XDG_STATE_HOME="$test_dir/state"

run_test() {
    test_status=0
    timeout 15 "${QS_TEST_BIN:-qs}" --no-color -p "$test_dir" > "$test_dir/output.log" 2>&1 || test_status=$?
    cat "$test_dir/output.log"
    if rg --quiet 'ReferenceError|TypeError|Binding loop|setPaused.*cannot' "$test_dir/output.log"; then
        return 1
    fi
    return "$test_status"
}
