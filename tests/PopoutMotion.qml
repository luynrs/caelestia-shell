import QtQuick
import Quickshell
import qs.modules.bar.popouts as Popouts

ShellRoot {
    id: root
    property real menuWidth: 360
    property real menuHeight: 240
    property int failures: 0
    property int phase: 0
    property int samples: 0
    property int realContentSamples: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Component {
        id: menus
        Item {
            implicitWidth: root.menuWidth
            implicitHeight: root.menuHeight
        }
    }

    Item {
        id: stage
        width: 1280
        height: 720
        Popouts.ClipWrapper {
            id: realPopout
            screen: Quickshell.screens[0]
            borderThickness: 10
        }
        Popouts.ClipWrapper {
            id: popout
            screen: Quickshell.screens[0]
            borderThickness: 10
        }
    }

    Component.onCompleted: {
        realPopout.content.currentName = "audio";
        realPopout.content.hasCurrent = true;
        popout.content.content.sourceComponent = menus;
        popout.content.currentCenter = stage.width - 5;
        popout.content.hasCurrent = true;
    }

    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            if (root.phase === 0) {
                root.phase++;
                realPopout.content.currentName = "kblayout";
                root.menuWidth = 600;
                root.menuHeight = 450;
                popout.content.currentCenter = stage.width - 35;
            } else if (root.phase === 1) {
                root.check(root.realContentSamples > 0, "Keyboard popout must provide content during its transition");
                root.realContentSamples = 0;
                root.phase++;
                realPopout.content.currentName = "audio";
                root.menuWidth = 220;
                root.menuHeight = 150;
                popout.content.currentCenter = stage.width - 5;
            } else if (root.phase === 2) {
                root.check(root.realContentSamples > 0, "Audio popout must provide content during its transition");
                root.phase++;
                root.menuWidth = 420;
                root.menuHeight = 300;
                popout.content.currentCenter = 50;
            } else {
                root.check(root.samples > 0, "Switching geometry must be sampled");
                console.log("Popout motion failures:", root.failures);
                Qt.exit(root.failures === 0 ? 0 : 1);
            }
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: root.phase > 0
        onTriggered: {
            root.samples++;
            if (realPopout.content.current) {
                root.realContentSamples++;
                root.check(Math.abs(realPopout.content.current.parent.y) < 1, "Incoming popout content must retain its top edge while its container resizes");
            }
            root.check(popout.x >= -1 && popout.x + popout.width <= stage.width + 1, "Switching popouts must stay within the horizontal screen bounds");
        }
    }
}
