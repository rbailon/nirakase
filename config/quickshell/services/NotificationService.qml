pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."

Item {
    id: root

    readonly property string _systemSoundDir: "/usr/share/sounds/freedesktop/stereo"
    readonly property int _soundCooldownMs: 350

    // Do Not Disturb (DND) and sound preferences persisted in Config
    readonly property bool dnd: Config.notifications ? (Config.notifications.dnd === true) : false
    readonly property bool soundEnabled: (Config.notifications && Config.notifications.soundEnabled !== undefined)
        ? (Config.notifications.soundEnabled === true)
        : true
    readonly property string soundFile: (Config.notifications && Config.notifications.soundFile)
        ? String(Config.notifications.soundFile).trim()
        : ""
    readonly property string soundName: (Config.notifications && Config.notifications.soundName)
        ? String(Config.notifications.soundName).trim()
        : "message-new-instant"
    readonly property string criticalSoundName: (Config.notifications && Config.notifications.criticalSoundName)
        ? String(Config.notifications.criticalSoundName).trim()
        : "dialog-warning"

    // Notification list in center/history
    property var history: []
    property int unreadCount: history.length
    readonly property bool hasCritical: {
        for (var i = 0; i < history.length; i++) {
            if (history[i] && history[i].urgency === NotificationUrgency.Critical) {
                return true;
            }
        }
        return false;
    }

    // Last received notification (for popup toasts)
    property var currentPopup: null

    // Internal sound playback throttling and fallback queue
    property double _lastSoundMs: 0
    property var _pendingSoundCommands: []
    property bool _soundExited: true
    property bool _fallbackScheduled: false

    // Signal emitted when a new notification arrives (for animations/toasts)
    signal notificationReceived(var notification)

    Process {
        id: soundPlayer
        running: false

        onExited: (exitCode, exitStatus) => {
            root._soundExited = true;
            if (exitCode !== 0 && root._pendingSoundCommands.length > 0) {
                root._scheduleFallback();
            } else {
                root._pendingSoundCommands = [];
            }
        }

        onRunningChanged: {
            if (!running && !root._soundExited) {
                root._soundExited = true;
                if (root._pendingSoundCommands.length > 0) {
                    root._scheduleFallback();
                }
            }
        }
    }

    function _scheduleFallback() {
        if (root._fallbackScheduled || root._pendingSoundCommands.length === 0) return;
        root._fallbackScheduled = true;
        Qt.callLater(function() {
            root._fallbackScheduled = false;
            root._startNextSoundCommand();
        });
    }

    function _normalizeSoundFile(rawPath) {
        if (rawPath === null || rawPath === undefined) return "";
        var path = String(rawPath).trim();
        if (path === "") return "";
        if (path.indexOf("file://") === 0) {
            path = path.slice(7);
        }
        if (path.indexOf("~/") === 0) {
            var home = Quickshell.env("HOME");
            if (!home || home === "") return "";
            path = home + path.slice(1);
        }
        if (path.indexOf("/") !== 0) return "";
        if (path.indexOf("\0") !== -1 || path.indexOf("\r") !== -1 || path.indexOf("\n") !== -1) return "";
        if (/(^|\/)\.\.(\/|$)/.test(path)) return "";
        return path;
    }

    function _sanitizeSoundName(rawName) {
        if (rawName === null || rawName === undefined) return "";
        var name = String(rawName).trim();
        if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(name)) return "";
        if (name.indexOf("..") !== -1) return "";
        return name;
    }

    function _startNextSoundCommand() {
        if (soundPlayer.running || root._pendingSoundCommands.length === 0) return;
        var nextCmd = root._pendingSoundCommands.shift();
        root._soundExited = false;
        soundPlayer.exec(nextCmd);
    }

    function playSound(notif) {
        if (!root.soundEnabled || root.dnd) return;
        if (soundPlayer.running) return;

        var hints = (notif && notif.hints) ? notif.hints : null;
        if (hints && (hints["suppress-sound"] === true || hints["suppress-sound"] === 1)) {
            return;
        }

        var now = Date.now();
        if (now - root._lastSoundMs < root._soundCooldownMs) return;
        root._lastSoundMs = now;

        var isCritical = (notif !== null && notif !== undefined && notif.urgency === NotificationUrgency.Critical);
        var customFile = root._normalizeSoundFile(root.soundFile);
        var hintFile = (customFile === "" && hints && hints["sound-file"])
            ? root._normalizeSoundFile(hints["sound-file"])
            : "";
        var fileToPlay = customFile !== "" ? customFile : hintFile;

        var commands = [];
        if (fileToPlay !== "") {
            commands.push(["pw-play", "--media-role", "Notification", fileToPlay]);
            commands.push(["paplay", fileToPlay]);
        }

        var hintName = (customFile === "" && hints && hints["sound-name"])
            ? root._sanitizeSoundName(hints["sound-name"])
            : "";
        var configuredName = root._sanitizeSoundName(isCritical ? root.criticalSoundName : root.soundName);
        var defaultName = isCritical ? "dialog-warning" : "message-new-instant";
        var targetName = hintName || configuredName || defaultName;

        commands.push(["pw-play", "--media-role", "Notification", root._systemSoundDir + "/" + targetName + ".oga"]);
        commands.push(["canberra-gtk-play", "-i", targetName, "-d", "Notification"]);

        if (targetName !== defaultName) {
            commands.push(["pw-play", "--media-role", "Notification", root._systemSoundDir + "/" + defaultName + ".oga"]);
            commands.push(["canberra-gtk-play", "-i", defaultName, "-d", "Notification"]);
        }

        root._pendingSoundCommands = commands;
        root._startNextSoundCommand();
    }

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
                root.playSound(notif);
            }
        }
    }

    // Toggle Do Not Disturb mode
    function toggleDnd() {
        Config.set("notifications.dnd", !root.dnd);
    }

    function setDnd(enabled) {
        Config.set("notifications.dnd", !!enabled);
    }

    // Toggle notification sound playback
    function toggleSound() {
        Config.set("notifications.soundEnabled", !root.soundEnabled);
    }

    function setSoundEnabled(enabled) {
        Config.set("notifications.soundEnabled", !!enabled);
    }

    // Set optional custom audio file path (empty string restores system default)
    function setSoundFile(path) {
        Config.set("notifications.soundFile", path ? String(path).trim() : "");
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
