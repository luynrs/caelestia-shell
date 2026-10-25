import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    id: root

    property int failures: 0
    property int phase: 0
    property int copies: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Connections {
        function onCopied(): void {
            root.copies++;
        }

        target: typeof Clipboard === "undefined" ? null : Clipboard
    }

    Process {
        id: cacheCheck

        onExited: code => root.check(code === 0, "Preview cache check failed: " + command[1])
        // qmllint disable signal-handler-parameters
    }

    Timer {
        interval: 30
        running: true
        repeat: true

        onTriggered: {
            if (typeof Clipboard === "undefined") {
                root.check(false, "Clipboard history service must be available");
                Qt.exit(1);
                return;
            }
            if (Clipboard.busy || cacheCheck.running)
                return;

            switch (root.phase++) {
            case 0:
                root.check(Clipboard.entries.length === 0, "History must load only on request");
                Clipboard.refresh();
                root.check(Clipboard.loading && Clipboard.busy, "Refresh must expose its pending state");
                break;
            case 1:
                root.check(!Clipboard.error && Clipboard.entries.length === 8, "Only valid TSV records must be loaded");
                root.check(Clipboard.entries[0].id === "9007199254740993", "IDs must retain their exact string representation");
                root.check(Clipboard.entries[0].isImage && Clipboard.entries[0].imageFormat === "png" && Clipboard.entries[0].dimensions === "32x24", "PNG metadata must be parsed from cliphist binary tags");
                root.check(Clipboard.entries[1].preview === "Привет WORLD\tindented", "Preview text must preserve Unicode and tabs after the ID separator");
                root.check(Clipboard.entries[4].isImage && Clipboard.entries[4].imageFormat === "jpeg" && Clipboard.entries[4].dimensions === "48x32", "JPEG metadata must retain its format and dimensions");
                root.check(!Clipboard.entries[2].isImage && !Clipboard.entries[5].isImage && !Clipboard.entries[6].isImage, "Text, non-image binary tags, and partial tags must remain text");
                root.check(Clipboard.entries[7].preview === "", "Empty previews must remain valid entries");
                root.check(Clipboard.query("  world ПРИВЕТ  ").length === 1 && Clipboard.query("world ПРИВЕТ")[0].id === "103", "Search must match every term without case sensitivity");
                root.check(Clipboard.query("binary png").map(entry => entry.id).join(",") === "9007199254740993,98", "Search must preserve clipboard chronology");
                root.check(Clipboard.query("  ").length === 8 && Clipboard.query("missing term").length === 0, "Empty and unmatched searches must return the correct records");
                root.check(Clipboard.previewDirectory === Quickshell.env("XDG_RUNTIME_DIR") + "/caelestia-clipboard", "Previews must use the isolated runtime directory");
                cacheCheck.exec(["clipboard-cache-check", "initial"]);
                for (const invalidId of ["", "-1", "1;touch injected", "$(touch injected)", "1\n2", " 1", 12]) {
                    Clipboard.copy({
                        id: invalidId
                    });
                    root.check(!Clipboard.busy && Clipboard.error.length > 0, "Invalid IDs must not start copy commands");
                    Clipboard.remove({
                        id: invalidId
                    });
                    root.check(!Clipboard.busy && Clipboard.error.length > 0, "Invalid IDs must not start delete commands");
                }
                Clipboard.copy(Clipboard.entries[1]);
                root.check(Clipboard.busy && !Clipboard.error, "Copy must clear old errors and expose pending state");
                Clipboard.copy(Clipboard.entries[0]);
                Clipboard.remove(Clipboard.entries[1]);
                Clipboard.refresh();
                break;
            case 2:
                root.check(root.copies === 1 && !Clipboard.error, "Successful text copy must emit copied once");
                Clipboard.copy(Clipboard.entries[0]);
                break;
            case 3:
                root.check(root.copies === 2 && !Clipboard.error, "Successful image copy must emit copied once");
                Clipboard.copy({
                    id: "404",
                    preview: "unused"
                });
                break;
            case 4:
                root.check(root.copies === 2 && Clipboard.error.length > 0, "Decode failure must surface an error without emitting copied");
                Clipboard.copy({
                    id: "13",
                    preview: "unused"
                });
                break;
            case 5:
                root.check(root.copies === 2 && Clipboard.error.length > 0, "wl-copy failure must surface an error without emitting copied");
                Clipboard.remove({
                    id: "405"
                });
                break;
            case 6:
                root.check(Clipboard.error.length > 0 && Clipboard.entries.length === 8, "Failed delete must retain the current history");
                Clipboard.remove(Clipboard.entries[1]);
                root.check(Clipboard.busy && !Clipboard.error, "Delete must clear old errors and expose pending state");
                break;
            case 7:
                root.check(!Clipboard.error && Clipboard.entries.length === 7 && !Clipboard.entries.some(entry => entry.id === "103"), "Successful delete must refresh the history");
                root.check(root.copies === 2, "Delete must not emit copied");
                Clipboard.remove(Clipboard.entries[0]);
                break;
            case 8:
                root.check(!Clipboard.error && Clipboard.entries.length === 6 && !Clipboard.entries.some(entry => entry.id === "9007199254740993"), "Successful image delete must refresh the history");
                Clipboard.refresh();
                break;
            case 9:
                root.check(Clipboard.error.length > 0 && Clipboard.entries.length === 6, "Failed refresh must retain the last successful history");
                cacheCheck.exec(["clipboard-cache-check", "failed"]);
                break;
            case 10:
                Clipboard.refresh();
                break;
            case 11:
                root.check(!Clipboard.error && Clipboard.entries.length === 0, "A cliphist database with no stored entries must show empty history");
                cacheCheck.exec(["clipboard-cache-check", "empty"]);
                Clipboard.refresh();
                break;
            case 12:
                root.check(!Clipboard.error && Clipboard.entries.length === 0, "An empty successful list must clear old entries");
                console.log("Clipboard backend failures:", root.failures);
                Qt.exit(root.failures === 0 ? 0 : 1);
            }
        }
    }
}
