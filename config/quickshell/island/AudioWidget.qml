import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import '../components/'
import ".."

IconButtonBar {
    id: root

    // Audio state
    property bool isMuted: false
    property bool isHeadphones: false
    property int volumeLevel: 50 // 0 to 100

    // Bindings with IconButtonBar
    available: true
    active: !root.isMuted

    // Dynamic icon selection based on output, mute and level
    icon: {
        // Case 1: Active output is HEADPHONES
        if (root.isHeadphones) {
            return root.isMuted ? "󰟎" : "󰋋" // Muted : Playing
        }

        // Case 2: Active output is SPEAKERS
        if (root.isMuted || root.volumeLevel === 0) {
            return "󰝟" // Muted
        }

        if (root.volumeLevel <= 33) return "󰕿"      // Low volume
        if (root.volumeLevel <= 66) return "󰖀"      // Medium volume
        return "󰕾"                                  // High volume
    }

    tooltip: (isHeadphones ? "Auriculares" : "Altavoces") + " (" + volumeLevel + "%)" + (isMuted ? " [Silenciado]" : "")

    Process { id: awClick; }
 
    // Left click: Open terminal audio mixer (e.g. pulsemixer or pavucontrol)
    onClicked: {
        awClick.exec(["xdg-terminal-exec", "--app-id=org.nirakase.audio", "-e", "wiremix"]);
    }

    // Right click: Toggle Mute
    onRightClicked: {
        awClick.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        root.isMuted = !root.isMuted;
        quickRefreshTimer.restart();
    }

    // Process to query volume, mute and device type (Speaker vs Headphones)
    Process {
        id: audioProcess
        command: [
            "bash",
            "-c",
            "vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "if [ -z \"$vol_raw\" ]; then exit 0; fi; " +
            "muted=$(echo \"$vol_raw\" | grep -q 'MUTED' && echo 'YES' || echo 'NO'); " +
            "vol_num=$(echo \"$vol_raw\" | awk '{print $2}'); " +
            "vol_pct=$(awk -v v=\"$vol_num\" 'BEGIN { printf \"%d\", (v * 100) }'); " +
            "sink_info=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "is_hp=$(echo \"$sink_info\" | grep -iE 'headphone|headset|auricular' && echo 'YES' || echo 'NO'); " +
            "echo \"$muted:$is_hp:$vol_pct\""
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length >= 3) {
                    root.isMuted = (parts[0] === "YES");
                    root.isHeadphones = (parts[1] === "YES");
                    root.volumeLevel = parseInt(parts[2]) || 0;
                }
            }
        }
    }

    // Periodic polling every 2.5 seconds
    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!audioProcess.running) audioProcess.running = true;
        }
    }

    // Quick refresh after right click
    Timer {
        id: quickRefreshTimer
        interval: 200
        onTriggered: {
            if (!audioProcess.running) audioProcess.running = true;
        }
    }
}
