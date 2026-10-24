pragma Singleton

import QtQuick
import Quickshell

Singleton {
    signal configReloaded

    property QtObject activeToplevel: QtObject {
        property string title: "Title probe 0"
    }

    readonly property bool usingLua: false
    readonly property QtObject extras: QtObject {
        function batchMessage(messages: var): void {}
    }
}
