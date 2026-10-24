import QtQuick

QtObject {
    property var entries: []
    property bool isSeparator: false
    property bool enabled: true
    property string text: "Open"
    property string icon
    property int buttonType: 0
    property int checkState: Qt.Unchecked
    property int openerInstances: 0
    property bool hasChildren: entries.length > 0

    signal triggered
}
