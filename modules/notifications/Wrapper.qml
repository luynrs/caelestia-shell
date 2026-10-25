import QtQuick
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property Item sidebarPanel
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias maxHeight: content.maxHeight

    visible: height > 0
    anchors.bottomMargin: -5
    implicitWidth: Math.max(sidebarPanel.width, content.implicitWidth)
    implicitHeight: content.implicitHeight

    Content {
        id: content

        anchors.bottomMargin: -root.anchors.bottomMargin
        screenState: root.screenState
    }
}
