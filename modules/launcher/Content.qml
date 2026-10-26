pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property ScreenState screenState
    required property var panels
    required property real maxHeight

    readonly property int padding: Tokens.padding.large

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: search.height + listWrapper.height + padding + search.anchors.bottomMargin

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: search.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            screenState: root.screenState
            panels: root.panels
            maxHeight: Math.max(0, root.maxHeight - search.implicitHeight - root.padding * 3)
            search: search
        }
    }

    SearchBar {
        id: search

        objectName: "launcherSearch"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        anchors.bottomMargin: CUtils.clamp(root.padding - Config.border.thickness, 0, root.padding)

        topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
        bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

        placeholderText: Tr.tr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)
        text: root.screenState.launcherQuery

        onTextChanged: root.screenState.launcherQuery = text

        onAccepted: {
            const currentItem = list.currentList?.currentItem;
            if (currentItem) {
                if (list.showClipboard) {
                    list.currentList.copyEntry(currentItem.modelData);
                } else if (list.showWallpapers) {
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(currentItem.modelData.path);
                    root.screenState.launcher = false;
                } else if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                    if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    Apps.launch(currentItem.modelData);
                    root.screenState.launcher = false;
                }
            }
        }

        Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
        Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

        Keys.onEscapePressed: root.screenState.launcher = false

        Keys.onDeletePressed: event => {
            if (list.showClipboard) {
                const item = list.currentList?.currentItem;
                if (item)
                    Clipboard.remove(item.modelData);
            } else {
                event.accepted = false;
            }
        }

        Keys.onPressed: event => {
            if (!GlobalConfig.launcher.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                list.currentList?.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                list.currentList?.decrementCurrentIndex();
                event.accepted = true;
            }
        }

        Component.onCompleted: forceActiveFocus()

        Connections {
            function onLauncherQueryChanged(): void {
                if (search.text !== root.screenState.launcherQuery) {
                    search.text = root.screenState.launcherQuery;
                    search.cursorPosition = search.length;
                }
            }

            function onLauncherChanged(): void {
                if (!root.screenState.launcher)
                    search.text = "";
            }

            function onSessionChanged(): void {
                if (!root.screenState.session)
                    search.forceActiveFocus();
            }

            target: root.screenState
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: search.top
        anchors.bottomMargin: Tokens.spacing.extraSmall

        visible: list.showClipboard && Clipboard.error.length > 0
        text: Clipboard.error
        textFormat: Text.PlainText
        color: Colours.palette.m3error
        font: Tokens.font.body.small
    }
}
