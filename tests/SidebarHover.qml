import QtQuick
import QtTest
import Quickshell
import qs.modules.drawers as Drawers

ShellRoot {
    id: root

    property int failures: 0
    property int step: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    function move(x: real, y: real): void {
        check(events.mouseMove(window.interactionWrapper, x, y, 0, Qt.NoButton, Qt.NoModifier), "Pointer event must reach the drawer window");
    }

    TestEvent {
        id: events
    }

    Drawers.ContentWindow {
        id: window
        screen: Quickshell.screens[0]
        contentItem.opacity: 0
        mask: Region {}
        Component.onCompleted: {
            const grab = contentItem.data.find(object => object.toString().includes("HyprlandFocusGrab"));
            root.check(grab !== undefined, "The fixture must disable compositor grabs before simulating pointer events");
            if (grab)
                grab.active = false;
        }
    }

    Timer {
        interval: 650
        running: true
        repeat: true
        onTriggered: {
            const state = window.screenState;
            const panels = window.interactionWrapper.panels;
            switch (root.step++) {
            case 0:
                root.move(window.width - 1, 1);
                root.check(!state.sidebar, "Top-right corner must no longer open the sidebar");
                state.sidebar = false;
                break;
            case 1:
                root.move(1, window.height - 1);
                root.check(!state.sidebar, "Bottom-left corner must not be the sidebar trigger");
                state.sidebar = false;
                break;
            case 2:
                root.move(window.width - 1, window.height - 1);
                root.check(state.sidebar, "Bottom-right corner must open the sidebar");
                break;
            case 3:
                root.move(window.width - 20, window.height / 2);
                root.check(state.sidebar, "Entering the right sidebar must keep it open");
                root.check(panels.sidebar.x + panels.sidebar.width >= panels.width - 1, "Sidebar must retain its right-edge position");
                root.check(Math.abs(panels.utilities.y + panels.utilities.height - panels.height) < 1, "Utility cards must retain their bottom position");
                root.check(panels.notifications.y < 1, "Popup notifications must retain their top position");
                break;
            case 4:
                root.move(window.width / 2, window.height / 2);
                root.check(!state.sidebar, "Leaving the right sidebar must close it");
                break;
            case 5:
                root.move(1, window.height - 1);
                root.check(!state.sidebar, "Returning to the bottom-left corner must keep the sidebar closed");
                console.log("Sidebar hover failures:", root.failures);
                Qt.exit(root.failures === 0 ? 0 : 1);
            }
        }
    }
}
