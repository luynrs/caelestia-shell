pragma Singleton

import Quickshell

Singleton {
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")
    readonly property string current: fallback
}
