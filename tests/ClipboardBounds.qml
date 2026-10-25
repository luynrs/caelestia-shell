import QtQuick
import Quickshell
import qs.components
import qs.modules.launcher as Launcher

ShellRoot {
    id: root

    property int failures: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    ScreenState {
        id: state

        modelData: Quickshell.screens[0]
        launcherQuery: ">clipboard "
        launcher: true
    }

    Item {
        id: stage

        width: 1280
        height: 300

        Launcher.Wrapper {
            id: launcher

            screen: Quickshell.screens[0]
            screenState: state
            panels: stage
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: {
            root.check(launcher.height > 200, "Large clipboard history must fill its bounded viewport");
            root.check(launcher.height <= stage.height && launcher.y >= 0, "Clipboard history must stay below the top bar");
            root.check(Math.abs(launcher.y + launcher.height - stage.height) < 1, "Clipboard history must retain the launcher bottom anchor");
            console.log("Clipboard bounds failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
