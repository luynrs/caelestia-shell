import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.daemons as Daemons

ShellRoot {
    id: root

    property int failures: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Daemons.Shortcuts {
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
            const calculator = ShellState.shortcuts.find(shortcut => shortcut.name === "calculator");
            root.check(calculator !== undefined, "Calculator shortcut must be registered");
            if (calculator) {
                state.dashboard = true;
                calculator.pressed();
                root.check(state.launcher && !state.dashboard, "Calculator shortcut must open the launcher exclusively");
                root.check(state.launcherQuery === `${GlobalConfig.launcher.actionPrefix}calc `, "Calculator shortcut must use the configured command prefix");
                state.launcherQuery += "1 + 2";
                calculator.pressed();
                root.check(!state.launcher && state.launcherQuery === "", "Calculator shortcut must close an active calculation and clear its query");
                state.launcherQuery = `${GlobalConfig.launcher.actionPrefix}clipboard `;
                state.launcher = true;
                calculator.pressed();
                root.check(state.launcher && state.launcherQuery === `${GlobalConfig.launcher.actionPrefix}calc `, "Calculator shortcut must switch clipboard history into calculator mode");
            }
            console.log("Clipboard shortcut failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
