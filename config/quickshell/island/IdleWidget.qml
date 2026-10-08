import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import '../components/'
import ".."

StatusIndicatorButton {
    id: root

    // hypridle service state
    property bool isIdleActive: true

    // Bindings with StatusIndicatorButton
    available: true
    active: root.isIdleActive
    icon: root.isIdleActive ? "󰒲" : "󰒳" // Normal : Inhibited

    // Status dot configuration
    dotOnly: true
    showBadge: !root.isIdleActive  // Shows the dot only when idle is inhibited
    badgeColor: "#E5A50A"          // Warning amber/orange color

    // Left and right click toggle the service
    onClicked: root.toggleIdle()
    onRightClicked: root.toggleIdle()

    Process { id: iwLeftClick }

    function toggleIdle() {
        var action = root.isIdleActive ? "stop" : "start";
        iwLeftClick.exec(["systemctl", "--user", action, "hypridle.service"]);

        // Optimistic UI update
        root.isIdleActive = !root.isIdleActive;
        quickRefreshTimer.restart();
    }

    // Process to check if hypridle.service is active
    Process {
        id: statusProcess
        command: ["systemctl", "--user", "is-active", "hypridle.service"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root.isIdleActive = (data.trim() === "active");
            }
        }
    }

    // Periodic check every 3 seconds
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statusProcess.running) statusProcess.running = true;
        }
    }

    // Quick refresh after interaction
    Timer {
        id: quickRefreshTimer
        interval: 300
        onTriggered: {
            if (!statusProcess.running) statusProcess.running = true;
        }
    }
}
