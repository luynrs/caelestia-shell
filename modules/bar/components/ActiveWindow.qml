pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    required property var bar
    property color colour: Colours.palette.m3primary

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return Tr.trCtx("Desktop", "shown when no window is focused");
        if (Config.bar.activeWindow.compact) {
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property int maxWidth: {
        const center = bar.width / 2;
        let available = center - bar.hPadding;
        for (const entry of bar.children) {
            if (!entry.entryId || entry.entryId === "spacer")
                continue;
            const distance = entry.x >= center ? entry.x - center : center - entry.x - entry.width;
            available = Math.min(available, distance - bar.spacing);
        }
        return Math.max(0, available * 2);
    }

    clip: true
    implicitWidth: Math.min(Math.ceil(metrics.advanceWidth), maxWidth)
    implicitHeight: title.implicitHeight

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.mapToItem(root.bar, root.implicitWidth / 2, 0).x;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font: root.Tokens.font.body.builders.small.letterSpacing(1.4).build()
        renderType: title.renderType
    }

    StyledText {
        id: title

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        text: metrics.text
        font: metrics.font
        color: root.colour
        horizontalAlignment: Text.AlignHCenter

        width: root.width
        elide: Text.ElideRight
    }
}
