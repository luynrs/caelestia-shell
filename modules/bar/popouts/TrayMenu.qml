pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

StackView {
    id: root

    required property PopoutState popouts
    required property QsMenuHandle trayItem
    readonly property SubMenu sizingMenu: {
        for (let index = depth - 1; index >= 0; index--) {
            const menu = get(index) as SubMenu;
            if (menu.hasChildren && menu.implicitHeight > menu.padding * 2)
                return menu;
        }
        return null;
    }
    readonly property bool ready: sizingMenu !== null

    implicitWidth: ready ? sizingMenu.implicitWidth : -Tokens.padding.large * 2
    implicitHeight: ready ? sizingMenu.implicitHeight : -Tokens.padding.large * 2

    initialItem: SubMenu {
        handle: root.trayItem
    }

    pushEnter: NoAnim {}
    pushExit: NoAnim {}
    popEnter: NoAnim {}
    popExit: NoAnim {}

    Component {
        id: subMenuComp

        SubMenu {}
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: Column {
        id: menu

        required property QsMenuHandle handle
        readonly property bool hasChildren: menuOpener.children.values.some(e => !e.isSeparator)
        property bool isSubMenu
        property bool shown

        padding: Tokens.padding.small
        spacing: Tokens.spacing.small

        opacity: shown ? 1 : 0

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        QsMenuOpener {
            id: menuOpener

            menu: menu.handle
        }

        Repeater {
            model: menuOpener.children

            StyledRect {
                id: item

                required property QsMenuEntry modelData

                implicitWidth: Tokens.sizes.bar.trayMenuWidth
                implicitHeight: modelData.isSeparator ? 1 : children.implicitHeight

                radius: Tokens.rounding.full
                color: modelData.isSeparator ? Colours.palette.m3outlineVariant : "transparent"

                Loader {
                    id: children

                    anchors.left: parent.left
                    anchors.right: parent.right

                    active: !item.modelData.isSeparator

                    sourceComponent: Item {
                        implicitHeight: label.implicitHeight

                        StateLayer {
                            anchors.margins: -Tokens.padding.extraSmall / 2
                            anchors.leftMargin: -Tokens.padding.small
                            anchors.rightMargin: -Tokens.padding.small

                            radius: item.radius
                            disabled: !item.modelData.enabled

                            onClicked: {
                                const entry = item.modelData;
                                if (entry.hasChildren)
                                    root.push(subMenuComp.createObject(null, {
                                        handle: entry,
                                        isSubMenu: true
                                    }));
                                else {
                                    item.modelData.triggered();
                                    root.popouts.hasCurrent = false;
                                }
                            }
                        }

                        Loader {
                            id: icon

                            anchors.left: parent.left

                            active: item.modelData.icon !== ""

                            sourceComponent: IconImage {
                                asynchronous: true
                                implicitSize: label.implicitHeight

                                source: item.modelData.icon
                            }
                        }

                        StyledText {
                            id: label

                            anchors.left: icon.right
                            anchors.leftMargin: icon.active ? Tokens.spacing.medium : 0

                            text: labelMetrics.elidedText
                            color: item.modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                        }

                        TextMetrics {
                            id: labelMetrics

                            text: item.modelData.text
                            font: label.font

                            elide: Text.ElideRight
                            elideWidth: root.Tokens.sizes.bar.trayMenuWidth - (icon.active ? icon.implicitWidth + label.anchors.leftMargin : 0) - (expand.active ? expand.implicitWidth + root.Tokens.spacing.medium : 0)
                        }

                        Loader {
                            id: expand

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right

                            active: item.modelData.hasChildren

                            sourceComponent: MaterialIcon {
                                text: "chevron_right"
                                color: item.modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                            }
                        }
                    }
                }
            }
        }

        Loader {
            active: menu.isSubMenu

            sourceComponent: Item {
                implicitWidth: back.implicitWidth
                implicitHeight: back.implicitHeight + Tokens.spacing.extraSmall

                Item {
                    anchors.bottom: parent.bottom
                    implicitWidth: back.implicitWidth
                    implicitHeight: back.implicitHeight

                    StyledRect {
                        anchors.fill: parent
                        anchors.margins: -Tokens.padding.extraSmall / 2
                        anchors.leftMargin: -Tokens.padding.small
                        anchors.rightMargin: -Tokens.padding.large

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3secondaryContainer

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onSecondaryContainer
                            onClicked: root.pop()
                        }
                    }

                    Row {
                        id: back

                        anchors.verticalCenter: parent.verticalCenter

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "chevron_left"
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tr.trCtx("Back", "button")
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }
            }
        }
    }
}
