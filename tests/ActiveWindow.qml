import QtQuick
import Quickshell
import qs.services
import qs.modules.bar.components as Widgets

ShellRoot {
    id: root

    property int failures: 0
    property int updates: 0
    property int shortTitleIndex: 0
    readonly property list<string> shortTitles: ["Discord", "Brave", "Дискорд", "WWW", "iiii", "A"]

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    function clickArea(item: Item): MouseArea {
        if (item instanceof MouseArea)
            return item;
        for (const child of item.children) {
            const area = clickArea(child);
            if (area)
                return area;
        }
        return null;
    }

    function readableTitle(item: Item, title: string): bool {
        if (item instanceof Text && item.text === title && item.opacity === 1)
            return true;
        return item.children.some(child => readableTitle(child, title));
    }

    function truncatedTitle(item: Item): bool {
        if (item instanceof Text && item.truncated)
            return true;
        return item.children.some(child => truncatedTitle(child));
    }

    Item {
        width: 480
        height: 120

        Item {
            id: bar

            readonly property int spacing: 0

            readonly property int hPadding: 0

            readonly property QtObject popouts: QtObject {
                property bool hasCurrent: false
                property string currentName: ""
                property real currentCenter: 0
            }

            anchors.fill: parent

            Widgets.ActiveWindow {
                id: activeWindow

                anchors.centerIn: parent
                bar: bar
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: {
            const area = root.clickArea(activeWindow);
            root.check(area !== null, "Click-to-open must remain available when the hover popout is disabled");
            if (area) {
                area.clicked(null);
                root.check(bar.popouts.hasCurrent && bar.popouts.currentName === "activewindow", "Click must open the active-window popout");
                area.clicked(null);
                root.check(!bar.popouts.hasCurrent, "Second click must close the active-window popout");
            }
            Hypr.activeToplevel.title = root.shortTitles[0];
            shortTitleTimer.start();
        }
    }

    Timer {
        id: shortTitleTimer

        interval: 100
        repeat: true
        onTriggered: {
            root.check(root.readableTitle(activeWindow, root.shortTitles[root.shortTitleIndex]) && !root.truncatedTitle(activeWindow), "Short title must be displayed in full: " + root.shortTitles[root.shortTitleIndex]);
            root.shortTitleIndex++;
            if (root.shortTitleIndex === root.shortTitles.length) {
                stop();
                Hypr.activeToplevel.title = "Title probe 1";
                updatesTimer.start();
                return;
            }
            Hypr.activeToplevel.title = root.shortTitles[root.shortTitleIndex];
        }
    }

    Timer {
        id: updatesTimer

        interval: 100
        repeat: true
        onTriggered: {
            root.check(root.readableTitle(activeWindow, "Title probe " + (root.updates + 1)), "Rapid title updates must remain fully opaque and current");
            root.updates++;
            if (root.updates === 8) {
                stop();
                Hypr.activeToplevel.title = "Long window title ".repeat(100);
                longTitleTimer.start();
                return;
            }
            Hypr.activeToplevel.title = "Title probe " + (root.updates + 1);
        }
    }

    Timer {
        id: longTitleTimer

        interval: 100
        onTriggered: {
            root.check(activeWindow.width > 0 && activeWindow.width <= bar.width, "Long titles must stay within the available bar width");
            root.check(root.truncatedTitle(activeWindow), "Long titles must be elided");
            console.log("Active-window failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
