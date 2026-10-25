#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$source_dir/tests/fixtures/harness.sh"
cp "$source_dir/tests/fixtures/Hypr.qml" "$test_dir/services/Hypr.qml"
cp "$source_dir/tests/fixtures/Wallpapers.qml" "$test_dir/services/Wallpapers.qml"
cp "$source_dir/tests/NetworkState.qml" "$test_dir/shell.qml"
rm "$test_dir/bin/nmcli"
cat > "$test_dir/bin/nmcli" <<'SH'
#!/bin/sh
case "$*" in
    '-g ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY d w')
        printf '%s\n' 'yes:80:2412: Cafe\\Lab\:Guest :AA\:BB\:CC\:DD\:EE\:FF:WPA2' ;;
    '-t -f NAME,TYPE connection show') printf '%s\n' ' Cafe\:Lab\\Profile :802-11-wireless' ;;
    '-t -f 802-11-wireless.ssid,802-11-wireless-security.key-mgmt connection show  Cafe:Lab\Profile ')
        printf '%s\n' '802-11-wireless.ssid: Cafe\Lab:Guest ' '802-11-wireless-security.key-mgmt:wpa-psk' ;;
esac
SH
chmod +x "$test_dir/bin/nmcli"
cat > "$test_dir/bin/tailscale" <<'SH'
#!/bin/sh
[ "$*" = 'status --json' ] || exit 2
sleep 0.8
printf '%s\n' '{"BackendState":"Running"}'
SH
cat > "$test_dir/bin/warp-cli" <<'SH'
#!/bin/sh
[ "$*" = status ] || exit 2
printf '%s\n' 'Status update: Connected'
SH
chmod +x "$test_dir/bin/tailscale" "$test_dir/bin/warp-cli"
run_test
