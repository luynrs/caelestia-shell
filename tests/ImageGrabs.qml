import QtQuick
import QtQuick.Window
import Quickshell
import Caelestia.Images

ShellRoot {
    id: root
    property bool grabbed: false
    property int failures: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Window {
        visible: true
        width: 64
        height: 64

        Rectangle {
            id: redItem
            anchors.fill: parent
            color: "red"
        }
    }

    ImageAnalyser {
        id: analyser
    }

    Timer {
        interval: 250
        running: true
        onTriggered: {
            redItem.grabToImage(result => root.grabbed = result.url.toString().length > 0);
            analyser.sourceItem = redItem;
            analyser.requestUpdate();
            analyser.source = `${Quickshell.env("CAELESTIA_TEST_DIRECTORY")}/blue.ppm`;
            analyser.requestUpdate();
            settledTimer.start();
        }
    }

    Timer {
        id: settledTimer
        interval: 1000
        onTriggered: {
            root.check(root.grabbed, "Item capture must complete for the stale-result test");
            root.check(analyser.dominantColour.b > 0.9 && analyser.dominantColour.r < 0.1, "Old item captures must not replace analysis of a newer source");
            console.log("Image capture failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
