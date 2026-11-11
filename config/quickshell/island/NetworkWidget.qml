import QtQuick
import QtQuick.Layouts
import Quickshell
import '../components/'
import "../services"
import ".."

IconButtonBar {
    id: root

    signal openRequested()

    // Available if a Wi-Fi or Ethernet card is present
    available: NetworkService.anyDeviceAvailable
    active: NetworkService.anyActive

    // Reactive icon (Wi-Fi or Ethernet depending on active connection)
    icon: NetworkService.primaryIcon

    // Secondary icon for active VPN (similar to power profile next to battery)
    prefixIcon: (NetworkService.vpnConnected || NetworkService.vpnConnecting) ? NetworkService.vpnIcon : ""
    prefixColor: NetworkService.vpnConnecting
        ? (Theme.warning || "#F59E0B")
        : (Theme.success || Theme.accent || "#10B981")

    // Warning color if connected to local network without Internet access / Captive Portal
    iconColor: NetworkService.hasConnectivityWarning
        ? (Theme.warning || "#F59E0B")
        : (Theme.textPrimary || "#ffffff")

    tooltip: {
        var lines = [];

        if (NetworkService.hasConnectivityWarning) {
            lines.push("⚠ " + NetworkService.connectivityText);
        }

        if (NetworkService.vpnConnected || NetworkService.vpnConnecting) {
            var vState = NetworkService.vpnConnecting ? "Connecting..." : "Active";
            lines.push(`${NetworkService.vpnIcon} ${NetworkService.activeVpnType}: ${NetworkService.activeVpnName} (${vState})`);
        }

        if (NetworkService.hasWiredDevice && (NetworkService.wiredConnected || NetworkService.wiredHasLink)) {
            if (NetworkService.wiredConnected) {
                var speedStr = NetworkService.wiredLinkSpeed > 0 ? (" · " + NetworkService.wiredLinkSpeed + " Mbps") : "";
                lines.push(`󰈀 Ethernet (${NetworkService.wiredInterface})${speedStr}`);
                lines.push(`IP: ${NetworkService.wiredIp}`);
            } else {
                lines.push(`󰌙 Ethernet (${NetworkService.wiredInterface}): Disconnected`);
            }
        }

        if (NetworkService.hasWifiDevice) {
            if (!NetworkService.wifiPowered) {
                lines.push("󰤮 Wi-Fi: Off");
            } else if (NetworkService.wifiConnecting) {
                lines.push("󱛇 Wi-Fi: Connecting...");
            } else if (NetworkService.wifiConnected) {
                var sec = NetworkService.wifiSecurity ? ` · ${NetworkService.wifiSecurity}` : "";
                var iface = NetworkService.wifiInterface ? ` (${NetworkService.wifiInterface})` : "";
                lines.push(`󰤨 ${NetworkService.wifiSsid} · ${NetworkService.wifiSignalPct}%`);
                lines.push(`Network${iface}${sec} · IP: ${NetworkService.wifiIp}`);
            } else {
                lines.push("󰤫 Wi-Fi: Disconnected");
            }
        }

        return lines.length > 0 ? lines.join("\n") : "No network";
    }

    // Left click: Opens the native Wi-Fi network selector in Control Center
    onClicked: {
        NetworkService.wifiPanelOpen = true;
        root.openRequested();
    }

    // Right click: Turns Wi-Fi radio on / off
    onRightClicked: {
        NetworkService.toggleWifi();
    }
}
