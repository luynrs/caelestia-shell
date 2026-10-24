import QtQuick
import Quickshell
import qs.components.controls as Controls
import qs.modules.background as Background

ShellRoot {
    id: root
    property int failures: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    PanelWindow {
        id: window
        visible: false
        implicitWidth: 1280
        implicitHeight: 720

        Item {
            id: anchor
        }

        Controls.Menu {
            id: menu
            parent: window.contentItem
            attachTo: anchor
        }

        Background.Visualiser {
            id: visualiser
            screen: Quickshell.screens[0]
            wallpaper: anchor
            opacity: 0
        }
    }

    Timer {
        interval: 150
        running: true
        onTriggered: {
            root.check(!menu.layer.enabled, "Closed dropdown must not retain a full-window layer");
            root.check(visualiser.children.every(child => !child.layer.enabled), "Hidden visualiser must not retain a full-screen layer");
            menu.expanded = true;
            fadingTimer.start();
        }
    }

    Timer {
        id: fadingTimer
        interval: 50
        onTriggered: {
            root.check(menu.opacity > 0 && menu.opacity < 1, "Dropdown fade must be sampled");
            root.check(!menu.layer.enabled, "Dropdown fade must not layer its full-window input surface");
            root.check(menu.children[0].layer.enabled, "Dropdown fade must group its visual contents");
            root.check(menu.children[0].width < menu.width, "Dropdown fade layer must be limited to the dropdown bounds");
            settledTimer.start();
        }
    }

    Timer {
        id: settledTimer
        interval: 700
        onTriggered: {
            root.check(!menu.children[0].layer.enabled, "Opaque dropdown must release its transition layer");
            menu.expanded = false;
            closedTimer.start();
        }
    }

    Timer {
        id: closedTimer
        interval: 700
        onTriggered: {
            root.check(menu.opacity === 0 && !menu.layer.enabled && !menu.children[0].layer.enabled, "Closed dropdown must release all transition layers");
            console.log("Render budget failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
