pragma Singleton

import Quickshell
import Caelestia.Config

Singleton {
    id: root

    readonly property list<ShellScreen> screens: Quickshell.screens.filter(screen => !isExcluded(screen))

    function isExcluded(screen: ShellScreen): bool {
        return !screen?.name || !GlobalConfig.forScreen(screen.name).enabled;
    }
}
