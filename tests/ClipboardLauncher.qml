import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.launcher as Launcher
import qs.modules.launcher.services as LauncherServices

ShellRoot {
    id: root
    property int failures: 0
    property var search
    property var historyList

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

    ScreenState {
        id: state
        modelData: Quickshell.screens[0]
        launcher: true
    }

    PanelWindow {
        id: window
        implicitWidth: 1280
        implicitHeight: 720
        color: "transparent"
        exclusiveZone: 0
        mask: Region {}
        contentItem.opacity: 0
    }

    Item {
        id: stage
        parent: window.contentItem
        width: 1280
        height: 720

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
        interval: 700
        running: true
        onTriggered: {
            root.search = root.findItem(launcher, "launcherSearch");
            root.check(root.search !== null, "Launcher search must load");
            root.check(LauncherServices.Actions.query(">clip").some(action => action.command[1] === "clipboard"), "Clipboard command must be discoverable in launcher actions");
            root.search.text = ">clipboard ";
            clipboardTimer.start();
        }
    }

    Timer {
        id: clipboardTimer
        interval: 700
        onTriggered: {
            const list = root.findItem(launcher, "launcherClipboardList");
            root.check(list !== null, "Clipboard command must open history inside the launcher");
            root.check(typeof state.launcherQuery === "string" && state.launcherQuery === root.search.text, "Launcher query must stay synchronized for shortcut entry");
            if (list) {
                root.check(list.count === 2, "Clipboard cards must expose fixture history");
                root.check(list.width > 0 && list.width <= launcher.width, "History must fit the existing launcher width");
                root.check(list.height <= stage.height, "History must fit the available screen height");
            }
            root.search.text = ">clipboard beta";
            filteredTimer.start();
        }
    }

    Timer {
        id: filteredTimer
        interval: 300
        onTriggered: {
            const list = root.findItem(launcher, "launcherClipboardList");
            root.check(list !== null && list.count === 1, "Clipboard search must filter history");
            if (list) {
                root.historyList = list;
                root.search.accepted();
                copiedTimer.start();
            } else {
                console.log("Clipboard launcher failures:", root.failures);
                Qt.exit(1);
            }
        }
    }

    Timer {
        id: closingTimer
        interval: 16
        repeat: true
        onTriggered: {
            if (state.launcher || !launcher.visible) {
                stop();
                return;
            }
            root.check(root.findItem(launcher, "launcherAppList") === null, "Closing clipboard history must not instantiate an app list");
            root.check(!state.launcher, "Successful copy must begin closing history");
            root.check(root.historyList !== null && root.historyList.count === 1, "Filtered history must retain its displayed entries during closing");
        }
    }

    Connections {
        target: Clipboard
        function onCopied(): void {
            closingTimer.start();
        }
    }

    Timer {
        id: copiedTimer
        interval: 650
        onTriggered: {
            root.check(!state.launcher, "Copying from history must close the launcher after success");
            root.check(state.launcherQuery === "", "Closing history must reset the next regular launcher query");
            state.launcherQuery = ">clipboard alpha";
            state.launcher = true;
            reopenedTimer.start();
        }
    }

    Timer {
        id: reopenedTimer
        interval: 700
        onTriggered: {
            const list = root.findItem(launcher, "launcherClipboardList");
            const search = root.findItem(launcher, "launcherSearch");
            root.check(search !== null && search.text === ">clipboard alpha", "Shortcut query must survive launcher creation");
            root.check(list !== null && list.count === 1 && list.currentItem.modelData.id === "101", "Shortcut query must select the matching history entry");
            state.dashboard = true;
            root.check(!state.launcher && state.dashboard && state.launcherQuery === "", "Dashboard must dismiss clipboard history exclusively");
            console.log("Clipboard launcher failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
