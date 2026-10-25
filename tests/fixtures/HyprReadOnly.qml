pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Services

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels

    readonly property var workspaces: Hyprland.workspaces

    readonly property var monitors: Hyprland.monitors

    readonly property bool usingLua: Hyprland.usingLua

    readonly property HyprlandToplevel activeToplevel: {
        const toplevel = Hyprland.activeToplevel;
        return toplevel?.workspace?.name.startsWith("special:") || Hyprland.focusedWorkspace?.toplevels.values.length > 0 ? toplevel : null;
    }

    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace

    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor

    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    readonly property var options: nativeExtras.options

    readonly property var keyboard: nativeExtras.devices.keyboards.find(keyboard => keyboard.main) ?? null

    readonly property bool capsLock: keyboard?.capsLock ?? false

    readonly property bool numLock: keyboard?.numLock ?? false

    readonly property string kbLayout: keyboard?.layout.split(",")[keyboard.lastIpcObject.active_layout_index ?? 0] ?? "??"

    readonly property QtObject extras: QtObject {
        function batchMessage(messages: var): void {
        }
    }

    signal configReloaded

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    function trimWsName(name: string): string {
        return name.startsWith("special:") ? name.slice("special:".length) : name;
    }

    function isToplevelIgnored(toplevel: HyprlandToplevel, ignoredTags: list<string>): bool {
        const ipc = toplevel?.lastIpcObject;
        return !ipc?.class || !ipc.mapped || (ipc.tags?.some(tag => ignoredTags.includes(tag.replace(/\*$/, ""))) ?? false);
    }

    function toplevelsForWs(workspace: int, ignoredTags: list<string>): list<HyprlandToplevel> {
        return toplevels.values.filter(toplevel => toplevel.workspace && toplevel.workspace.id === workspace && !isToplevelIgnored(toplevel, ignoredTags));
    }

    function dispatch(request: string): void {
    }
    function focusWorkspace(workspace: var): void {
    }
    function toggleSpecial(name: string): void {
    }

    HyprExtras {
        id: nativeExtras

        usingLua: Hyprland.usingLua
    }
}
