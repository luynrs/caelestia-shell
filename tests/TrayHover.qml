import QtQuick
import Quickshell
import "fixtures"
import qs.components
import qs.modules.bar as Bar
import qs.modules.bar.popouts as Popouts

ShellRoot {
    id: root

    property int failures: 0
    property int samples: 0
    property bool switching: false
    property var tray

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    function findItem(parent: Item, name: string): Item {
        if (parent.objectName === name)
            return parent;
        for (const child of parent.children) {
            const found = findItem(child, name);
            if (found)
                return found;
        }
        return null;
    }

    function hover(index: int): void {
        const item = tray.items.itemAt(index);
        bar.checkPopout(item.mapToItem(bar, item.width / 2, item.height / 2).x);
    }

    TrayMenuHandle {
        id: menu
        entries: [entry]
    }

    TrayMenuHandle {
        id: entry
        text: "Open application"
    }

    ScreenState {
        id: state
        modelData: Quickshell.screens[0]
        bar: true
    }

    PanelWindow {
        implicitWidth: 1280
        implicitHeight: 720
        exclusiveZone: 0
        color: "transparent"
        mask: Region {}
        contentItem.opacity: 0

        Bar.BarWrapper {
            id: bar
            width: parent.width
            screen: Quickshell.screens[0]
            screenState: state
            popouts: popout.content
            fullscreen: false
        }

        Popouts.ClipWrapper {
            id: popout
            screen: Quickshell.screens[0]
            borderThickness: 10
        }
    }

    Component.onCompleted: {
        Popouts.TrayRegistry.entries = [0, 1, 2].map(index => ({
            id: `hover-fixture-${index}`,
            icon: Qt.resolvedUrl("assets/logo.svg"),
            status: 1,
            hasMenu: index !== 2,
            menu
        }));
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            root.tray = root.findItem(bar, "taskbarTray");
            root.check(root.tray !== null && root.tray.items.count === 3, "Bar hover must use the three fixture tray items");
            if (!root.tray || root.tray.items.count !== 3) {
                Qt.exit(1);
                return;
            }
            root.tray.expanded = true;
            initial.start();
        }
    }

    Timer {
        id: initial
        interval: 500
        onTriggered: {
            root.hover(0);
            gap.start();
        }
    }

    Timer {
        id: gap
        interval: 650
        onTriggered: {
            root.check(popout.content.hasCurrent && popout.offsetScale < 0.001, "Initial tray menu must finish opening before the pointer crosses its gap");
            const first = root.tray.items.itemAt(0);
            const second = root.tray.items.itemAt(1);
            root.check(second.x > first.x + first.width, "Fixture must exercise actual spacing between tray icons");
            root.switching = true;
            bar.checkPopout(first.mapToItem(bar, (first.width + second.x - first.x) / 2, first.height / 2).x);
            root.check(popout.content.hasCurrent && popout.content.currentName === "traymenu0", "The gap between tray icons must preserve the active popup");
            incoming.start();
        }
    }

    Timer {
        id: incoming
        interval: 100
        onTriggered: {
            root.hover(1);
            root.check(popout.content.currentName === "traymenu1", "The next tray icon must select its own menu");
            finish.start();
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: root.switching
        onTriggered: {
            root.samples++;
            root.check(popout.content.hasCurrent && popout.offsetScale < 0.001, "Crossing tray icons must not restart the opening animation");
        }
    }

    Timer {
        id: finish
        interval: 550
        onTriggered: {
            root.switching = false;
            root.check(root.samples > 20, "Tray hover continuity must be sampled across the gap and incoming menu");
            root.hover(2);
            root.check(!popout.content.hasCurrent, "A tray item without a menu must close the popup");
            console.log("Tray hover failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
