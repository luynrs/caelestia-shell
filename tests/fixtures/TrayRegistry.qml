pragma Singleton

import Quickshell

Singleton {
    id: root

    property var entries: []
    readonly property ScriptModel items: ScriptModel {
        values: root.entries
    }
}
