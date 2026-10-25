import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Images
import Caelestia.Models

ShellRoot {
    id: root

    readonly property string directory: Quickshell.env("CAELESTIA_TEST_DIRECTORY")
    property int failures: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    FileSystemModel {
        id: files

        path: `${root.directory}/walls`
        recursive: true
        watchChanges: true
        filter: FileSystemModel.Files
        nameFilters: ["*.txt"]
    }

    FileView {
        id: addedFile

        path: `${root.directory}/walls/a/added.txt`
        printErrors: false
    }

    ImageAnalyser {
        id: latestImage
    }

    Component {
        id: transientAnalyser

        ImageAnalyser {}
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            root.check(files.entries.length === 3, "Recursive model must load the initial files");
            addedFile.setText("added");
            changedTimer.start();

            for (let index = 0; index < 128; index++) {
                const analyser = transientAnalyser.createObject(root, {
                    source: `${root.directory}/red.ppm`
                });
                analyser.requestUpdate();
                analyser.destroy();
                latestImage.source = `${root.directory}/${index % 2 === 0 ? "red" : "blue"}.ppm`;
                latestImage.requestUpdate();
            }
        }
    }

    Timer {
        id: changedTimer

        interval: 700
        onTriggered: {
            root.check(files.entries.length === 4, "Changing one subdirectory must preserve all other entries");
            root.check(files.entries.some(entry => entry.path.endsWith("/walls/root.txt")), "Root-level files must survive subdirectory changes");
            root.check(files.entries.some(entry => entry.path.endsWith("/walls/b/second.txt")), "Sibling directories must survive subdirectory changes");
            files.path = `${root.directory}/bulk`;
            files.path = "";
            clearedTimer.start();
        }
    }

    Timer {
        id: clearedTimer

        interval: 700
        onTriggered: {
            root.check(files.entries.length === 0, "Clearing the path must cancel pending scans");
            root.check(latestImage.dominantColour.b > 0.9 && latestImage.dominantColour.r < 0.1, "Image analysis must settle on the latest source");
            for (let index = 0; index < 30; index++)
                files.path = `${root.directory}/${index % 2 === 0 ? "bulk" : "walls"}`;
            replacedTimer.start();
        }
    }

    Timer {
        id: replacedTimer

        interval: 700
        onTriggered: {
            root.check(files.entries.length === 4, "Rapid scan replacement must retain only the final directory entries");
            root.check(new Set(files.entries.map(entry => entry.path)).size === 4, "Rapid scan replacement must not duplicate entries");
            root.check(files.entries.every(entry => entry.path.startsWith(`${root.directory}/walls/`)), "Canceled scans must not add entries from previous directories");
            console.log("Plugin model failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
