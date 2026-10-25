pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property var modelData

    signal copyRequested

    implicitHeight: Tokens.sizes.launcher.itemHeight

    StateLayer {
        radius: Tokens.rounding.large
        disabled: Clipboard.busy
        onClicked: root.copyRequested()
    }

    Item {
        id: leading

        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.medium
        anchors.verticalCenter: parent.verticalCenter
        width: icon.implicitWidth
        height: width

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            text: root.modelData.isImage ? "image" : "content_copy"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.builders.large.scale(1.3).build()
            visible: !thumbnail.active || (thumbnail.item as Image)?.status !== Image.Ready
        }

        Loader {
            id: thumbnail

            anchors.fill: parent
            active: root.modelData.isImage

            sourceComponent: Image {
                id: image

                readonly property string previewFile: `${Clipboard.previewDirectory}/${root.modelData.id}.${root.modelData.imageFormat}`

                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(width, height)

                Process {
                    running: true
                    command: ["bash", "-c", 'umask 077; mkdir -p "$1" || exit; preview=$(mktemp "$1/.preview.XXXXXX") || exit; trap \'rm -f -- "$preview"\' EXIT; cliphist decode "$2" > "$preview" && mv -f -- "$preview" "$3"', "caelestia-clipboard-preview", Clipboard.previewDirectory, root.modelData.id, image.previewFile]
                    onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
                        if (exitCode === 0 && exitStatus === 0)
                            image.source = "file://" + image.previewFile;
                    }
                }
            }
        }
    }

    Column {
        anchors.left: leading.right
        anchors.leftMargin: Tokens.spacing.medium
        anchors.right: removeButton.left
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.modelData.isImage ? Tr.tr("Image") : root.modelData.preview
            textFormat: Text.PlainText
            font: Tokens.font.body.medium
            wrapMode: Text.Wrap
            maximumLineCount: root.modelData.isImage ? 1 : 2
            elide: Text.ElideRight
        }

        StyledText {
            visible: root.modelData.isImage
            text: `${root.modelData.imageFormat.toUpperCase()}  ${root.modelData.dimensions.replace("x", " x ")}`
            textFormat: Text.PlainText
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }
    }

    IconButton {
        id: removeButton

        anchors.right: parent.right
        anchors.rightMargin: Tokens.padding.medium
        anchors.verticalCenter: parent.verticalCenter
        icon: "delete"
        type: IconButton.Text
        enabled: !Clipboard.busy
        onClicked: Clipboard.remove(root.modelData)
    }
}
