import QtQuick
import Quickshell
import qs.modules.bar.popouts.kblayout as Keyboard

ShellRoot {
    id: root

    property int attempts: 0
    property int failures: 0
    readonly property bool duplicateLayouts: Quickshell.env("KB_LAYOUT_TEST_SOURCE") === "duplicates"
    readonly property var expectedVisible: duplicateLayouts ? [
        {
            layoutIndex: 0,
            label: "US - English (US)"
        },
        {
            layoutIndex: 1,
            label: "US - English (US)"
        }
    ] : [
        {
            layoutIndex: 0,
            label: "US - English (US)"
        },
        {
            layoutIndex: 2,
            label: "GB - English (UK)"
        },
        {
            layoutIndex: 3,
            label: "ZZ - zz"
        }
    ]

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Keyboard.KbLayoutModel {
        id: layouts

        Component.onCompleted: start()
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (++root.attempts < 40 && (layouts.activeLabel !== "RU - Russian" || layouts.visibleModel.count !== root.expectedVisible.length || layouts.visibleModel.get(0).label !== "US - English (US)"))
                return;
            stop();
            root.check(layouts.activeIndex === (root.duplicateLayouts ? 2 : 1) && layouts.activeLabel === "RU - Russian", "Active layout index must resolve to its XML description: " + layouts.activeIndex + " " + layouts.activeLabel);
            root.check(layouts.visibleModel.count === root.expectedVisible.length, "Only the active group must be excluded, including repeated layout codes");
            if (layouts.visibleModel.count === root.expectedVisible.length) {
                for (let i = 0; i < root.expectedVisible.length; i++) {
                    root.check(layouts.visibleModel.get(i).layoutIndex === root.expectedVisible[i].layoutIndex && layouts.visibleModel.get(i).label === root.expectedVisible[i].label, "Visible group must retain its compositor index and layout description: " + layouts.visibleModel.get(i).layoutIndex + " " + layouts.visibleModel.get(i).label);
                }
            }
            console.log("Keyboard-layout failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
