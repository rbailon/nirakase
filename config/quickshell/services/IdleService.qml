pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

Singleton {
    id: root

    // Controls whether the timeout settings subpanel is open in Control Center
    property bool idlePanelOpen: false

    // Manual inhibition state ("Caffeine Mode") persisted in Config
    readonly property bool inhibited: Config.idle ? (Config.idle.inhibited === true) : false
    readonly property bool isIdleActive: !inhibited

    // Configurable timeouts in seconds (0 = disabled)
    readonly property int dimTimeout: (Config.idle && Config.idle.dimTimeout !== undefined) ? Number(Config.idle.dimTimeout) : 150
    readonly property int lockTimeout: (Config.idle && Config.idle.lockTimeout !== undefined) ? Number(Config.idle.lockTimeout) : 300
    readonly property int dpmsTimeout: (Config.idle && Config.idle.dpmsTimeout !== undefined) ? Number(Config.idle.dpmsTimeout) : 330
    readonly property int suspendTimeout: (Config.idle && Config.idle.suspendTimeout !== undefined) ? Number(Config.idle.suspendTimeout) : 900

    // Current Wayland monitor states
    readonly property bool isDpmsOff: dpmsMonitor.isIdle

    // Icon and descriptive status strings
    readonly property string icon: isIdleActive ? "󰒲" : "󰒳"
    readonly property string statusText: isIdleActive ? "Idle: Active" : "Caffeine: Active"
    readonly property string summaryText: {
        if (inhibited) return "Manually inhibited (Caffeine Mode)";
        var parts = [];
        if (lockTimeout > 0) parts.push("Lock " + formatDuration(lockTimeout));
        if (suspendTimeout > 0) parts.push("Suspend " + formatDuration(suspendTimeout));
        return parts.length > 0 ? parts.join(" · ") : "No active timers";
    }

    function formatDuration(seconds) {
        var sec = Number(seconds) || 0;
        if (sec <= 0) return "Never";
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        if (m > 0 && s > 0) return m + "m " + s + "s";
        if (m > 0) return m + " min";
        return s + " s";
    }

    function toggleInhibit() {
        Config.set("idle.inhibited", !root.inhibited);
    }

    function setInhibited(val) {
        Config.set("idle.inhibited", !!val);
    }

    function setDimTimeout(sec) {
        Config.set("idle.dimTimeout", Math.max(0, Number(sec) || 0));
    }

    function setLockTimeout(sec) {
        Config.set("idle.lockTimeout", Math.max(0, Number(sec) || 0));
    }

    function setDpmsTimeout(sec) {
        Config.set("idle.dpmsTimeout", Math.max(0, Number(sec) || 0));
    }

    function setSuspendTimeout(sec) {
        Config.set("idle.suspendTimeout", Math.max(0, Number(sec) || 0));
    }

    function resetDefaults() {
        Config.set("idle.dimTimeout", 150);
        Config.set("idle.lockTimeout", 300);
        Config.set("idle.dpmsTimeout", 330);
        Config.set("idle.suspendTimeout", 900);
    }

    function lockNow() {
        lockProc.exec(["sh", "-c", "pidof swaylock >/dev/null || swaylock -f"]);
    }

    function suspendNow() {
        suspendProc.exec(["sh", "-c", "(pidof swaylock >/dev/null || swaylock -f) & sleep 0.3 && systemctl suspend"]);
    }

    // ── Processes for running actions ─────────────────────────────
    property bool isDimmed: false

    Process { id: dimProc }
    Process { id: lockProc }
    Process { id: dpmsProc }
    Process { id: suspendProc }

    Timer {
        id: restoreBrightnessTimer
        interval: 300
        repeat: false
        onTriggered: {
            dimProc.exec(["brightnessctl", "--class=backlight", "-r"]);
            root.isDimmed = false;
        }
    }

    function restoreBrightness(delayed) {
        if (!root.isDimmed) return;
        dimProc.exec(["brightnessctl", "--class=backlight", "-r"]);
        if (delayed) {
            restoreBrightnessTimer.interval = 300;
            restoreBrightnessTimer.restart();
        } else if (!restoreBrightnessTimer.running) {
            restoreBrightnessTimer.interval = 50;
            restoreBrightnessTimer.restart();
        }
    }

    // Stage 1: Dim screen (default 150s / 2m 30s)
    IdleMonitor {
        id: dimMonitor
        enabled: !root.inhibited && root.dimTimeout > 0
        timeout: root.dimTimeout > 0 ? root.dimTimeout : 150
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                if (!root.isDimmed) {
                    restoreBrightnessTimer.stop();
                    root.isDimmed = true;
                    dimProc.exec([
                        "sh", "-c",
                        "cur=$(brightnessctl --class=backlight g); max=$(brightnessctl --class=backlight m); target=$((max / 10)); if [ \"$cur\" -gt \"$target\" ]; then brightnessctl --class=backlight -s set 10%; else brightnessctl --class=backlight -s; fi"
                    ]);
                }
            } else {
                root.restoreBrightness(false);
            }
        }
    }

    // Stage 2: Lock session with swaylock (default 300s / 5m)
    IdleMonitor {
        id: lockMonitor
        enabled: !root.inhibited && root.lockTimeout > 0
        timeout: root.lockTimeout > 0 ? root.lockTimeout : 300
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                root.lockNow();
            }
        }
    }

    // Stage 3: Power off monitors via Niri DPMS (default 330s / 5m 30s)
    IdleMonitor {
        id: dpmsMonitor
        enabled: !root.inhibited && root.dpmsTimeout > 0
        timeout: root.dpmsTimeout > 0 ? root.dpmsTimeout : 330
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                dpmsProc.exec(["niri", "msg", "action", "power-off-monitors"]);
            } else {
                dpmsProc.exec(["niri", "msg", "action", "power-on-monitors"]);
                root.restoreBrightness(true);
            }
        }
    }

    // Stage 4: Suspend system (default 900s / 15m)
    IdleMonitor {
        id: suspendMonitor
        enabled: !root.inhibited && root.suspendTimeout > 0
        timeout: root.suspendTimeout > 0 ? root.suspendTimeout : 900
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                root.suspendNow();
            }
        }
    }
}
