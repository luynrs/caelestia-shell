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
        launcherQuery: ">clipboard beta"
        launcher: true
    }

    Item {
        id: stage
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
        interval: 40
        running: true
        onTriggered: root.check(root.findItem(launcher, "launcherClipboardList") !== null, "Clipboard shortcut must initialize history without flashing the app list")
    }

    Timer {
        interval: 700
        running: true
        onTriggered: {
            const search = root.findItem(launcher, "launcherSearch");
            const list = root.findItem(launcher, "launcherClipboardList");
            root.check(search !== null && search.text === ">clipboard beta", "Clipboard shortcut query must initialize the launcher");
            root.check(list !== null && list.count === 1, "Delayed copy must start from filtered history");
            if (search && list)
                search.accepted();
            dismissTimer.start();
        }
    }

    Timer {
        id: dismissTimer
        interval: 40
        onTriggered: {
            state.launcher = false;
            state.launcherQuery = ">clipboard alpha";
            state.launcher = true;
            reopenedTimer.start();
        }
    }

    Timer {
        id: reopenedTimer
        interval: 450
        onTriggered: {
            root.check(state.launcher && state.launcherQuery === ">clipboard alpha", "A completed old copy must not close newly opened clipboard history");
            const list = root.findItem(launcher, "launcherClipboardList");
            root.check(list !== null && list.count === 1 && list.currentItem.modelData.id === "101", "Reopened clipboard history must retain its new search");
            state.dashboard = true;
            console.log("Clipboard dismissal failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
