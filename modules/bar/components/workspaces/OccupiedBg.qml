pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var workspaces
    required property int wsSpacing

    readonly property color colour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
    property color colourAnimated: colour

    Behavior on colourAnimated {
        CAnim {}
    }

    // Item wrappers because `layer.enabled` clips the content, and the rects extend 1px outside the parent
    Item {
        anchors.fill: parent
        anchors.margins: -1

        opacity: root.colourAnimated.a
        layer.enabled: opacity < 1 // Forces opacity to apply to children as a single layer

        Item {
            anchors.fill: parent
            anchors.margins: 1

            AnimatedRepeater {
                model: ScriptModel {
                    values: root.workspaces
                }

                removeDuration: Tokens.anim.durations.expressiveDefaultEffects

                OccupiedRect {}
            }
        }
    }

    component OccupiedRect: StyledRect {
        required property int index
        required property Workspace modelData

        property real topRadius: ifAdjacent(0, -1, 0, height / 2)
        property real bottomRadius: ifAdjacent(root.workspaces.length - 1, 1, 0, height / 2)
        property real topPadding: ifAdjacent(0, -1, root.wsSpacing, 0)
        property real bottomPadding: ifAdjacent(root.workspaces.length - 1, 1, root.wsSpacing, 0)

        function ifAdjacent(exclIdx: int, adj: int, yes: real, no: real): real {
            if (AnimatedRepeater.adding || AnimatedRepeater.removing || !modelData?.isOccupied || index === exclIdx)
                return no;
            return root.workspaces[index + adj]?.isOccupied ? yes : no;
        }

        anchors.top: parent?.top
        anchors.bottom: parent?.bottom
        anchors.margins: -1

        x: modelData ? modelData.x + anchors.margins - topPadding : 0
        implicitWidth: modelData ? modelData.width - anchors.margins * 2 + topPadding + bottomPadding : 0

        color: Qt.alpha(root.colour, 1)
        topLeftRadius: topRadius
        topRightRadius: bottomRadius
        bottomLeftRadius: topRadius
        bottomRightRadius: bottomRadius

        opacity: modelData?.isOccupied ? 1 : 0

        Behavior on topRadius {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on bottomRadius {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on topPadding {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on bottomPadding {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
