import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules as Modules
import qs.services

ShellRoot {
    id: root

    property int failures: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Modules.Shortcuts {
        id: shortcuts
    }

    Timer {
        interval: 100
        running: true
        onTriggered: {
            const clipboard = ShellState.shortcuts.find(shortcut => shortcut.name === "clipboard");
            const state = ShellState.forActive();
            root.check(clipboard !== undefined, "Clipboard shortcut must be registered");
            if (clipboard) {
                state.dashboard = true;
                clipboard.pressed();
                root.check(state.launcher && !state.dashboard, "Clipboard shortcut must open the launcher exclusively");
                root.check(state.launcherQuery === `${GlobalConfig.launcher.actionPrefix}clipboard `, "Clipboard shortcut must use the configured command prefix");
                state.launcherQuery += "filtered";
                clipboard.pressed();
                root.check(!state.launcher && state.launcherQuery === "", "Clipboard shortcut must close filtered history and clear its query");
                state.launcher = true;
                state.launcherQuery = "app search";
                clipboard.pressed();
                root.check(state.launcher && state.launcherQuery === `${GlobalConfig.launcher.actionPrefix}clipboard `, "Clipboard shortcut must switch an open application search into history");
            }
            console.log("Clipboard shortcut failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
