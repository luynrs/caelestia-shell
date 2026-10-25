import QtQuick
import Quickshell
import qs.modules.nexus.pages

ShellRoot {
    Item {
        width: 900
        height: 900

        AboutPage {
            id: about

            anchors.fill: parent
        }
    }

    Timer {
        interval: 600
        running: true
        onTriggered: {
            if (!/^\d+\.\d+\.\d+/.test(about.quickshellVersion)) {
                console.error("About must report the running Quickshell version without requiring a PATH alias");
                Qt.exit(1);
            } else {
                console.log("About version detection passed");
                Qt.quit();
            }
        }
    }
}
