import QtQuick
import Quickshell
import qs.modules.launcher.items

ShellRoot {
    id: root

    property int failures: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    function findImage(parent: Item): Image {
        if (parent as Image)
            return parent as Image;
        for (const child of parent.children) {
            const image = findImage(child);
            if (image)
                return image;
        }
        return null;
    }

    Item {
        width: 600
        height: 300

        ClipboardItem {
            id: card

            width: parent.width
            modelData: ({
                    id: "201",
                    preview: "[[ binary data 71 B png 2x1 ]]",
                    isImage: true,
                    imageFormat: "png",
                    dimensions: "2x1"
                })
        }
    }

    Timer {
        interval: 800
        running: true
        onTriggered: {
            const image = root.findImage(card);
            root.check(image !== null && image.status === Image.Ready, "Clipboard image card must decode and load its preview");
            if (image) {
                root.check(image.sourceSize.width <= 112 && image.sourceSize.height <= 76, "Clipboard image preview must use bounded decode dimensions");
                root.check(image.source.toString().startsWith("file://" + Quickshell.env("XDG_RUNTIME_DIR")), "Clipboard preview files must stay in the private runtime directory");
            }
            root.check(card.height > 0 && card.width === 600, "Clipboard image card must keep launcher geometry");
            console.log("Clipboard preview failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
