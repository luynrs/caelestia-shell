import "fixtures"
import QtQuick
import Quickshell
import qs.modules.bar.popouts as Popouts

ShellRoot {
    id: root

    property int failures: 0
    property int phase: 0
    property int pendingSamples: 0
    property int menuSamples: 0
    property real outgoingWidth: 0
    property real outgoingHeight: 0
    property real minimumPendingWidth: Infinity
    property real minimumPendingHeight: Infinity
    property real maximumTopOffset: 0
    property Item iconLabel
    property real initialLabelOffset: 0
    property real maximumLabelShift: 0
    property Item retainedMenu
    property int retainedOpenerInstances: 0
    property real submenuParentHeight: 0
    property real currentMenuWidth: 0
    property real currentMenuHeight: 0
    property int clearedMenuSamples: 0
    property real minimumClearedWidth: Infinity
    property real minimumClearedHeight: Infinity
    readonly property var trayLoaders: popout.content.content.item?.children[0]?.children.filter(child => child.name?.startsWith("traymenu")) ?? []

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Component.onCompleted: {
        Popouts.TrayRegistry.entries = [
            {
                id: "first",
                status: 1,
                hasMenu: true,
                menu: firstMenu
            },
            {
                id: "delayed",
                status: 1,
                hasMenu: true,
                menu: delayedMenu
            },
            {
                id: "empty",
                status: 1,
                hasMenu: true,
                menu: emptyMenu
            }
        ];
        popout.content.currentCenter = 1210;
        popout.content.currentName = "traymenu0";
        popout.content.hasCurrent = true;
        emptyPopout.content.currentName = "traymenu2";
        emptyPopout.content.hasCurrent = true;
        const rows = root.trayLoaders.find(child => child.name === "traymenu0").item.currentItem.children.filter(child => child.modelData !== undefined && !child.modelData.isSeparator);
        root.check(rows.length === 2 && rows.every(child => child.implicitHeight > 0), "Tray menu rows must have measured heights before asynchronous incubation");
        root.iconLabel = rows[0].children[0].item?.children.find(child => child.text === openEntry.text) ?? null;
        if (root.iconLabel)
            root.initialLabelOffset = root.iconLabel.x;
    }

    TrayMenuHandle {
        id: firstMenu

        entries: [openEntry, separatorEntry, quitEntry]
    }

    TrayMenuHandle {
        id: delayedMenu
    }

    TrayMenuHandle {
        id: emptyMenu
    }

    TrayMenuHandle {
        id: openEntry

        text: "Open application"
        icon: Qt.resolvedUrl("assets/logo.svg")
        entries: [quitEntry]
    }

    TrayMenuHandle {
        id: separatorEntry

        isSeparator: true
    }

    TrayMenuHandle {
        id: quitEntry

        text: "Quit application"
    }

    TrayMenuHandle {
        id: preferencesEntry

        text: "Preferences"
    }

    Item {
        width: 1280
        height: 720

        Popouts.ClipWrapper {
            id: popout

            screen: Quickshell.screens[0]
            borderThickness: 10
        }

        Popouts.ClipWrapper {
            id: emptyPopout

            screen: Quickshell.screens[0]
            borderThickness: 10
        }
    }

    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            if (root.phase === 0) {
                root.check(popout.content.current !== null, "The initial tray menu must load");
                root.check(emptyPopout.width === 0 && emptyPopout.height === 0 && !emptyPopout.visible, "An initially empty native menu must not open a blank popup");
                root.check(root.iconLabel !== null, "The icon-bearing menu label must be measured during activation");
                root.check(root.maximumLabelShift < 1, "A static tray entry label must retain its horizontal position; observed shift " + root.maximumLabelShift);
                root.outgoingWidth = popout.width;
                root.outgoingHeight = popout.height;
                root.phase = 1;
                popout.content.currentName = "traymenu1";
                populate.restart();
            } else if (root.phase === 2) {
                root.check(root.pendingSamples >= 30, "Native menu population must remain pending beyond the outgoing fade");
                root.check(root.menuSamples > 0, "The populated incoming menu must be sampled");
                root.check(root.minimumPendingWidth >= root.outgoingWidth - 1, "Pending tray menu must preserve outgoing width; observed " + root.minimumPendingWidth + " from " + root.outgoingWidth);
                root.check(root.minimumPendingHeight >= root.outgoingHeight - 1, "Pending tray menu must preserve outgoing height; observed " + root.minimumPendingHeight + " from " + root.outgoingHeight);
                root.check(popout.content.current?.trayItem === delayedMenu, "The incoming tray menu must replace the outgoing menu after population");
                root.phase = 3;
                popout.content.currentName = "traymenu0";
            } else if (root.phase === 3) {
                root.check(popout.content.current?.trayItem === firstMenu, "A ready tray menu must replace the previous menu directly");
                root.check(root.maximumTopOffset < 1, "Tray menu content must retain its top edge; observed offset " + root.maximumTopOffset);
                root.phase = 4;
                popout.content.currentName = "traymenu2";
            } else if (root.phase === 4) {
                root.check(popout.width >= root.outgoingWidth - 1 && popout.height >= root.outgoingHeight - 1, "An empty native menu must preserve the previous popup dimensions");
                root.check(popout.content.content.item.currentPopout.item.trayItem === firstMenu, "An empty native menu must not replace the measured outgoing menu");
                root.check(popout.content.current === null, "A pending native menu must not expose the outgoing menu to pointer handling");
                root.check(root.trayLoaders.every(child => !child.enabled && child.opacity < 0.01), "Pending native menus must fade and disable outgoing actions");
                root.phase = 5;
                delayedMenu.entries = [];
                popout.content.currentName = "traymenu1";
                populate.restart();
                cancel.restart();
            } else if (root.phase === 5) {
                root.check(popout.content.current?.trayItem === firstMenu, "Late menu population must not steal a cancelled hover request");
                root.check(root.trayLoaders.find(child => child.name === "traymenu0").enabled, "Returning to a ready menu must enable its actions");
                root.retainedMenu = popout.content.current;
                root.retainedOpenerInstances = firstMenu.openerInstances;
                root.phase = 6;
                popout.content.hasCurrent = false;
                reopen.restart();
            } else if (root.phase === 6) {
                root.check(popout.content.current === root.retainedMenu, "A brief gap between hover targets must reuse the measured menu");
                root.check(firstMenu.openerInstances === root.retainedOpenerInstances, "Re-entering during the close transition must preserve the native menu subscription");
                root.retainedMenu = popout.content.current;
                root.retainedOpenerInstances = firstMenu.openerInstances;
                root.phase = 7;
                firstMenu.entries = [openEntry, separatorEntry, preferencesEntry, quitEntry];
            } else if (root.phase === 7) {
                root.check(popout.content.current === root.retainedMenu && firstMenu.openerInstances === root.retainedOpenerInstances, "A live native model update must reuse the existing menu subscription");
                root.check(popout.height > root.outgoingHeight + 10, "A live native model update must resize the displayed menu");
                root.submenuParentHeight = popout.height;
                openEntry.hasChildren = true;
                openEntry.entries = [];
                const row = root.retainedMenu.currentItem.children.find(child => child.modelData === openEntry);
                row.children[0].item.children[0].clicked(null);
                root.phase = 8;
            } else if (root.phase === 8) {
                root.check(popout.content.current?.depth === 2, "A pending submenu must retain the current stack for submenu focus and hover pinning");
                root.check(Math.abs(popout.height - root.submenuParentHeight) < 1, "A pending submenu must retain its measured parent height");
                root.phase = 9;
                openEntry.entries = [quitEntry];
            } else if (root.phase === 9) {
                root.check(popout.content.current?.depth === 2 && popout.content.current.currentItem.hasChildren, "A populated submenu must remain current");
                root.check(popout.height > 0 && popout.height < root.submenuParentHeight, "A populated submenu must resize from its measured parent to its own rows");
                root.retainedMenu.pop();
                root.phase = 10;
            } else if (root.phase === 10) {
                root.check(popout.content.current?.depth === 1 && Math.abs(popout.height - root.submenuParentHeight) < 1, "Back must restore the measured parent menu");
                openEntry.entries = [];
                const row = root.retainedMenu.currentItem.children.find(child => child.modelData === openEntry);
                row.children[0].item.children[0].clicked(null);
                root.retainedMenu.pop();
                submenuPopulate.restart();
                root.phase = 11;
            } else if (root.phase === 11) {
                root.check(popout.content.current?.depth === 1, "Late submenu population must not reopen a popped page");
                root.currentMenuWidth = popout.width;
                root.currentMenuHeight = popout.height;
                root.phase = 12;
                firstMenu.entries = [];
                repopulate.restart();
            } else if (root.phase === 13) {
                root.check(popout.content.current === root.retainedMenu && firstMenu.openerInstances === root.retainedOpenerInstances, "Repopulating the current menu must preserve its native subscription");
                root.check(popout.height > 0 && popout.height < root.currentMenuHeight - 10, "Repopulating the current menu must resize to its new measured rows");
                root.phase = 14;
                popout.content.hasCurrent = false;
            } else {
                root.check(popout.content.content.item === null, "Closing the wrapper must release retained tray menus");
                console.log("Tray menu motion failures:", root.failures);
                Qt.exit(root.failures === 0 ? 0 : 1);
            }
        }
    }

    Timer {
        id: populate

        interval: 640
        onTriggered: {
            delayedMenu.entries = [openEntry, quitEntry];
            if (root.phase === 1)
                root.phase = 2;
        }
    }

    Timer {
        id: cancel

        interval: 80
        onTriggered: popout.content.currentName = "traymenu0"
    }

    Timer {
        id: reopen

        interval: 80
        onTriggered: popout.content.hasCurrent = true
    }

    Timer {
        id: submenuPopulate

        interval: 160
        onTriggered: openEntry.entries = [preferencesEntry]
    }

    Timer {
        id: repopulate

        interval: 640
        onTriggered: {
            root.check(root.retainedMenu.ready === false, "Clearing the current menu must exercise loss of measured readiness");
            root.check(root.clearedMenuSamples >= 30, "The current menu must remain empty beyond its fade duration");
            root.check(root.minimumClearedWidth >= root.currentMenuWidth - 1, "Temporarily empty current menu must preserve its width; observed " + root.minimumClearedWidth + " from " + root.currentMenuWidth);
            root.check(root.minimumClearedHeight >= root.currentMenuHeight - 1, "Temporarily empty current menu must preserve its height; observed " + root.minimumClearedHeight + " from " + root.currentMenuHeight);
            root.check(!root.trayLoaders.find(child => child.name === "traymenu0").enabled, "Temporarily empty current menu must disable its actions");
            firstMenu.entries = [openEntry, quitEntry];
            root.phase = 13;
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            for (const loader of root.trayLoaders)
                loader.item?.currentItem?.forceLayout();
            if (root.phase === 0 && root.iconLabel)
                root.maximumLabelShift = Math.max(root.maximumLabelShift, Math.abs(root.iconLabel.x - root.initialLabelOffset));
            if (root.phase === 1) {
                root.pendingSamples++;
                root.minimumPendingWidth = Math.min(root.minimumPendingWidth, popout.width);
                root.minimumPendingHeight = Math.min(root.minimumPendingHeight, popout.height);
            } else if (root.phase === 12) {
                root.clearedMenuSamples++;
                root.minimumClearedWidth = Math.min(root.minimumClearedWidth, popout.width);
                root.minimumClearedHeight = Math.min(root.minimumClearedHeight, popout.height);
            } else if (root.phase > 1 && popout.content.current?.currentItem?.hasChildren) {
                root.menuSamples++;
                root.maximumTopOffset = Math.max(root.maximumTopOffset, Math.abs(popout.content.current.currentItem.mapToItem(popout.content.current, 0, 0).y));
            }
        }
    }
}
