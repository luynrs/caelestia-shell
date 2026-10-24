pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.items

StyledListView {
    id: root

    required property SearchBar search
    required property ScreenState screenState
    property string displayText
    property bool waitingForCopy

    function syncDisplayText(): void {
        const command = `${GlobalConfig.launcher.actionPrefix}clipboard`;
        if (screenState.launcher && (search.text === command || search.text.startsWith(command + " ")))
            displayText = search.text;
        else
            waitingForCopy = false;
    }

    function copyEntry(entry: var): void {
        if (Clipboard.busy)
            return;
        waitingForCopy = true;
        Clipboard.copy(entry);
    }

    model: ScriptModel {
        values: Clipboard.query(root.displayText.slice(`${GlobalConfig.launcher.actionPrefix}clipboard`.length))
        onValuesChanged: root.currentIndex = 0
    }

    spacing: Tokens.spacing.small
    implicitHeight: Math.max(0, (Tokens.sizes.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing)
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {}
        }
    }

    delegate: ClipboardItem {
        width: root.width
        onCopyRequested: root.copyEntry(modelData)
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    Component.onCompleted: {
        syncDisplayText();
        Clipboard.refresh();
    }

    Connections {
        target: root.search
        function onTextChanged(): void {
            root.syncDisplayText();
        }
    }

    Connections {
        target: root.screenState
        function onLauncherChanged(): void {
            root.syncDisplayText();
            if (root.screenState.launcher)
                Clipboard.refresh();
        }
    }

    Connections {
        function onCopied(): void {
            if (root.waitingForCopy) {
                root.waitingForCopy = false;
                root.screenState.launcher = false;
            }
        }

        function onErrorChanged(): void {
            if (Clipboard.error)
                root.waitingForCopy = false;
        }

        target: Clipboard
    }
}
