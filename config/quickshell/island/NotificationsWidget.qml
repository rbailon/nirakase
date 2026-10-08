import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services" // Path to NotificationService
import "../components" // Path to StatusIndicatorButton

StatusIndicatorButton {
    id: root

    signal openRequested()
    signal closeRequested()

    // Direct reactive binding with the service
    count: NotificationService.unreadCount
    available: true
    active: !NotificationService.dnd

    // Dynamic icon (JetBrainsMono Nerd Font Propo)
    icon: {
        if (NotificationService.dnd) return "󰂛"; // Bell slashed / DND
        if (root.count > 0) return "󰂚";          // Active bell with notifications
        return "󰂜";                              // Empty bell / no notifications
    }

    // Badge color: Red if there are notifications, or muted in DND
    badgeColor: NotificationService.dnd ? "#6E6E73" : "#E03838"

    // Waybar-style informative tooltip
    tooltip: {
        if (NotificationService.dnd) {
            return "Modo No Molestar ACTIVO\n[Clic der: Desactivar DND]";
        }
        if (root.count > 0) {
            return root.count + " notificación(es) pendiente(s)\n[Clic der: Activar No Molestar]\n[Clic izq: Limpiar bandeja]";
        }
        return "Sin notificaciones pendientes\n[Clic der: Activar No Molestar]";
    }

    // Clicks
    onClicked: {
        // NotificationService.clearAll();
        root.openRequested();
    }

    onRightClicked: {
        // Right click: toggle Do Not Disturb mode
        NotificationService.toggleDnd();
    }

    // State for temporary blinking animation
    property bool isBlinking: false

    // Gently blinks 3 times when a new notification arrives
    SequentialAnimation on opacity {
        id: blinkAnim
        running: root.isBlinking
        loops: 3

        NumberAnimation { to: 0.3; duration: 250; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 250; easing.type: Easing.InOutQuad }

        onFinished: root.isBlinking = false
    }

    // Listen to new notification signal from service
    Connections {
        target: NotificationService
        function onNotificationReceived(notif) {
            if (!NotificationService.dnd) {
                root.isBlinking = true;
            }
        }
    }
}
