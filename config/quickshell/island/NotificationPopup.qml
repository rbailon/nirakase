import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import ".."
import "../components"
import "../services"

PanelWindow {
    id: popupWindow

    anchors {
        top: true
        right: true
    }

    margins {
        top: 14
        right: 14
    }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    implicitWidth: 360
    implicitHeight: card.implicitHeight
    color: "transparent"

    readonly property var currentNotif: NotificationService.currentPopup
    readonly property bool isCritical: currentNotif !== null && currentNotif.urgency === NotificationUrgency.Critical

    visible: currentNotif !== null

    // Temporizador de autocierre (se pausa si está hovered o si es crítica)
    Timer {
        id: autoCloseTimer
        interval: {
            if (!popupWindow.currentNotif) return 5000;
            var timeout = popupWindow.currentNotif.expireTimeout;
            return (timeout && timeout > 0) ? timeout : 5000;
        }
        running: popupWindow.visible && !popupWindow.isCritical && !card.hovered
        repeat: false
        onTriggered: {
            NotificationService.currentPopup = null;
        }
    }

    NotificationsCard {
        id: card
        width: parent.width
        notification: popupWindow.currentNotif

        // Animación de deslizamiento y desvanecimiento
        transform: Translate {
            x: popupWindow.visible ? 0 : 40
            Behavior on x {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        opacity: popupWindow.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        onDismissed: {
            NotificationService.currentPopup = null;
        }

        onActionInvoked: {
            NotificationService.currentPopup = null;
        }
    }
}
