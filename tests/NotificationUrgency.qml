import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.sidebar as Sidebar

ShellRoot {
    id: root

    property int failures: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            failures++;
        }
    }

    function findText(parent: Item, text: string): Item {
        if (parent.text === text)
            return parent;
        for (const child of parent.children) {
            const found = findText(child, text);
            if (found)
                return found;
        }
        return null;
    }

    NotifData {
        id: notification

        summary: "Urgency regression"
        body: "Urgency body"
        urgency: NotificationUrgency.Critical
    }

    ScreenState {
        id: state

        modelData: Quickshell.screens[0]
    }

    Sidebar.Props {
        id: props
    }

    Item {
        width: 400
        height: 500

        Sidebar.Notif {
            id: card

            width: parent.width
            modelData: notification
            screenState: state
            props: props
            expanded: true
        }
    }

    Timer {
        interval: Tokens.anim.durations.expressiveSlowEffects + 100
        running: true
        onTriggered: {
            root.check(card.color === Colours.palette.m3secondaryContainer, "Critical notification must use its urgency background");
            root.check(root.findText(card, notification.summary)?.color === Colours.palette.m3onSecondaryContainer, "Critical notification summary must use its urgency foreground");
            root.check(card.body?.color === Colours.palette.m3secondary, "Expanded critical notification body must use its urgency foreground");
            card.expanded = false;
            compact.start();
        }
    }

    Timer {
        id: compact

        interval: Tokens.anim.durations.expressiveSlowEffects + 100
        onTriggered: {
            root.check(root.findText(card, notification.body)?.color === Colours.palette.m3secondary, "Compact critical notification body must use its urgency foreground");
            notification.urgency = NotificationUrgency.Normal;
            normalCompact.start();
        }
    }

    Timer {
        id: normalCompact

        interval: Tokens.anim.durations.expressiveSlowEffects + 100
        onTriggered: {
            root.check(root.findText(card, notification.summary)?.color === Colours.palette.m3onSurface, "Normal notification summary must retain its ordinary foreground");
            root.check(root.findText(card, notification.body)?.color === Colours.palette.m3outline, "Compact normal notification body must retain its ordinary foreground");
            card.expanded = true;
            normal.start();
        }
    }

    Timer {
        id: normal

        interval: Tokens.anim.durations.expressiveSlowEffects + 100
        onTriggered: {
            root.check(card.color === Colours.layer(Colours.palette.m3surfaceContainerHigh, 2), "Normal notification must retain its ordinary background");
            root.check(card.body?.color === Colours.palette.m3outline, "Expanded normal notification body must retain its ordinary foreground");
            console.log("Notification urgency failures:", root.failures);
            Qt.exit(root.failures === 0 ? 0 : 1);
        }
    }
}
