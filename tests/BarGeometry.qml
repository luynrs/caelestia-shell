import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.bar as Bar
import qs.modules.drawers as Drawers
import qs.modules.bar.components as Widgets
import qs.modules.bar.popouts as Popouts

ShellRoot {
    id: root

    property int failures: 0
    property int popoutOpeningSamples: 0

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

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    ScreenState {
        id: state

        modelData: Quickshell.screens[0]
        bar: true
    }

    Drawers.ContentWindow {
        id: window

        visible: false
        screen: Quickshell.screens[0]
        implicitWidth: 1280
        implicitHeight: 720
    }

    Item {
        id: stage

        width: 1280
        height: 720

        Bar.BarWrapper {
            id: bar

            width: parent.width
            anchors.top: parent.top
            screen: Quickshell.screens[0]
            screenState: state
            popouts: popout.content
            fullscreen: false
        }

        Popouts.ClipWrapper {
            id: popout

            screen: Quickshell.screens[0]
            borderThickness: 10
        }

        Widgets.Clock {
            id: clock
        }

        Widgets.StatusIcons {
            id: status
        }

        Widgets.Tray {
            id: tray
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            root.check(bar.height > 0 && bar.height < 100, "Visible top bar must have a positive, bounded height");
            root.check(bar.width === stage.width, "Top bar must span its screen");
            root.check(bar.exclusiveZone === bar.height, "Reserved space must equal top bar height");
            root.check(clock.width > clock.height, "Clock must be horizontal");
            root.check(status.width > status.height, "Status icons must form a horizontal row");
            const workspaces = root.findItem(bar, "taskbarWorkspaces");
            root.check(workspaces !== null && workspaces.width > workspaces.height, "Workspaces must form a horizontal row");
            if (workspaces) {
                root.check(workspaces.workspaces.length > 0, "Workspace delegates must be exposed to indicators");
                const entries = workspaces.workspaces;
                for (let index = 1; index < entries.length; index++)
                    root.check(entries[index].x >= entries[index - 1].x + entries[index - 1].width, "Workspace delegates must not overlap");
            }
            const panels = window.interactionWrapper.panels;
            root.check(window.bar.y === 0, "Bar must sit at the top of the screen");
            root.check(panels.y === window.bar.height, "Drawer content must start below the bar");
            root.check(panels.x < window.bar.height, "Drawer content must not retain the old left bar offset");
            root.check(window.mask.y >= window.bar.height, "Input mask must leave the top bar interactive");
            root.check(window.mask.width > window.mask.height, "Input mask must preserve the landscape desktop area");
            root.check(window.interactionWrapper.inBottomPanel(panels.dashboard, panels.x + panels.dashboard.x + panels.dashboard.width / 2, window.height - 1), "Closed dashboard must retain a bottom-edge hover and drag trigger");
            root.check(window.interactionWrapper.inBottomPanel(panels.launcher, panels.x + panels.launcher.x + panels.launcher.width / 2, window.height - 1), "Closed launcher must retain its bottom-edge trigger");
            if (tray.items.count === 0)
                root.check(tray.width === 0, "Empty tray must not reserve horizontal space");
            popout.content.currentName = "audio";
            popout.content.currentCenter = stage.width;
            popout.content.hasCurrent = true;
            popoutOpeningTimer.start();
            popupTimer.start();
        }
    }

    Timer {
        id: popoutOpeningTimer

        interval: 16
        repeat: true
        onTriggered: {
            if (popout.offsetScale <= 0 || popout.offsetScale >= 1)
                return;
            root.popoutOpeningSamples++;
            root.check(Math.abs(popout.x + popout.width - stage.width) < 1, "Opening a right-edge popout must preserve its horizontal position");
            root.check(Math.abs(popout.content.width - popout.content.nonAnimWidth) < 1, "Opening a top popout must use its final width");
            root.check(popout.content.y < 0, "Opening a top popout must slide down from above");
        }
    }

    Timer {
        id: popupTimer

        interval: 1000
        onTriggered: {
            popoutOpeningTimer.stop();
            root.check(root.popoutOpeningSamples > 0, "Popout trajectory must be checked during its opening animation");
            root.check(popout.x + popout.width <= stage.width + 1, "Right-edge popout must stay on screen");
            root.check(popout.y === 0, "Attached popout must open below the top bar");
            window.screenState.dashboard = true;
            popout.content.currentCenter = 1;
            rightTimer.start();
        }
    }

    Timer {
        id: rightTimer

        interval: 1000
        onTriggered: {
            root.check(popout.x >= 0 && popout.x < 1, "Left-edge popout must stay on screen");
            const panels = window.interactionWrapper.panels;
            root.check(Math.abs(panels.dashboard.y + panels.dashboard.height - panels.height) < 1, "Dashboard opened by Win+A must sit at the bottom");
            window.screenState.launcher = true;
            root.check(window.screenState.launcher && !window.screenState.dashboard, "Opening launcher must close dashboard");
            root.check(!panels.dashboard.visible, "Dashboard must disappear immediately when switching to launcher");
            launcherTimer.start();
        }
    }

    Timer {
        id: launcherTimer

        interval: 1000
        onTriggered: {
            const panels = window.interactionWrapper.panels;
            root.check(!panels.dashboard.visible, "Dashboard must be hidden while launcher is open");
            root.check(Math.abs(panels.launcher.y + panels.launcher.height - panels.height) < 1, "Launcher must open at the bottom edge");
            window.screenState.launcher = false;
            root.check(panels.launcher.visible, "Normal launcher close must preserve visibility during animation");
            launcherClosingTimer.start();
        }
    }

    Timer {
        id: launcherClosingTimer

        interval: 50
        onTriggered: {
            const launcher = window.interactionWrapper.panels.launcher;
            root.check(launcher.offsetScale > 0 && launcher.offsetScale < 1, "Normal launcher close must animate its offset");
            root.check(launcher.height > 0, "Launcher content must retain height while closing");
            launcherClosedTimer.start();
        }
    }

    Timer {
        id: launcherClosedTimer

        interval: 1000
        onTriggered: {
            root.check(!window.interactionWrapper.panels.launcher.visible, "Launcher must disappear after its closing animation");
            window.screenState.launcher = true;
            launcherSwitchTimer.start();
        }
    }

    Timer {
        id: launcherSwitchTimer

        interval: 1000
        onTriggered: {
            const panels = window.interactionWrapper.panels;
            window.screenState.dashboard = true;
            root.check(window.screenState.dashboard && !window.screenState.launcher, "Opening dashboard must close launcher without dismissing dashboard");
            root.check(!panels.launcher.visible, "Launcher must disappear immediately when switching to dashboard");
            dashboardTimer.start();
        }
    }

    Timer {
        id: dashboardTimer

        interval: 1000
        onTriggered: {
            const panels = window.interactionWrapper.panels;
            root.check(panels.dashboard.visible && !panels.launcher.visible, "Only dashboard must remain visible after switching from launcher");
            window.screenState.dashboard = false;
            root.check(panels.dashboard.visible, "Normal dashboard close must preserve visibility during animation");
            dashboardClosingTimer.start();
        }
    }

    Timer {
        id: dashboardClosingTimer

        interval: 50
        onTriggered: {
            const dashboard = window.interactionWrapper.panels.dashboard;
            root.check(dashboard.offsetScale > 0 && dashboard.offsetScale < 1, "Normal dashboard close must animate its offset");
            window.screenState.launcher = true;
            root.check(!dashboard.visible && dashboard.offsetScale === 1, "Switching during dashboard close must settle its geometry immediately: " + dashboard.offsetScale + ", " + dashboard.visible);
            for (let index = 0; index < 4; index++) {
                window.screenState.launcher = true;
                root.check(window.screenState.launcher && !window.screenState.dashboard, "Rapid switching must select launcher exclusively");
                window.screenState.dashboard = true;
                root.check(window.screenState.dashboard && !window.screenState.launcher, "Rapid switching must select dashboard exclusively");
            }
            window.screenState.dashboard = false;
            root.check(!window.screenState.launcher && !window.screenState.dashboard, "Closing a drawer must leave both closed");
            closingTimer.start();
        }
    }

    Timer {
        id: closingTimer

        interval: 50
        onTriggered: {
            window.screenState.launcher = true;
            root.check(!window.interactionWrapper.panels.dashboard.visible, "Opening launcher must stop an ongoing dashboard close animation");
            launcherBeforeInterruptTimer.start();
        }
    }

    Timer {
        id: launcherBeforeInterruptTimer

        interval: 1000
        onTriggered: {
            window.screenState.launcher = false;
            switchingTimer.start();
        }
    }

    Timer {
        id: switchingTimer

        interval: 50
        onTriggered: {
            const launcher = window.interactionWrapper.panels.launcher;
            root.check(launcher.offsetScale > 0 && launcher.offsetScale < 1, "Launcher must be partway through closing before interruption");
            window.screenState.dashboard = true;
            root.check(!launcher.visible && launcher.offsetScale === 1, "Opening dashboard must stop an ongoing launcher close animation");
            window.screenState.dashboard = false;
            popout.content.hasCurrent = false;
            bar.fullscreen = true;
            hiddenTimer.start();
        }
    }

    Timer {
        id: hiddenTimer

        interval: 1000
        onTriggered: {
            root.check(popout.height === 0, "Closed attached popout must collapse vertically");
            root.check(bar.height === 0, "Fullscreen must hide the top bar");
            root.check(!window.interactionWrapper.panels.launcher.visible && !window.interactionWrapper.panels.dashboard.visible, "Closed drawers must not reappear after interrupted animations");
            console.log("Bar geometry failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
