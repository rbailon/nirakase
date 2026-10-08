import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import '../components/'
import ".."

IconButtonBar {
    id: root

    // Internal state
    property bool hasWifiDevice: false
    property bool isPowered: true
    property bool isConnected: false
    property int signalLevel: 0 // 1 to 4
    property string ssid: ""
    property int signalPct: 0
    property string ipAddress: ""

    // Properties inherited from IconButtonBar
    available: root.hasWifiDevice
    active: root.isPowered && root.isConnected

    // Reactive icon selection based on state
    icon: {
        if (!root.isPowered) return "󰤮";    // Turned off
        if (!root.isConnected) return "󰤫";  // Disconnected
        
        switch (root.signalLevel) {
            case 1: return "󰤟";             // Signal 25%
            case 2: return "󰤢";             // Signal 50%
            case 3: return "󰤥";             // Signal 75%
            case 4:
            default: 
              return "󰤨";            // Signal 100%
        }
    }
    
    tooltip: isConnected 
    ? `Conectado a ${ssid}\nSeñal: ${signalPct}%\nIP: ${ipAddress}`
    : "Desconectado"

    Process { id: wwClick; }

    // Mouse actions
    onClicked: {
        // Left click: Open Wi-Fi manager in terminal (e.g. impala/iwctl)
        wwClick.exec(["xdg-terminal-exec", "--app-id=org.nirakase.wifi", "-e", "impala"]);
    }

    onRightClicked: {
        // Right click: Toggle Wi-Fi antenna
        root.toggleWifi();
    }

    function toggleWifi() {
        var cmd = root.isPowered ? ["rfkill", "block", "wifi"] : ["rfkill", "unblock", "wifi"];
        wwClick.exec(cmd);
        root.isPowered = !root.isPowered;
        quickRefreshTimer.restart();
    }

    Process {
        id: wifiProcess
        command: [
            "bash",
            "-c",
            "iface=$(ls -d /sys/class/net/*/wireless 2>/dev/null | head -n1 | cut -d/ -f5); " +
            "if [ -z \"$iface\" ]; then echo 'NO_DEVICE'; exit 0; fi; " +
            "if rfkill list wifi 2>/dev/null | grep -q 'Soft blocked: yes'; then echo 'DISABLED'; exit 0; fi; " +
            "net_state=$(networkctl status \"$iface\" 2>/dev/null | grep 'State:' | awk '{print $2}'); " +
            "raw_ssid=$(networkctl status \"$iface\" 2>/dev/null | grep -E 'Wi-Fi access point:|SSID:' | head -n1); " +
            "if [ -z \"$raw_ssid\" ] || [ \"$net_state\" = 'off' ] || [ \"$net_state\" = 'no-carrier' ]; then echo 'DISCONNECTED'; exit 0; fi; " +
            "ssid=$(echo \"$raw_ssid\" | sed -E 's/.*(Wi-Fi access point:|SSID:)[[:space:]]*//; s/[[:space:]]*\\(.*//'); " +
            "ip=$(ip -4 addr show dev \"$iface\" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1); " +
            "if [ -z \"$ip\" ]; then ip='Sin IP'; fi; " +
            "qual=$(awk -v iface=\"${iface}:\" '$1 == iface { sub(/\\./, \"\", $3); print $3 }' /proc/net/wireless 2>/dev/null); " +
            "if [ -z \"$qual\" ]; then qual=50; fi; " +
            "if [ \"$qual\" -gt 70 ]; then pct=$qual; else pct=$(( qual * 100 / 70 )); fi; " +
            "if [ \"$pct\" -gt 100 ]; then pct=100; fi; " +
            "if [ \"$pct\" -ge 75 ]; then lvl=4; elif [ \"$pct\" -ge 50 ]; then lvl=3; elif [ \"$pct\" -ge 25 ]; then lvl=2; else lvl=1; fi; " +
            "echo \"CONNECTED:$lvl:$pct:$ssid:$ip\""
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var str = data.trim();
                if (str === "NO_DEVICE") {
                    root.hasWifiDevice = false;
                } else if (str === "DISABLED") {
                    root.hasWifiDevice = true;
                    root.isPowered = false;
                    root.isConnected = false;
                } else if (str === "DISCONNECTED") {
                    root.hasWifiDevice = true;
                    root.isPowered = true;
                    root.isConnected = false;
                    root.ssid = "";
                    root.ipAddress = "";
                } else if (str.startsWith("CONNECTED:")) {
                    root.hasWifiDevice = true;
                    root.isPowered = true;
                    root.isConnected = true;

                    // Format: CONNECTED:lvl:pct:ssid:ip
                    var parts = str.split(":");
                    root.signalLevel = parseInt(parts[1]) || 4;
                    root.signalPct = parseInt(parts[2]) || 0;
                    root.ssid = parts[3] || "Desconocida";
                    root.ipAddress = parts[4] || "Sin IP";
                }
            }
        }
    }
    // Periodic query every 4 seconds
    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!wifiProcess.running) wifiProcess.running = true;
        }
    }

    // Quick refresh after right-click interaction
    Timer {
        id: quickRefreshTimer
        interval: 400
        onTriggered: {
            if (!wifiProcess.running) wifiProcess.running = true;
        }
    }
}
