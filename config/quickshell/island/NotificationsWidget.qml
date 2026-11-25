import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services" // Path to NotificationService
import "../components" // Path to StatusIndicatorButton

StatusIndicatorButton {
    id: root

    signal openRequested()
    signal closeRequested()

    // Direct reactive binding with the service
    count: NotificationService.unreadCount
    available: true
    // Dim icon when DND is active or notification sound is muted (matches UpdatesWidget inactive style)
    active: !NotificationService.dnd && NotificationService.soundEnabled

    // Dynamic icon (JetBrainsMono Nerd Font Propo)
    icon: {
        if (NotificationService.dnd) return "󰂛"; // Bell slashed / DND
        if (root.count > 0) return "󰂚";          // Active bell with notifications
        return "󰂜";                              // Empty bell / no notifications
    }

    // Dot-only top badge matching UpdatesWidget behavior
    dotOnly: true
    showBadge: root.count > 0
    badgeColor: {
        if (NotificationService.dnd) return Theme.textMuted || "#6E6E73";
        if (NotificationService.hasCritical) return Theme.danger || "#E03838";
        return Theme.accent || "#3584E4";
    }

    // Waybar-style informative tooltip
    tooltip: {
        var soundAction = NotificationService.soundEnabled ? "Mute sound" : "Enable sound";
        var dndAction = NotificationService.dnd ? "Disable DND" : "Enable DND";
        var statusLine;
        if (NotificationService.dnd) {
            statusLine = "Do Not Disturb: ON";
            if (root.count > 0) {
                statusLine += " (" + root.count + " pending)";
            }
        } else if (root.count > 0) {
            statusLine = root.count + " pending notification(s)";
            if (NotificationService.hasCritical) {
                statusLine += " (Critical)";
            }
        } else {
            statusLine = "No pending notifications";
        }
        var soundLine = NotificationService.soundEnabled ? "Sound: ON" : "Sound: Muted";
        return statusLine + "\n" + soundLine
            + "\n[Left click: " + soundAction + "]"
            + "\n[Right click: " + dndAction + "]"
            + "\n[Middle click: Control Center]";
    }

    // Clicks
    onClicked: {
        // Left click: toggle notification sound
        NotificationService.toggleSound();
    }

    onRightClicked: {
        // Right click: toggle Do Not Disturb mode
        NotificationService.toggleDnd();
    }

    onMiddleClicked: {
        // Middle click: open/close Control Center
        root.openRequested();
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
