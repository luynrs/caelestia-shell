import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root

    property int failures: 0
    readonly property string directory: Quickshell.env("XDG_CACHE_HOME") + "/"

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Connections {
        function onShowPreviewChanged(): void {
            if (Colours.showPreview && Wallpapers.previewPath === root.directory + "second")
                root.check(Colours.preview.m3primary.toString() === "#0000ff", "An obsolete wallpaper response must not flash its palette");
        }

        target: Colours
    }

    Timer {
        interval: 200
        running: true
        onTriggered: {
            Colours.scheme = "dynamic";
            Wallpapers.preview(root.directory + "first");
            replacement.start();
        }
    }

    Timer {
        id: replacement

        interval: 40
        onTriggered: {
            Wallpapers.preview(root.directory + "second");
            latest.start();
        }
    }

    Timer {
        id: latest

        interval: 500
        onTriggered: {
            root.check(Colours.showPreview && Colours.preview.m3primary.toString() === "#0000ff", "Only the latest wallpaper may supply preview colours");
            Wallpapers.stopPreview();
            Wallpapers.preview(root.directory + "closing");
            dismissal.start();
        }
    }

    Timer {
        id: dismissal

        interval: 40
        onTriggered: {
            Wallpapers.stopPreview();
            closed.start();
        }
    }

    Timer {
        id: closed

        interval: 350
        onTriggered: {
            root.check(!Colours.showPreview && !Wallpapers.showPreview, "A pending preview must not restore colours after dismissal");
            Wallpapers.preview(root.directory + "failure");
            failed.start();
        }
    }

    Timer {
        id: failed

        interval: 300
        onTriggered: {
            root.check(!Colours.showPreview, "A failed preview must not activate a stale palette");
            Wallpapers.stopPreview();
            console.log("Wallpaper preview failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
