pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root

    // Do Not Disturb (DND) mode
    property bool dnd: false

    // Notification list in center/history
    property var history: []
    property int unreadCount: history.length

    // Last received notification (for popup toasts)
    property var currentPopup: null

    // Signal emitted when a new notification arrives (for animations/toasts)
    signal notificationReceived(var notification)

    // Quickshell native D-Bus server (org.freedesktop.Notifications)
    NotificationServer {
        id: server

        // Capabilities supported for the system
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        // Automatically executed when receiving a notification from any application
        onNotification: notif => {
            // Add to local history
            var list = root.history.slice();
            list.unshift(notif);
            notif.tracked = true;
            root.history = list;

            notif.closed.connect(function() {
                root.history = root.history.filter(item => item && item !== notif);
                if (root.currentPopup === notif) {
                    root.currentPopup = null;
                }
            });

            // Emit event for widget and popups (if DND mode is not active)
            root.notificationReceived(notif);

            if (!root.dnd) {
                root.currentPopup = notif;
            }
        }
    }

    // Toggle Do Not Disturb mode
    function toggleDnd() {
        root.dnd = !root.dnd;
    }

    // Dismiss a specific notification
    function dismiss(notif) {
        if (!notif) return;
        root.history = root.history.filter(item => item && item !== notif);
        if (root.currentPopup === notif) {
            root.currentPopup = null;
        }
        notif.dismiss();
    }

    // Clear all notifications
    function clearAll() {
        var oldList = root.history.slice();
        root.history = [];
        root.currentPopup = null;
        for (var i = 0; i < oldList.length; i++) {
            if (oldList[i]) {
                oldList[i].dismiss();
            }
        }
    }
}
