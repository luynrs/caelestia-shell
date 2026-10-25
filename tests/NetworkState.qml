import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.services as Services

ShellRoot {
    id: root

    property int failures: 0
    property bool vpnWrongStatus: false

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    function requestFor(fragment: string): var {
        return Services.Requests.pendingRequests.find(request => request.url.includes(fragment));
    }

    function weatherPayload(temperature: real): string {
        return JSON.stringify({
            current: { weather_code: 0, temperature_2m: temperature, apparent_temperature: temperature, relative_humidity_2m: 50, wind_speed_10m: 5, is_day: 1 },
            daily: { time: ["2026-10-25"], sunrise: ["2026-10-25T07:00"], sunset: ["2026-10-25T18:00"], temperature_2m_max: [temperature], temperature_2m_min: [temperature], weather_code: [0] },
            hourly: { time: ["2026-10-25T12:00"], temperature_2m: [temperature], precipitation_probability: [0], weather_code: [0] }
        });
    }

    function testWeatherResponses(): void {
        Weather.loc = "";
        GlobalConfig.services.weatherLocation = "Paris";
        GlobalConfig.services.weatherLocation = "Berlin";
        requestFor("name=Berlin").success('{"results":[{"name":"Berlin","latitude":52.52,"longitude":13.405}]}');
        requestFor("name=Paris").success('{"results":[{"name":"Paris","latitude":48.8566,"longitude":2.3522}]}');
        root.check(Weather.city === "Berlin" && Weather.loc === "52.52,13.405", "An older city lookup must not replace the configured location");

        GlobalConfig.services.weatherLocation = "1,2";
        Weather.fetchCityFromCoords("1,2");
        const oldReverseRequests = Services.Requests.pendingRequests.filter(request => request.url.includes("reverse?lat=1&lon=2"));
        GlobalConfig.services.weatherLocation = "3,4";
        requestFor("reverse?lat=3&lon=4").success('{"features":[{"properties":{"geocoding":{"type":"city","name":"Current city"}}}]}');
        oldReverseRequests[0].success('{"features":[{"properties":{"geocoding":{"type":"city","name":"Old city"}}}]}');
        root.check(Weather.city === "Current city", "An older reverse lookup must not replace the current city");
        oldReverseRequests[1].failure("old request failure");
        root.check(Weather.city === "Current city", "An older reverse lookup error must not clear the current city");

        requestFor("forecast?latitude=3&longitude=4").success(weatherPayload(30));
        requestFor("forecast?latitude=1&longitude=2").success(weatherPayload(10));
        root.check(Weather.cc.tempC === 30, "An older forecast must not replace weather for the current coordinates");
    }

    function testVpnSwitch(): void {
        GlobalConfig.utilities.toasts.vpnChanged = false;
        VPN.addProvider({name: "tailscale", displayName: "Previous provider", interface: "tailscale0", connectCmd: [], disconnectCmd: []});
        VPN.addProvider({name: "warp", displayName: "Current provider", interface: "CloudflareWARP", connectCmd: [], disconnectCmd: []});
        VPN.checkStatus();
        vpnSwitchTimer.start();
    }

    function testPendingCancellation(): void {
        root.check(Nmcli.active?.ssid === " Cafe\\Lab:Guest ", "Pending connection checks must use the active network from the command boundary");
        Nmcli.pendingConnection = null;
        Nmcli.checkPendingConnection();
        Nmcli.pendingConnection = {ssid: Nmcli.active.ssid, callback: () => root.check(false, "A canceled connection must not complete")};
        Nmcli.checkPendingConnection();
        Nmcli.pendingConnection = null;
        Qt.callLater(() => {
            root.check(Nmcli.pendingConnection === null, "A canceled connection must remain canceled");
            root.check(!Nmcli.immediateCheckTimer.running, "A canceled connection must not restart polling");
            root.testPendingReplacement();
        });
    }

    function testPendingReplacement(): void {
        let oldCallbacks = 0;
        let replacementCallbacks = 0;
        const successor = {ssid: "Successor", callback: () => root.check(false, "A successor connection must not complete against the old active network")};
        const replacement = {
            ssid: Nmcli.active.ssid,
            callback: result => {
                root.check(result.success, "The current connection must complete successfully");
                replacementCallbacks++;
                Nmcli.pendingConnection = successor;
            }
        };
        Nmcli.pendingConnection = {ssid: Nmcli.active.ssid, callback: () => oldCallbacks++};
        Nmcli.checkPendingConnection();
        Nmcli.pendingConnection = replacement;
        Qt.callLater(() => {
            root.check(oldCallbacks === 0 && replacementCallbacks === 0, "An old connection check must not complete either superseded or replacement callbacks");
            root.check(Nmcli.pendingConnection === replacement, "An old connection check must preserve a replacement even when its SSID matches");
            Nmcli.checkPendingConnection();
            Qt.callLater(() => {
                root.check(replacementCallbacks === 1, "A current pending connection must complete exactly once");
                root.check(Nmcli.pendingConnection === successor, "Completion must preserve a successor created by its callback");
                Nmcli.pendingConnection = null;
                Nmcli.immediateCheckTimer.stop();
                root.testVpnSwitch();
            });
        });
    }

    Connections {
        target: VPN
        function onStatusChanged(): void {
            if (VPN.providerName === "warp" && VPN.status.state === "error")
                root.vpnWrongStatus = true;
        }
    }

    Timer {
        interval: 150
        running: Weather.citiesLoaded
        onTriggered: {
            root.testWeatherResponses();
            root.check(Nmcli.cidrToSubnetMask("0") === "0.0.0.0", "IPv4 /0 must have an empty mask");
            root.check(Nmcli.cidrToSubnetMask("1") === "128.0.0.0", "IPv4 /1 must preserve its first bit");
            root.check(Nmcli.cidrToSubnetMask("24") === "255.255.255.0", "IPv4 /24 must preserve its prefix");
            root.check(Nmcli.cidrToSubnetMask("32") === "255.255.255.255", "IPv4 /32 must preserve all bits");

            const networks = Nmcli.parseNetworkOutput("no:80:2412: Cafe\\\\Lab\\:Guest :AA\\:BB\\:CC\\:DD\\:EE\\:FF:WPA2\nno:40:2412:STRINGWHICHHOPEFULLYWONTBEUSED:11\\:22\\:33\\:44\\:55\\:66:");
            root.check(networks[0].ssid === " Cafe\\Lab:Guest ", "Network SSIDs must retain spaces and decode escaped fields");
            root.check(networks[0].bssid === "AA:BB:CC:DD:EE:FF", "Network BSSID must decode escaped colons");
            root.check(networks[1].ssid === "STRINGWHICHHOPEFULLYWONTBEUSED", "Network names must not collide with parser placeholders");
            const devices = Nmcli.parseDeviceStatusOutput("wlan0:wifi:connected: Cafe\\:Lab\\\\Profile \n", "wifi");
            root.check(devices[0].connection === " Cafe:Lab\\Profile ", "Device connection names must decode escaped fields and preserve boundary spaces");

            Nmcli.loadSavedConnections(() => {
                root.check(Nmcli.savedConnections[0] === " Cafe:Lab\\Profile ", "Saved profile names must decode escaped fields and preserve boundary spaces");
                root.check(Nmcli.savedConnectionSsids[0] === " Cafe\\Lab:Guest ", "Saved SSIDs must preserve raw multiline values and spaces");
                Nmcli.processSsidOutput("802-11-wireless.ssid: Isolated SSID \n");
                root.check(Nmcli.savedConnectionSsids.includes(" Isolated SSID "), "A final SSID field without security settings must preserve boundary spaces");
                Nmcli.getNetworks(() => root.testPendingCancellation());
            });
        }
    }

    Timer {
        id: vpnSwitchTimer
        interval: 100
        onTriggered: {
            VPN.setActiveProvider(1);
            completionTimer.start();
        }
    }

    Timer {
        id: completionTimer
        interval: 2000
        onTriggered: {
            root.check(!root.vpnWrongStatus, "A previous provider's status output must not be parsed by the newly selected provider");
            root.check(VPN.connected, "Switching providers during a status query must fetch the current provider's state");
            console.log("Network state failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
