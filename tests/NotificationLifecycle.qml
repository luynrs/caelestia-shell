import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.notifications as Notifications

ShellRoot {
    id: root

    property int failures: 0
    property NotifData notification
    property bool popupActive: true

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    Component {
        id: notificationComponent

        NotifData {
            popup: true
            summary: "Lifecycle regression"
            body: "A notification must outlive the delegate that displays it."
            appName: "Notification lifecycle test"
            hints: ({})
            expireTimeout: 60000
        }
    }

    PanelWindow {
        id: container
        visible: true
        implicitWidth: 500
        implicitHeight: 500

        ScreenState {
            id: testState
            modelData: Quickshell.screens[0]
        }

        Notifications.Content {
            width: 500
            screenState: testState
            osdPanel: container.contentItem
            sessionPanel: container.contentItem
            utilitiesPanel: container.contentItem
        }

        Loader {
            id: popup

            active: root.popupActive && root.notification !== null
            sourceComponent: Notifications.Notification {
                modelData: root.notification
                implicitWidth: 400
            }
        }
    }

    Component.onCompleted: {
        notification = notificationComponent.createObject(root);
        Notifs.list = [notification];
    }

    Timer {
        interval: 100
        running: true
        onTriggered: {
            root.check(popup.item !== null, "The popup delegate must load");
            root.check(root.notification.locks.size === 2, "Every visible popup must retain its notification");
            root.notification.close();
            root.check(Notifs.list.length === 1, "Closing must retain data while its delegate is live");
            root.popupActive = false;
            retained.start();
            finish.start();
        }
    }

    Timer {
        id: retained
        interval: 32
        onTriggered: {
            root.check(root.notification !== null && Notifs.list.length === 1, "A closing popup must retain its data through delayed removal");
            root.check(root.notification?.locks.size === 1, "Removing one delegate must preserve the remaining popup lock");
        }
    }

    Timer {
        id: finish
        interval: 1000
        onTriggered: {
            root.check(Notifs.list.length === 0, "Destroying the final delegate must release closed data");
            root.check(root.notification === null, "Closed notification data must be destroyed after its delegates");
            root.notification = notificationComponent.createObject(root);
            Notifs.list = [root.notification];
            root.popupActive = true;
            expire.start();
        }
    }

    Timer {
        id: expire
        interval: 100
        onTriggered: {
            root.check(root.notification.locks.size === 2, "A subsequent notification must acquire both popup locks");
            root.notification.popup = false;
            root.popupActive = false;
            expired.start();
        }
    }

    Timer {
        id: expired
        interval: 1000
        onTriggered: {
            root.check(root.notification !== null && Notifs.list.length === 1, "Popup expiry must preserve notification history");
            root.check(root.notification.locks.size === 0, "Expired popup delegates must release all locks");
            root.notification.close();
            cleanup.start();
        }
    }

    Timer {
        id: cleanup
        interval: 100
        onTriggered: {
            root.check(Notifs.list.length === 0 && root.notification === null, "Closing expired history must destroy its data");
            console.log("Notification lifecycle failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
