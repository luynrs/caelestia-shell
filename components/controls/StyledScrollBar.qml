import QtQuick
import QtQuick.Templates
import Caelestia.Config
import qs.components
import qs.services

ScrollBar {
    id: root

    required property Flickable flickable
    property bool shouldBeActive

    // Sync nonAnimPosition with Qt's automatic position binding
    // Sync nonAnimPosition with flickable when not animating
    readonly property real nonAnimPosition: Math.max(0, Math.min(1 - size, position))

    onHoveredChanged: {
        if (hovered)
            shouldBeActive = true;
        else
            shouldBeActive = flickable.moving;
    }

    implicitWidth: Tokens.padding.extraSmall

    contentItem: Item {
        anchors.left: parent.left
        anchors.right: parent.right

        StyledRect {
            id: thumb

            anchors.left: parent.left
            anchors.right: parent.right
            y: root.topPadding + (root.size < 1 ? root.nonAnimPosition / (1 - root.size) * (root.availableHeight - height) : 0) - parent.y
            height: Math.min(1, root.size) * root.availableHeight * 0.85
            opacity: {
                if (root.size === 1)
                    return 0;
                if (fullMouse.pressed)
                    return 1;
                if (mouse.containsMouse)
                    return 0.8;
                if (root.policy === ScrollBar.AlwaysOn || root.shouldBeActive)
                    return 0.6;
                return 0;
            }
            radius: Tokens.rounding.full
            color: Colours.palette.m3secondary

            MouseArea {
                id: mouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    Connections {
        function onMovingChanged(): void {
            if (root.flickable.moving)
                root.shouldBeActive = true;
            else
                hideDelay.restart();
        }

        target: root.flickable
    }

    Timer {
        id: hideDelay

        interval: 600
        onTriggered: root.shouldBeActive = root.flickable.moving || root.hovered
    }

    CustomMouseArea {
        id: fullMouse

        function onWheel(event: WheelEvent): void {
            let newPos = root.nonAnimPosition;
            if (event.angleDelta.y > 0)
                newPos = Math.max(0, root.nonAnimPosition - 0.1);
            else if (event.angleDelta.y < 0)
                newPos = Math.min(1 - root.size, root.nonAnimPosition + 0.1);
            // Update flickable position
            // Map scrollbar position [0, 1-size] to contentY [0, maxContentY]
            if (root.flickable) {
                const contentHeight = root.flickable.contentHeight;
                const height = root.flickable.height;
                if (contentHeight > height) {
                    const maxContentY = contentHeight - height;
                    const maxPos = 1 - root.size;
                    const contentY = maxPos > 0 ? (newPos / maxPos) * maxContentY : 0;
                    root.flickable.contentY = root.flickable.originY + Math.max(0, Math.min(maxContentY, contentY));
                }
            }
        }

        anchors.fill: parent
        preventStealing: true

        onPressed: event => {
            const newPos = Math.max(0, Math.min(1, (event.y - root.topPadding - thumb.height / 2) / (root.availableHeight - thumb.height))) * (1 - root.size);
            // Update flickable position
            // Map scrollbar position [0, 1-size] to contentY [0, maxContentY]
            if (root.flickable) {
                const contentHeight = root.flickable.contentHeight;
                const height = root.flickable.height;
                if (contentHeight > height) {
                    const maxContentY = contentHeight - height;
                    const maxPos = 1 - root.size;
                    const contentY = maxPos > 0 ? (newPos / maxPos) * maxContentY : 0;
                    root.flickable.contentY = root.flickable.originY + Math.max(0, Math.min(maxContentY, contentY));
                }
            }
        }

        onPositionChanged: event => {
            const newPos = Math.max(0, Math.min(1, (event.y - root.topPadding - thumb.height / 2) / (root.availableHeight - thumb.height))) * (1 - root.size);
            // Update flickable position
            // Map scrollbar position [0, 1-size] to contentY [0, maxContentY]
            if (root.flickable) {
                const contentHeight = root.flickable.contentHeight;
                const height = root.flickable.height;
                if (contentHeight > height) {
                    const maxContentY = contentHeight - height;
                    const maxPos = 1 - root.size;
                    const contentY = maxPos > 0 ? (newPos / maxPos) * maxContentY : 0;
                    root.flickable.contentY = root.flickable.originY + Math.max(0, Math.min(maxContentY, contentY));
                }
            }
        }
    }
}
