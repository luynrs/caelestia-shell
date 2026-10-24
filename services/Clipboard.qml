pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var entries: []
    property bool loading: false
    readonly property bool busy: loading || actionProcess.operation.length > 0 || cleanupProcess.running
    property string error: ""
    readonly property string previewDirectory: Quickshell.env("XDG_RUNTIME_DIR") + "/caelestia-clipboard"

    signal copied()

    function refresh(): void {
        if (busy)
            return;
        error = "";
        loading = true;
        listProcess.running = true;
    }

    function query(search: string): var {
        const terms = search.trim().toLowerCase().split(/\s+/);
        return entries.filter(entry => terms.every(term => entry.preview.toLowerCase().includes(term)));
    }

    function copy(entry: var): void {
        if (busy)
            return;
        if (!entry || typeof entry.id !== "string" || !/^\d+$/.test(entry.id)) {
            error = "Invalid clipboard entry";
            return;
        }
        error = "";
        actionProcess.operation = "copy";
        actionProcess.exec(["bash", "-c", `clipboard_file=$(mktemp -- "$2/caelestia-clipboard-copy.XXXXXXXXXX") || exit 1; trap 'rm -f -- "$clipboard_file"' EXIT; trap 'exit 1' HUP INT TERM; cliphist decode "$1" > "$clipboard_file" && wl-copy < "$clipboard_file"`, "caelestia-clipboard-copy", entry.id, Quickshell.env("XDG_RUNTIME_DIR")]);
    }

    function remove(entry: var): void {
        if (busy)
            return;
        if (!entry || typeof entry.id !== "string" || !/^\d+$/.test(entry.id)) {
            error = "Invalid clipboard entry";
            return;
        }
        error = "";
        actionProcess.operation = "delete";
        actionProcess.exec(["bash", "-o", "pipefail", "-c", 'printf "%s\\n" "$1" | cliphist delete', "caelestia-clipboard-delete", entry.id]);
    }

    Process {
        id: listProcess

        command: ["cliphist", "-preview-width", "400", "list"]
        stdout: StdioCollector {
            id: listOutput
        }
        stderr: StdioCollector {
            id: listError
        }
        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            if (exitCode === 0 && exitStatus === 0) {
                const entries = [];
                for (const line of listOutput.text.split("\n")) {
                    const separator = line.indexOf("\t");
                    if (separator < 1 || !/^\d+$/.test(line.slice(0, separator)))
                        continue;
                    const preview = line.slice(separator + 1);
                    const image = preview.match(/^\[\[ binary data \d+ (?:B|KiB|MiB) (png|jpeg|gif|bmp|tiff) (\d+x\d+) \]\]$/);
                    entries.push({
                        id: line.slice(0, separator),
                        preview,
                        isImage: image !== null,
                        imageFormat: image ? image[1] : "",
                        dimensions: image ? image[2] : ""
                    });
                }
                root.entries = entries;
            } else if (listError.text.includes("please store something first")) {
                root.entries = [];
            } else {
                root.error = "Could not load clipboard history";
            }
            if (root.error.length === 0)
                cleanupProcess.exec(["bash", "-c", `
                    [[ -d $1 && ! -L $1 ]] || exit 0
                    cd -- "$1" || exit 0
                    shift
                    declare -A expected=()
                    for filename; do expected["$filename"]=1; done
                    obsolete=()
                    for filename in *; do
                        if [[ -f $filename && ! -L $filename && $filename =~ ^[0-9]+\\.(png|jpeg|gif|bmp|tiff)$ && ! -v expected[$filename] ]]; then
                            obsolete+=("$filename")
                        fi
                    done
                    rm -f -- "\${obsolete[@]}"
                `, "caelestia-clipboard-cleanup", root.previewDirectory, ...root.entries.filter(entry => entry.isImage).map(entry => `${entry.id}.${entry.imageFormat}`)]);
            root.loading = false;
        }
        onRunningChanged: {
            if (!running && root.loading) {
                root.loading = false;
                root.error = "Could not start clipboard history";
            }
        }
    }

    Process {
        id: cleanupProcess
    }

    Process {
        id: actionProcess

        property string operation: ""

        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            const operation = actionProcess.operation;
            actionProcess.operation = "";
            if (exitCode !== 0 || exitStatus !== 0) {
                root.error = operation === "copy" ? "Could not copy clipboard entry" : "Could not delete clipboard entry";
            } else if (operation === "copy") {
                root.copied();
            } else {
                root.refresh();
            }
        }
        onRunningChanged: {
            if (!running && operation.length > 0) {
                root.error = operation === "copy" ? "Could not start clipboard copy" : "Could not start clipboard delete";
                operation = "";
            }
        }
    }
}
