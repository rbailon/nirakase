import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import '../components/'
import ".."

IconButtonBar {
    id: root

    // Internal state property
    property bool isPowered: false

    // Reactive IconButtonBar configuration
    available: false // Dynamically updated if hardware is present
    active: root.isPowered
    icon: root.isPowered ? "󰂯" : "󰂲" // Active : Inactive

    Process { id: bwClick; }
    
    // Click actions delegated to IconButtonBar native signals
    onClicked: {
        bwClick.exec(["xdg-terminal-exec", "--app-id=org.nirakase.bluetooth", "-e", "bluetui"]);
    }

    onRightClicked: {
        root.toggleBluetooth();
    }

    // Hardware presence and status check process
    Process {
        id: statusProcess
        command: [
            "bash",
            "-c",
            "if [ -d /sys/class/bluetooth ] && [ -n \"$(ls -A /sys/class/bluetooth 2>/dev/null)\" ]; then if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then echo 'ON'; else echo 'OFF'; fi; else echo 'NONE'; fi"
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var state = data.trim();
                if (state === "ON") {
                    root.available = true;
                    root.isPowered = true;
                } else if (state === "OFF") {
                    root.available = true;
                    root.isPowered = false;
                } else {
                    root.available = false;
                    root.isPowered = false;
                }
            }
        }
    }

    // Periodic status polling (every 3s)
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statusProcess.running) statusProcess.running = true;
        }
    }

    // Quick refresh after user interaction
    Timer {
        id: quickRefreshTimer
        interval: 400
        onTriggered: {
            if (!statusProcess.running) statusProcess.running = true;
        }
    }

    // Toggle Bluetooth power state
    function toggleBluetooth() {
        var newTarget = !root.isPowered;
        bwClick.exec(newTarget ? ["bluetoothctl", "power", "on"] : ["bluetoothctl", "power", "off"]);
        root.isPowered = newTarget;
        quickRefreshTimer.restart();
    }
}
