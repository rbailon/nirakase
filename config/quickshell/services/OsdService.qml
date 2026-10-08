pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root

    // OSD Types: "volume", "mic", "brightness", "kbd_brightness", "capslock", "numlock", "powerprofile"
    property string osdType: "volume"
    property real level: 50
    property bool isMuted: false
    property bool isHeadphones: false
    property string icon: "󰕾"
    property string label: "50%"
    property string stateText: ""
    property color stateColor: Theme.accent

    signal osdTriggered()

    // -------------------------------------------------------------
    // Audio Output (Sink / Speakers & Headphones)
    // -------------------------------------------------------------
    Process {
        id: sinkProcess
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length >= 3) {
                    root.osdType = "volume";
                    root.isMuted = (parts[0] === "YES");
                    root.isHeadphones = (parts[1] === "YES");
                    root.level = Math.max(0, Math.min(100, parseInt(parts[2]) || 0));
                    root.label = root.isMuted ? "MUTE" : root.level + "%";

                    if (root.isHeadphones) {
                        root.icon = root.isMuted ? "󰟎" : "󰋋";
                    } else {
                        if (root.isMuted || root.level === 0) root.icon = "󰝟";
                        else if (root.level <= 33) root.icon = "󰕿";
                        else if (root.level <= 66) root.icon = "󰖀";
                        else root.icon = "󰕾";
                    }
                    root.stateColor = root.isMuted ? Theme.danger : Theme.accent;
                    root.osdTriggered();
                }
            }
        }
    }

    function runSinkCommand(actionCmd) {
        var query = "vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
                    "muted=$(echo \"$vol_raw\" | grep -q 'MUTED' && echo 'YES' || echo 'NO'); " +
                    "vol_num=$(echo \"$vol_raw\" | awk '{print $2}'); " +
                    "vol_pct=$(awk -v v=\"$vol_num\" 'BEGIN { printf \"%d\", (v * 100) }'); " +
                    "sink_info=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
                    "is_hp=$(echo \"$sink_info\" | grep -iE 'headphone|headset|auricular' && echo 'YES' || echo 'NO'); " +
                    "echo \"$muted:$is_hp:$vol_pct\"";
        var full = actionCmd ? (actionCmd + "; " + query) : query;
        sinkProcess.command = ["bash", "-c", full];
        sinkProcess.running = true;
    }

    function volumeRaise(step) {
        var s = (step !== undefined && step !== "") ? step : "5%";
        runSinkCommand("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + s + "+ -l 1.0");
    }

    function volumeLower(step) {
        var s = (step !== undefined && step !== "") ? step : "5%";
        runSinkCommand("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + s + "-");
    }

    function volumeMuteToggle() {
        runSinkCommand("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
    }

    // -------------------------------------------------------------
    // Audio Input (Source / Microphone)
    // -------------------------------------------------------------
    Process {
        id: sourceProcess
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length >= 2) {
                    root.osdType = "mic";
                    root.isMuted = (parts[0] === "YES");
                    root.level = Math.max(0, Math.min(100, parseInt(parts[1]) || 0));
                    root.label = root.isMuted ? "MUTE" : root.level + "%";
                    root.icon = root.isMuted ? "󰍭" : "󰍬";
                    root.stateColor = root.isMuted ? Theme.danger : Theme.accent;
                    root.osdTriggered();
                }
            }
        }
    }

    function runSourceCommand(actionCmd) {
        var query = "vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null); " +
                    "muted=$(echo \"$vol_raw\" | grep -q 'MUTED' && echo 'YES' || echo 'NO'); " +
                    "vol_num=$(echo \"$vol_raw\" | awk '{print $2}'); " +
                    "vol_pct=$(awk -v v=\"$vol_num\" 'BEGIN { printf \"%d\", (v * 100) }'); " +
                    "echo \"$muted:$vol_pct\"";
        var full = actionCmd ? (actionCmd + "; " + query) : query;
        sourceProcess.command = ["bash", "-c", full];
        sourceProcess.running = true;
    }

    function micRaise(step) {
        var s = (step !== undefined && step !== "") ? step : "5%";
        runSourceCommand("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + s + "+ -l 1.0");
    }

    function micLower(step) {
        var s = (step !== undefined && step !== "") ? step : "5%";
        runSourceCommand("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + s + "-");
    }

    function micMuteToggle() {
        runSourceCommand("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle");
    }

    // -------------------------------------------------------------
    // Monitor Brightness
    // -------------------------------------------------------------
    Process {
        id: brightnessProcess
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var val = parseInt(data.trim());
                if (!isNaN(val)) {
                    root.osdType = "brightness";
                    root.isMuted = false;
                    root.level = Math.max(0, Math.min(100, val));
                    root.label = root.level + "%";
                    if (root.level <= 33) root.icon = "󰃞";
                    else if (root.level <= 66) root.icon = "󰃟";
                    else root.icon = "󰃠";
                    root.stateColor = Theme.accent;
                    root.osdTriggered();
                }
            }
        }
    }

    function runBrightnessCommand(actionCmd) {
        var query = "brightnessctl -m --class=backlight info | awk -F',' '{print $4}' | tr -d '%'";
        var full = actionCmd ? (actionCmd + "; " + query) : query;
        brightnessProcess.command = ["bash", "-c", full];
        brightnessProcess.running = true;
    }

    function brightnessRaise(step) {
        var s = (step !== undefined && step !== "") ? step : "5%";
        runBrightnessCommand("brightnessctl --class=backlight set " + s + "+");
    }

    function brightnessLower(step) {
        var s = (step !== undefined && step !== "") ? step : "5%";
        runBrightnessCommand("brightnessctl --class=backlight set " + s + "-");
    }

    // -------------------------------------------------------------
    // Keyboard Backlight (brightnessctl --device='*kbd_backlight*')
    // -------------------------------------------------------------
    Process {
        id: kbdProcess
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var clean = data.trim();
                if (clean !== "ERR") {
                    var val = parseInt(clean);
                    if (!isNaN(val)) {
                        root.osdType = "kbd_brightness";
                        root.isMuted = false;
                        root.level = Math.max(0, Math.min(100, val));
                        root.label = root.level + "%";
                        root.icon = (root.level === 0) ? "󰌐" : "󰌌";
                        root.stateColor = Theme.accent;
                        root.osdTriggered();
                    }
                }
            }
        }
    }

    function runKbdCommand(actionCmd) {
        var query = "info=$(brightnessctl -m --device='*kbd_backlight*' info 2>/dev/null); " +
                    "if [ -n \"$info\" ]; then echo \"$info\" | awk -F',' '{print $4}' | tr -d '%'; else echo 'ERR'; fi";
        var full = actionCmd ? (actionCmd + "; " + query) : query;
        kbdProcess.command = ["bash", "-c", full];
        kbdProcess.running = true;
    }

    function kbdBrightnessRaise(step) {
        var s = (step !== undefined && step !== "") ? step : "+1";
        runKbdCommand("brightnessctl --device='*kbd_backlight*' set " + s + " 2>/dev/null || brightnessctl --device='*kbd_backlight*' set 10%+ 2>/dev/null");
    }

    function kbdBrightnessLower(step) {
        var s = (step !== undefined && step !== "") ? step : "1-";
        runKbdCommand("brightnessctl --device='*kbd_backlight*' set " + s + " 2>/dev/null || brightnessctl --device='*kbd_backlight*' set 10%- 2>/dev/null");
    }

    // -------------------------------------------------------------
    // Caps Lock & Num Lock
    // -------------------------------------------------------------
    function showCaps(active) {
        osdType = "capslock";
        icon = "󰬈";
        isMuted = !active;
        stateText = active ? "MAYÚSCULAS: ON" : "MAYÚSCULAS: OFF";
        stateColor = active ? Theme.accent : Theme.textMuted;
        level = active ? 100 : 0;
        label = active ? "ON" : "OFF";
        osdTriggered();
    }

    function showNum(active) {
        osdType = "numlock";
        icon = "󰎠";
        isMuted = !active;
        stateText = active ? "BLOQ NUM: ON" : "BLOQ NUM: OFF";
        stateColor = active ? Theme.accent : Theme.textMuted;
        level = active ? 100 : 0;
        label = active ? "ON" : "OFF";
        osdTriggered();
    }

    Process {
        id: capsQueryProcess
        command: ["bash", "-c", "[ \"$(cat /sys/class/leds/*::capslock/brightness 2>/dev/null | grep -m 1 '^1$')\" = '1' ] && echo ON || echo OFF"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.showCaps(data.trim() === "ON")
        }
    }

    Process {
        id: numQueryProcess
        command: ["bash", "-c", "[ \"$(cat /sys/class/leds/*::numlock/brightness 2>/dev/null | grep -m 1 '^1$')\" = '1' ] && echo ON || echo OFF"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.showNum(data.trim() === "ON")
        }
    }

    function checkCapsLock() {
        capsQueryProcess.running = true;
    }

    function checkNumLock() {
        numQueryProcess.running = true;
    }

    // Background watcher for hardware keyboard lock events
    Process {
        id: lockWatcherProcess
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/lock-watcher.py"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim();
                if (line === "CAPSLOCK:ON") root.showCaps(true);
                else if (line === "CAPSLOCK:OFF") root.showCaps(false);
                else if (line === "NUMLOCK:ON") root.showNum(true);
                else if (line === "NUMLOCK:OFF") root.showNum(false);
            }
        }
    }

    // -------------------------------------------------------------
    // Power Profiles (powerprofilesctl)
    // -------------------------------------------------------------
    function applyPowerProfile(profile) {
        osdType = "powerprofile";
        isMuted = false;
        if (profile === "power-saver") {
            icon = "󰌪";
            stateText = "AHORRO DE ENERGÍA";
            stateColor = Theme.success;
            level = 33;
        } else if (profile === "performance") {
            icon = "󰓅";
            stateText = "ALTO RENDIMIENTO";
            stateColor = Theme.danger;
            level = 100;
        } else {
            icon = "󰗑";
            stateText = "EQUILIBRADO";
            stateColor = Theme.accent;
            level = 66;
        }
        label = profile.toUpperCase();
        osdTriggered();
    }

    Process {
        id: powerProfileProcess
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var p = data.trim();
                if (p === "power-saver" || p === "balanced" || p === "performance") {
                    root.applyPowerProfile(p);
                }
            }
        }
    }

    function powerProfileCycle() {
        var cycleCmd = "curr=$(powerprofilesctl get 2>/dev/null || echo 'balanced'); " +
                       "case \"$curr\" in " +
                       "    power-saver) next='balanced' ;; " +
                       "    balanced) next='performance' ;; " +
                       "    performance) next='power-saver' ;; " +
                       "    *) next='balanced' ;; " +
                       "esac; " +
                       "powerprofilesctl set \"$next\" 2>/dev/null; " +
                       "echo \"$next\"";
        powerProfileProcess.command = ["bash", "-c", cycleCmd];
        powerProfileProcess.running = true;
    }

    function powerProfileSet(profile) {
        var setCmd = "powerprofilesctl set \"" + profile + "\" 2>/dev/null; echo \"" + profile + "\"";
        powerProfileProcess.command = ["bash", "-c", setCmd];
        powerProfileProcess.running = true;
    }
}
