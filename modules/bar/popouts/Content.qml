pragma ComponentBehavior: Bound

import "./kblayout"
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property PopoutState popouts
    readonly property Popout requestedPopout: content.children.find(c => c.name === root.popouts.currentName) ?? null
    property Popout currentPopout
    readonly property Item current: currentPopout?.shouldBeActive ? (currentPopout.item as Item) : null

    readonly property var trayItemsToIndices: SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id)).reduce((acc, item, i) => {
        acc[item.id] = i;
        return acc;
    }, {})

    Binding on implicitWidth {
        when: root.currentPopout?.ready ?? false
        delayed: true
        restoreMode: Binding.RestoreNone
        value: root.currentPopout ? root.currentPopout.implicitWidth + root.Tokens.padding.large * 2 : 0
    }

    Binding on implicitHeight {
        when: root.currentPopout?.ready ?? false
        delayed: true
        restoreMode: Binding.RestoreNone
        value: root.currentPopout ? root.currentPopout.implicitHeight + root.Tokens.padding.large * 2 : 0
    }

    Item {
        id: content

        anchors.fill: parent
        anchors.margins: Tokens.padding.large

        Popout {
            name: "activewindow"
            sourceComponent: ActiveWindow {
                popouts: root.popouts
            }
        }

        Popout {
            id: networkPopout

            name: "network"
            sourceComponent: Network {
                popouts: root.popouts
                view: Nmcli.activeEthernet ? "ethernet" : "wireless"
            }
        }

        Popout {
            id: passwordPopout

            name: "wirelesspassword"
            sourceComponent: WirelessPassword {
                id: passwordComponent

                popouts: root.popouts
                network: (networkPopout.item as Network)?.passwordNetwork ?? null
            }

            Connections {
                function onCurrentNameChanged() {
                    // Update network immediately when password popout becomes active
                    if (root.popouts.currentName === "wirelesspassword") {
                        // Set network immediately if available
                        if ((networkPopout.item as Network)?.passwordNetwork) {
                            if (passwordPopout.item) {
                                (passwordPopout.item as WirelessPassword).network = (networkPopout.item as Network).passwordNetwork;
                            }
                        }
                        // Also try after a short delay in case networkPopout.item wasn't ready
                        Qt.callLater(() => {
                            if (passwordPopout.item && (networkPopout.item as Network)?.passwordNetwork) {
                                (passwordPopout.item as WirelessPassword).network = (networkPopout.item as Network).passwordNetwork;
                            }
                        }, 100);
                    }
                }

                target: root.popouts
            }

            Connections {
                function onItemChanged() {
                    // When network popout loads, update password popout if it's active
                    if (root.popouts.currentName === "wirelesspassword" && passwordPopout.item) {
                        Qt.callLater(() => {
                            if ((networkPopout.item as Network)?.passwordNetwork) {
                                (passwordPopout.item as WirelessPassword).network = (networkPopout.item as Network).passwordNetwork;
                            }
                        });
                    }
                }

                target: networkPopout
            }
        }

        Popout {
            name: "bluetooth"
            sourceComponent: Bluetooth {
                popouts: root.popouts
            }
        }

        Popout {
            name: "battery"
            sourceComponent: Battery {}
        }

        Popout {
            name: "audio"
            sourceComponent: AudioPopout {
                popouts: root.popouts
            }
        }

        Popout {
            name: "kblayout"
            sourceComponent: KbLayout {}
        }

        Popout {
            name: "lockstatus"
            sourceComponent: LockStatus {}
        }

        Repeater {
            model: ScriptModel {
                values: SystemTray.items.values.filter(i => i.hasMenu && i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))
            }

            Popout {
                id: trayMenu

                required property SystemTrayItem modelData

                name: `traymenu${root.trayItemsToIndices[modelData.id]}`
                sourceComponent: trayMenuComp

                Component {
                    id: trayMenuComp

                    TrayMenu {
                        popouts: root.popouts
                        trayItem: trayMenu.modelData.menu // qmllint disable incompatible-type
                    }
                }
            }
        }
    }

    component Popout: Loader {
        id: popout

        required property string name
        readonly property bool ready: status === Loader.Ready && ((item as TrayMenu)?.ready ?? true)
        readonly property bool shouldBeActive: root.popouts.hasCurrent && root.requestedPopout === popout && ready

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        active: root.requestedPopout === popout || root.currentPopout === popout || opacity > 0
        enabled: shouldBeActive
        opacity: shouldBeActive ? 1 : 0

        onShouldBeActiveChanged: {
            if (shouldBeActive)
                root.currentPopout = popout;
        }

        Behavior on opacity {
            Anim {
                type: popout.shouldBeActive ? Anim.SlowEffects : Anim.DefaultEffects
            }
        }
    }
}
