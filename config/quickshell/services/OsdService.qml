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
    // Audio Output & Input via native Pipewire (AudioService)
    // -------------------------------------------------------------
    function parseStepPct(step) {
        if (step === undefined || step === "") return 5;
        var n = parseInt(String(step).replace("%", ""));
        return isNaN(n) ? 5 : n;
    }

    function showVolumeOsd(vol, muted) {
        root.osdType = "volume";
        root.isMuted = muted;
        root.isHeadphones = AudioService.isHeadphones;
        root.level = Math.max(0, Math.min(100, vol));
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

    function volumeRaise(step) {
        var delta = parseStepPct(step);
        var nextVol = Math.max(0, Math.min(100, AudioService.volume + delta));
        AudioService.setVolume(nextVol);
        showVolumeOsd(nextVol, AudioService.isMuted);
    }

    function volumeLower(step) {
        var delta = parseStepPct(step);
        var nextVol = Math.max(0, Math.min(100, AudioService.volume - delta));
        AudioService.setVolume(nextVol);
        showVolumeOsd(nextVol, AudioService.isMuted);
    }

    function volumeMuteToggle() {
        var nextMuted = !AudioService.isMuted;
        AudioService.toggleMute();
        showVolumeOsd(AudioService.volume, nextMuted);
    }

    function showMicOsd(vol, muted) {
        root.osdType = "mic";
        root.isMuted = muted;
        root.level = Math.max(0, Math.min(100, vol));
        root.label = root.isMuted ? "MUTE" : root.level + "%";
        root.icon = (root.isMuted || root.level === 0) ? "󰍭" : "󰍬";
        root.stateColor = root.isMuted ? Theme.danger : Theme.accent;
        root.osdTriggered();
    }

    function micRaise(step) {
        var delta = parseStepPct(step);
        var nextVol = Math.max(0, Math.min(100, AudioService.micVolume + delta));
        AudioService.setMicVolume(nextVol);
        showMicOsd(nextVol, AudioService.isMicMuted);
    }

    function micLower(step) {
        var delta = parseStepPct(step);
        var nextVol = Math.max(0, Math.min(100, AudioService.micVolume - delta));
        AudioService.setMicVolume(nextVol);
        showMicOsd(nextVol, AudioService.isMicMuted);
    }

    function micMuteToggle() {
        var nextMuted = !AudioService.isMicMuted;
        AudioService.toggleMicMute();
        showMicOsd(AudioService.micVolume, nextMuted);
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
        stateText = active ? "CAPS LOCK: ON" : "CAPS LOCK: OFF";
        stateColor = active ? Theme.accent : Theme.textMuted;
        level = active ? 100 : 0;
        label = active ? "ON" : "OFF";
        osdTriggered();
    }

    function showNum(active) {
        osdType = "numlock";
        icon = "󰎠";
        isMuted = !active;
        stateText = active ? "NUM LOCK: ON" : "NUM LOCK: OFF";
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
    // Power Profiles via native UPower (PowerService)
    // -------------------------------------------------------------
    function applyPowerProfile(profile) {
        osdType = "powerprofile";
        isMuted = false;
        if (profile === "power-saver") {
            icon = "󰌪";
            stateText = "POWER SAVER";
            stateColor = Theme.success;
            level = 33;
        } else if (profile === "performance") {
            icon = "󰓅";
            stateText = "HIGH PERFORMANCE";
            stateColor = Theme.danger;
            level = 100;
        } else {
            icon = "󰗑";
            stateText = "BALANCED";
            stateColor = Theme.accent;
            level = 66;
        }
        label = profile.toUpperCase();
        osdTriggered();
    }

    function powerProfileCycle() {
        var nextProfile = PowerService.cycleProfile();
        applyPowerProfile(nextProfile);
    }

    function powerProfileSet(profile) {
        PowerService.setProfile(profile);
        applyPowerProfile(profile);
    }
}
