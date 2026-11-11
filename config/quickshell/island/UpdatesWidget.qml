import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import '../components'
import ".."

StatusIndicatorButton {
    id: root

    // Updates breakdown
    property int repoUpdates: 0
    property int aurUpdates: 0
    property bool isChecking: false

    // Reactive binding with StatusIndicatorButton
    count: repoUpdates + aurUpdates
    available: true // Set "count > 0" to hide when up to date
    active: count > 0
    icon: count === 0 ? "󰄬" : "󰚰"  // Updates available : Up to date

    // Badge color: Orange if AUR included, Blue if official only
    dotOnly: true
    showBadge: count > 0
    badgeColor: count > 100 ? Theme.danger : count > 40 ? "#E5A50A" : count === 0 ? "green" : "#3584E4"

    tooltip: count > 0 ? "Updates: " + count + "\n• Official: " + repoUpdates + "\n• AUR: " + aurUpdates + "\n[Left click: Update]" : "System up to date"

    SequentialAnimation on iconColor {
        running: count > 100
        loops: Animation.Infinite
        ColorAnimation { to: "#E03838"; duration: 400 }
        ColorAnimation { to: "#FFFFFF"; duration: 400 }
    }

    Process {
      id: uwLeftClick
    }

    // Left click: Open updater in terminal
    onClicked: {
        uwLeftClick.exec(["xdg-terminal-exec", "--app-id=org.nirakase.update", "-e", "nirakase-update-system"]);
    }

    function refresh() {
        if (!checkProc.running) {
            root.isChecking = true;
            checkProc.running = true;
        }
    }

    // Right click: Force manual check right now
    onRightClicked: {
        root.refresh();
    }

    // Process to count official and AUR packages
    Process {
        id: checkProc
        command: [
            "bash",
            "-c",
            "repo=$(checkupdates 2>/dev/null | wc -l); " +
            "aur=$(paru -Qum 2>/dev/null | wc -l); " +
            "echo \"$repo:$aur\""
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var parts = data.trim().split(":");
                if (parts.length >= 2) {
                    root.repoUpdates = parseInt(parts[0]) || 0;
                    root.aurUpdates = parseInt(parts[1]) || 0;
                }
                root.isChecking = false;
            }
        }
    }

    // Automatic check every 30 minutes (1800000 ms)
    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkProc.running) checkProc.running = true;
        }
    }
}
