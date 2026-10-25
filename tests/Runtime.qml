import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.controls as Controls
import qs.services
import qs.services as Services

ShellRoot {
    id: root

    property int failures: 0
    property int completedCommands: 0
    property var processes: []
    property var indicatorManager
    property real previousProgress
    property var monitor

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Component.onCompleted: {
        for (let index = 0; index < 12; index++) {
            Nmcli.executeCommand([index % 2 === 0 ? "--version" : "--test-failure"], result => {
                root.check(result.success === (index % 2 === 0), "Command callback must preserve its exit status");
                root.completedCommands++;
            });
            root.processes.push(Nmcli.activeProcesses[Nmcli.activeProcesses.length - 1]);
        }
        root.monitor = Brightness.monitors[0];

        GlobalConfig.services.weatherLocation = "unresolvable test location";
        Weather.fetchCoordsFromCity("unresolvable test location");
        root.check(Services.Requests.pendingRequests.length === 1, "Weather must start one geocoding request");
        Services.Requests.pendingRequests[0].success('{"results":[]}');
        root.check(Services.Requests.pendingRequests.length === 1, "Empty geocoding results must not recursively request another lookup");
    }

    Item {
        Controls.StyledProgressBar {
            id: progress

            width: 200
            height: 4
            indeterminate: true
        }
    }

    Timer {
        interval: 150
        running: true
        onTriggered: {
            root.indicatorManager = progress.data.find(entry => typeof entry.completeEndProgress === "number");
            root.check(root.indicatorManager !== undefined, "Progress manager must be present");
            root.previousProgress = root.indicatorManager.progress;
            visibleTimer.start();

            Brightness.ddcMonitors = [
                {
                    connector: root.monitor.modelData.name,
                    busNum: "test"
                }
            ];
            root.check(root.monitor.isDdc, "DDC test monitor must be selected");
            brightnessTimer.start();
        }
    }

    Timer {
        id: brightnessTimer

        interval: 50
        onTriggered: {
            root.monitor.brightness = 0.7;
            root.monitor.timer.restart();
            root.monitor.setBrightness(0.8);
            root.monitor.setBrightness(0.7);
            root.check(root.monitor.queuedBrightness === 0.7, "DDC queue must retain the latest requested brightness");
        }
    }

    Timer {
        id: visibleTimer

        interval: 100
        onTriggered: {
            root.check(root.indicatorManager.progress !== root.previousProgress, "Visible progress must animate");
            progress.height = 0;
            root.previousProgress = root.indicatorManager.progress;
            collapsedTimer.start();
        }
    }

    Timer {
        id: collapsedTimer

        interval: 100
        onTriggered: {
            root.check(root.indicatorManager.progress === root.previousProgress, "Zero-height progress must stop updating");
            progress.visible = false;
            progress.height = 4;
            root.previousProgress = root.indicatorManager.progress;
            hiddenTimer.start();
        }
    }

    Timer {
        id: hiddenTimer

        interval: 100
        onTriggered: {
            root.check(root.indicatorManager.progress === root.previousProgress, "Hidden progress must stop updating");
            progress.visible = true;
            root.previousProgress = root.indicatorManager.progress;
            resumedTimer.start();
        }
    }

    Timer {
        id: resumedTimer

        interval: 400
        onTriggered: {
            root.check(root.indicatorManager.progress !== root.previousProgress, "Visible progress must resume updating");
            root.check(root.completedCommands === 12, "All command callbacks must run exactly once");
            root.check(root.processes.every(process => !Qt.isQtObject(process)), "Completed command objects must be destroyed");
            root.check(root.monitor.brightness === 0.7, "DDC throttle must not apply an obsolete queued brightness");
            root.check(isNaN(root.monitor.queuedBrightness), "DDC queue must be empty after its timeout");
            console.log("Runtime failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
