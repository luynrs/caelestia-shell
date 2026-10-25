import QtQuick
import QtTest
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.State
import qs.components.controls as Controls
import qs.services
import qs.modules.drawers as Drawers

ShellRoot {
    id: root

    property int failures: 0
    property int step: 0
    property int closingSamples: 0
    property int fullscreenSamples: 0
    property point notificationCorner

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    function move(x: real, y: real): void {
        check(events.mouseMove(window.interactionWrapper, x, y, 0, Qt.NoButton, Qt.NoModifier), "Pointer event must reach the drawer window");
    }

    function findItem(parent: Item, name: string): Item {
        if (parent.objectName === name)
            return parent;
        for (const child of parent.children) {
            const found = findItem(child, name);
            if (found)
                return found;
        }
        return null;
    }

    function findToggle(parent: Item): Controls.IconButton {
        const button = parent as Controls.IconButton;
        if (button?.icon === "notifications_off")
            return button;
        for (const child of parent.children) {
            const found = findToggle(child);
            if (found)
                return found;
        }
        return null;
    }

    Component {
        id: notificationComponent

        NotifData {
            popup: true
            hints: ({})
            summary: "Popup placement regression"
            body: "Notifications must remain inside the available lower-right area."
            expireTimeout: 60000
        }
    }

    TestEvent {
        id: events
    }

    Drawers.ContentWindow {
        id: window

        screen: Quickshell.screens[0]
        contentItem.opacity: 0
    }

    Timer {
        id: closingProbe

        interval: 16
        repeat: true
        onTriggered: {
            const panels = window.interactionWrapper.panels;
            if (!panels.sidebar.visible) {
                stop();
                return;
            }
            const popup = panels.notifications;
            const toast = panels.toasts;
            if (popup.height <= 0 || toast.height <= 0)
                return;
            root.closingSamples++;
            const overlapWidth = Math.min(popup.x + popup.width, toast.x + toast.width) - Math.max(popup.x, toast.x);
            const overlapHeight = Math.min(popup.y + popup.height, toast.y + toast.height) - Math.max(popup.y, toast.y);
            if (overlapWidth > 2 && overlapHeight > 2) {
                root.check(false, "A popup arriving during sidebar dismissal must not overlap internal toasts");
                stop();
            }
        }
    }

    Timer {
        interval: 16
        running: root.step === 11 || root.step === 12
        repeat: true
        onTriggered: {
            const popup = window.interactionWrapper.panels.notifications;
            const corner = popup.mapToItem(window.contentItem, popup.width, popup.height);
            root.fullscreenSamples++;
            root.check(Math.abs(corner.y - root.notificationCorner.y) < 1 && Math.abs(corner.x - root.notificationCorner.x) < 1, "Fullscreen transitions must preserve the popup's lower-right position: " + corner + " instead of " + root.notificationCorner);
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
                root.check(panels.sidebar.height >= 0, "Closed sidebar geometry must remain nonnegative");
                root.move(window.width - 1, 1);
                root.check(!state.sidebar, "Top-right corner must no longer open the sidebar");
                state.sidebar = false;
                GlobalConfig.appearance.deformScale = 0;
                Notifs.list = [notificationComponent.createObject(root)];
                Toaster.toast("Toast placement regression", "Internal messages must not cover notifications", "info", Toast.Info, 10000);
                break;
            case 1:
                root.check(panels.notifications.height > 0, "The placement fixture must show a popup");
                root.check(Math.abs(panels.notifications.y + panels.notifications.height - panels.height - 5) < 1, "Popup notifications must stay anchored to the bottom");
                root.check(Math.abs(panels.notifications.x + panels.notifications.width - panels.width) < 1, "Popup notifications must stay anchored to the right");
                root.check(panels.toasts.height > 0 && panels.toasts.y + panels.toasts.height <= panels.notifications.y, "Internal toast messages must not cover notification popups");
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
                root.check(Math.abs(panels.utilities.y) < 1, "Sidebar utility controls must start at the top");
                const toggles = root.findItem(panels, "utilitiesQuickToggles");
                const notifications = root.findItem(panels, "sidebarNotifications");
                const keepAwake = root.findItem(panels, "utilitiesKeepAwake");
                const recorder = root.findItem(panels, "utilitiesScreenRecorder");
                root.check(toggles !== null && notifications !== null && keepAwake !== null && recorder !== null, "All sidebar sections must load");
                const toggle = root.findToggle(panels.utilities);
                root.check(toggle !== null, "The quick-toggle click target must be loaded");
                if (toggle) {
                    const point = toggle.mapToItem(window.contentItem, toggle.width / 2, toggle.height / 2);
                    const input = window.mask.regions.find(region => region.panel === panels.utilities);
                    root.check(input && point.x >= input.x && point.x < input.x + input.width && point.y >= input.y && point.y < input.y + input.height, "The Wayland input region must include the visible quick toggle at " + point + "; actual region " + input?.x + "," + input?.y + " " + input?.width + "x" + input?.height);
                    const initialDnd = PersistentState.doNotDisturb;
                    root.check(events.mouseClick(toggle.stateLayer, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "The quick toggle must accept a click");
                    root.check(PersistentState.doNotDisturb !== initialDnd && state.sidebar, "A quick toggle must change its state without closing the sidebar");
                    root.check(events.mouseClick(toggle.stateLayer, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "The quick toggle must accept a repeated click");
                    root.check(PersistentState.doNotDisturb === initialDnd && state.sidebar, "Repeated quick-toggle clicks must keep the sidebar open");
                }
                if (toggles && notifications && keepAwake && recorder) {
                    root.check(toggles.mapToItem(panels, 0, toggles.height).y < keepAwake.mapToItem(panels, 0, 0).y, "Quick toggles must precede keep-awake controls");
                    root.check(keepAwake.mapToItem(panels, 0, keepAwake.height).y < recorder.mapToItem(panels, 0, 0).y, "Keep-awake must precede the recorder");
                    root.check(recorder.mapToItem(panels, 0, recorder.height).y < notifications.mapToItem(panels, 0, 0).y, "Notification history must follow all utility controls");
                }
                break;
            case 4:
                root.move(window.width / 2, window.height / 2);
                root.check(!state.sidebar, "Leaving the right sidebar must close it");
                Notifs.list = [notificationComponent.createObject(root)];
                closingProbe.start();
                break;
            case 5:
                root.check(root.closingSamples > 0, "Dismissal overlap checks must observe the closing animation");
                root.move(1, window.height - 1);
                root.check(!state.sidebar, "Returning to the bottom-left corner must keep the sidebar closed");
                state.utilities = true;
                Notifs.list = Array.from({
                    length: 20
                }, () => notificationComponent.createObject(root));
                break;
            case 6:
                root.check(panels.notifications.height > 0 && panels.notifications.y >= -1, "A large popup stack must fit below the top bar");
                root.check(panels.notifications.y + panels.notifications.height <= panels.utilities.y + 6, "Popups must stay above the open utility controls");
                root.check(panels.toasts.y >= -1, "Combined toast and popup stacks must stay below the top bar");
                const standaloneToggles = root.findItem(panels.utilities, "utilitiesQuickToggles");
                const standaloneKeepAwake = root.findItem(panels.utilities, "utilitiesKeepAwake");
                root.check(standaloneToggles !== null && standaloneKeepAwake !== null, "Standalone utilities must retain quick toggles");
                if (standaloneToggles && standaloneKeepAwake)
                    root.check(standaloneToggles.mapToItem(panels, 0, standaloneToggles.height).y < standaloneKeepAwake.mapToItem(panels, 0, 0).y, "Standalone quick toggles must also remain first");
                state.utilities = false;
                state.osd = true;
                break;
            case 7:
                root.check(panels.notifications.y >= panels.osdWrapper.y + panels.osdWrapper.height - 1, "Popups must stay below the visible OSD");
                root.check(panels.notifications.y + panels.notifications.height <= panels.height + 6, "OSD must not push popups past the bottom edge");
                state.osd = false;
                state.session = true;
                break;
            case 8:
                root.check(panels.notifications.y >= panels.sessionWrapper.y + panels.sessionWrapper.height - 1, "Popups must stay below the visible session menu");
                root.check(panels.notifications.y + panels.notifications.height <= panels.height + 6, "Session menu must not push popups past the bottom edge");
                state.session = false;
                GlobalConfig.sidebar.enabled = false;
                state.sidebar = true;
                break;
            case 9:
                root.check(!panels.sidebar.visible && root.findItem(panels.utilities, "utilitiesQuickToggles") !== null, "A disabled sidebar must not hide quick toggles from the remaining utility controls");
                state.sidebar = false;
                Notifs.list = [notificationComponent.createObject(root)];
                break;
            case 10:
                root.notificationCorner = panels.notifications.mapToItem(window.contentItem, panels.notifications.width, panels.notifications.height);
                window.fsTransitionProg = 1;
                window.bar.fullscreen = true;
                break;
            case 11:
                root.check(window.bar.height === 0, "The fullscreen placement check must run with the top bar hidden");
                window.fsTransitionProg = 0;
                window.bar.fullscreen = false;
                break;
            case 12:
                root.check(root.fullscreenSamples > 0, "Popup position checks must cover fullscreen transitions");
                console.log("Sidebar hover failures:", root.failures);
                Qt.exit(root.failures === 0 ? 0 : 1);
            }
        }
    }
}
