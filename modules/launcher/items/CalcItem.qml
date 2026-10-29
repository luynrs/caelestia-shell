import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    required property var list
    readonly property string math: list.search.text.slice(`${GlobalConfig.launcher.actionPrefix}calc `.length)

    function onClicked(): void {
        Quickshell.execDetached(["wl-copy", Qalculator.rawResult]);
        root.list.screenState.launcher = false;
    }

    onMathChanged: {
        if (math.length > 0)
            Qalculator.evalAsync(math);
    }

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.onClicked()
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.medium

        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: "function"
            fontStyle: Tokens.font.icon.extraLarge
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            id: result

            color: {
                if (text.includes("error: ") || text.includes("warning: "))
                    return Colours.palette.m3error;
                if (!root.math)
                    return Colours.palette.m3onSurfaceVariant;
                return Colours.palette.m3onSurface;
            }

            text: root.math.length > 0 ? (Qalculator.result ? Tr.trMarked(Qalculator.result) : Tr.tr("Calculating...")) : Tr.tr("Type an expression to calculate")
            elide: Text.ElideLeft

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
