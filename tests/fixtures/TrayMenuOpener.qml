import QtQuick
import Quickshell

QtObject {
    id: root

    required property QtObject menu
    readonly property ScriptModel children: ScriptModel {
        values: root.menu.entries
    }

    Component.onCompleted: root.menu.openerInstances++
}
