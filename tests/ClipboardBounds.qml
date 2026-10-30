import QtQuick
import QtQuick.Templates
import QtTest
import Quickshell
import qs.components
import qs.components.controls as Controls
import qs.modules.launcher as Launcher

ShellRoot {
    id: root

    property int failures: 0
    property var scrollbar
    property var thumb
    property int step: 0
    property var list
    property real previousContentY
    property real topOvershoot
    property real bottomOvershoot

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
        launcherQuery: ">clipboard "
        launcher: true
    }

    TestEvent {
        id: events
    }

    ListModel {
        id: changingModel

        Component.onCompleted: {
            for (let i = 0; i < 25; i++)
                append({
                    value: i
                });
        }
    }

    PanelWindow {
        id: window
        implicitWidth: 1280
        implicitHeight: 300
        color: "transparent"
        exclusiveZone: 0
        mask: Region {}
        contentItem.opacity: 0
    }

    Item {
        id: stage

        parent: window.contentItem
        width: 1280
        height: 300

        Launcher.Wrapper {
            id: launcher

            screen: Quickshell.screens[0]
            screenState: state
            panels: stage
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
        }

        ListView {
            id: changingList

            width: 100
            height: 200
            model: changingModel

            delegate: Item {
                required property int value
                width: changingList.width
                height: 50
            }

            Controls.StyledScrollBar.vertical: Controls.StyledScrollBar {
                flickable: changingList
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: {
            root.check(launcher.height > 200, "Large clipboard history must fill its bounded viewport");
            root.check(launcher.height <= stage.height && launcher.y >= 0, "Clipboard history must stay below the top bar");
            root.check(Math.abs(launcher.y + launcher.height - stage.height) < 1, "Clipboard history must retain the launcher bottom anchor");
            root.list = root.findItem(launcher, "launcherClipboardList");
            root.check(root.list !== null, "Clipboard list must load");
            if (root.list) {
                root.scrollbar = root.list.ScrollBar.vertical;
                root.thumb = root.scrollbar.contentItem.children[0];
                root.check(root.thumb.height < root.scrollbar.size * root.scrollbar.height * 0.9, "The scrollbar thumb must be shorter than the visible content ratio");
                root.list.positionViewAtBeginning();
                sampleTimer.start();
                interactionTimer.start();
            } else {
                Qt.exit(1);
            }
        }
    }

    Timer {
        id: sampleTimer

        interval: 16
        repeat: true
        onTriggered: {
            const thumbY = root.thumb.mapToItem(root.scrollbar, 0, 0).y;
            root.check(thumbY >= -0.1 && thumbY + root.thumb.height <= root.scrollbar.height + 0.1, "Visible scrollbar must stay within its track during scrolling");
            const expectedY = Math.max(0, Math.min(1, root.list.visibleArea.yPosition / (1 - root.scrollbar.size))) * (root.scrollbar.height - root.thumb.height);
            root.check(Math.abs(thumbY - expectedY) < 0.5, "Visible scrollbar must use the full track while following the list");
            if (root.step >= 14) {
                root.topOvershoot = Math.min(root.topOvershoot, root.list.verticalOvershoot);
                root.bottomOvershoot = Math.max(root.bottomOvershoot, root.list.verticalOvershoot);
                root.check(Math.abs(root.thumb.height - root.scrollbar.size * root.scrollbar.height * 0.85) < 1, "Scrollbar thumb must keep its length when the list overscrolls");
            }
        }
    }

    Timer {
        id: interactionTimer

        interval: 250
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.check(events.mouseWheel(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0), "Wheel event must reach the scrollbar");
                root.check(root.list.contentY > 0, "Scrolling down on the scrollbar must move the list down");
                root.list.positionViewAtIndex(18, ListView.Beginning);
                break;
            case 1:
                root.previousContentY = root.list.contentY;
                root.check(root.previousContentY > 300, "Keyboard-style navigation must move the list away from the previous scrollbar position");
                root.check(events.mouseWheel(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0), "Second wheel event must reach the scrollbar");
                root.check(root.list.contentY > root.previousContentY && root.list.contentY - root.previousContentY <= root.list.contentHeight * 0.11, "Scrolling down on the scrollbar must continue from the current list position without jumping");
                break;
            case 2:
                root.check(events.mousePress(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height * 0.25, Qt.LeftButton, Qt.NoModifier, 0), "Press must reach the scrollbar");
                root.previousContentY = root.list.contentY;
                root.check(events.mouseMove(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height * 0.75, 0, Qt.LeftButton, Qt.NoModifier), "Drag must reach the scrollbar");
                root.check(Math.abs(root.thumb.mapToItem(root.scrollbar, 0, 0).y + root.thumb.height / 2 - root.scrollbar.height * 0.75) < 2, "The scrollbar thumb must follow the pointer while dragged");
                root.check(events.mouseRelease(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height * 0.75, Qt.LeftButton, Qt.NoModifier, 0), "Release must reach the scrollbar");
                root.check(root.list.contentY > root.previousContentY + 300, "Dragging the scrollbar down must move the list down");
                root.list.positionViewAtBeginning();
                break;
            case 3:
                root.check(root.list.contentY === root.list.originY && Math.abs(root.thumb.mapToItem(root.scrollbar, 0, 0).y) < 0.5, "Scrollbar must reach the top after returning to the first entry");
                root.check(events.mouseWheel(root.list, root.list.width / 2, root.list.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0), "Wheel event must reach the list");
                break;
            case 4:
                root.previousContentY = root.list.contentY;
                root.check(root.previousContentY > 0, "Scrolling the list must move its content");
                root.check(events.mouseWheel(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0), "Wheel event must reach the scrollbar after scrolling the list");
                root.check(root.list.contentY > root.previousContentY && root.list.contentY - root.previousContentY <= root.list.contentHeight * 0.11, "Scrollbar wheel must continue from the position reached by scrolling the list");
                root.list.positionViewAtEnd();
                break;
            case 5:
                root.check(Math.abs(root.thumb.mapToItem(root.scrollbar, 0, 0).y + root.thumb.height - root.scrollbar.height) < 0.5, "Scrollbar must reach the bottom after the last entry");
                root.check(events.mouseWheel(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0), "Wheel event must reach the scrollbar at the bottom");
                root.list.positionViewAtIndex(12, ListView.Beginning);
                break;
            case 6:
                root.previousContentY = root.list.contentY;
                root.check(events.mouseWheel(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height / 2, Qt.NoButton, Qt.NoModifier, 0, 120, 0), "Upward wheel event must reach the scrollbar");
                root.check(root.list.contentY < root.previousContentY && root.previousContentY - root.list.contentY <= root.list.contentHeight * 0.11, "Scrollbar must scroll up from the current position after reaching the boundary");
                break;
            case 7:
                root.list.positionViewAtBeginning();
                root.list.flick(0, -1500);
                break;
            case 8:
                root.check(root.list.contentY > 0, "A flick must move the list while scrollbar geometry is sampled");
                root.list.cancelFlick();
                changingList.positionViewAtIndex(12, ListView.Beginning);
                break;
            case 9:
                changingModel.remove(0, 5);
                break;
            case 10:
                root.check(changingList.originY !== 0, "Removing scrolled entries must exercise a shifted list origin");
                root.previousContentY = changingList.contentY;
                const changingScrollbar = changingList.ScrollBar.vertical;
                root.check(events.mouseWheel(changingScrollbar, changingScrollbar.width / 2, changingScrollbar.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0), "Wheel event must reach a scrollbar after entries are removed");
                root.check(changingList.contentY > root.previousContentY && changingList.contentY - root.previousContentY <= changingList.contentHeight * 0.11, "Scrollbar must continue from the current position after entries are removed");
                root.check(events.mousePress(changingScrollbar, changingScrollbar.width / 2, 2, Qt.LeftButton, Qt.NoModifier, 0), "Press must reach the scrollbar with a shifted list origin");
                root.check(Math.abs(changingList.contentY - changingList.originY) < 1, "Pressing the top of the scrollbar must reach the first remaining item");
                root.check(events.mouseMove(changingScrollbar, changingScrollbar.width / 2, changingScrollbar.height - 2, 0, Qt.LeftButton, Qt.NoModifier), "Drag must reach the scrollbar with a shifted list origin");
                root.check(events.mouseRelease(changingScrollbar, changingScrollbar.width / 2, changingScrollbar.height - 2, Qt.LeftButton, Qt.NoModifier, 0), "Release must reach the scrollbar with a shifted list origin");
                root.check(Math.abs(changingList.contentY - changingList.originY - changingList.contentHeight + changingList.height) < 1, "Dragging to the bottom must reach the last remaining item");
                break;
            case 11:
                changingModel.clear();
                break;
            case 12:
                root.previousContentY = changingList.contentY;
                root.check(events.mouseWheel(changingList.ScrollBar.vertical, changingList.ScrollBar.vertical.width / 2, changingList.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0), "Wheel event must reach an empty list's scrollbar");
                root.check(changingList.contentY === root.previousContentY, "Scrolling an empty list must not move its content");
                break;
            case 13:
                root.list.positionViewAtEnd();
                root.list.contentY -= 20;
                root.check(events.mouseWheel(root.list, root.list.width / 2, root.list.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, 0), "Wheel event must reach the list near the bottom");
                break;
            case 14:
                break;
            case 15:
            case 16:
            case 17:
                break;
            case 18:
                root.list.cancelFlick();
                root.list.positionViewAtBeginning();
                root.list.contentY += 20;
                root.check(events.mouseWheel(root.list, root.list.width / 2, root.list.height / 2, Qt.NoButton, Qt.NoModifier, 0, 120, 0), "Wheel event must reach the list near the top");
                break;
            case 19:
                break;
            case 20:
                root.check(root.topOvershoot < -1 && root.bottomOvershoot > 1, "Wheel scrolling must exercise overscroll at both ends");
                break;
            case 21:
                root.list.contentY = root.list.originY - root.list.height * 2;
                break;
            case 22:
                root.check(events.mousePress(root.scrollbar, root.scrollbar.width / 2, 1, Qt.LeftButton, Qt.NoModifier, 0), "Press must reach the scrollbar during overscroll");
                root.check(events.mouseMove(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height / 2, 0, Qt.LeftButton, Qt.NoModifier), "Drag must reach the scrollbar during overscroll");
                root.check(events.mouseRelease(root.scrollbar, root.scrollbar.width / 2, root.scrollbar.height / 2, Qt.LeftButton, Qt.NoModifier, 0), "Release must reach the scrollbar during overscroll");
                root.check(root.list.contentY > root.list.originY + 10, "Dragging the visible scrollbar during overscroll must move the list");
                break;
            case 23:
                sampleTimer.stop();
                stop();
                console.log("Clipboard bounds failures:", root.failures);
                Qt.exit(root.failures === 0 ? 0 : 1);
            }
        }
    }
}
