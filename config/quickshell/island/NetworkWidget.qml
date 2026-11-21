import QtQuick
import QtQuick.Layouts
import Quickshell
import '../components/'
import "../services"
import ".."

RowLayout {
    id: root

    signal openRequested()

    spacing: 1
    visible: NetworkService.anyDeviceAvailable

    // 1. Wired (Ethernet) Indicator Button
    IconButtonBar {
        id: wiredBtn

        available: NetworkService.hasWiredDevice
        active: NetworkService.wiredConnected || NetworkService.wiredConnecting
        icon: NetworkService.wiredIcon

        // Show VPN badge on the first visible network button
        prefixIcon: (NetworkService.vpnConnected || NetworkService.vpnConnecting) ? NetworkService.vpnIcon : ""
        prefixColor: NetworkService.vpnConnecting
            ? (Theme.warning || "#F59E0B")
            : (Theme.success || Theme.accent || "#10B981")

        iconColor: (NetworkService.wiredConnected && NetworkService.hasConnectivityWarning)
            ? (Theme.warning || "#F59E0B")
            : (Theme.textPrimary || "#ffffff")

        tooltip: {
            var lines = [];

            if (NetworkService.wiredConnected && NetworkService.hasConnectivityWarning) {
                lines.push("⚠ " + NetworkService.connectivityText);
            }

            if (NetworkService.vpnConnected || NetworkService.vpnConnecting) {
                var vState = NetworkService.vpnConnecting ? "Connecting..." : "Active";
                lines.push(`${NetworkService.vpnIcon} ${NetworkService.activeVpnType}: ${NetworkService.activeVpnName} (${vState})`);
            }

            var iface = NetworkService.wiredInterface ? ` (${NetworkService.wiredInterface})` : "";
            if (NetworkService.wiredConnected) {
                var speedStr = NetworkService.wiredLinkSpeed > 0 ? (" · " + NetworkService.wiredLinkSpeed + " Mbps") : "";
                lines.push(`󰈀 Ethernet${iface}${speedStr}`);
                lines.push(`IP: ${NetworkService.wiredIp}`);
            } else if (NetworkService.wiredConnecting) {
                lines.push(`󰌘 Ethernet${iface}: Connecting...`);
            } else if (NetworkService.wiredHasLink) {
                lines.push(`󰌙 Ethernet${iface}: Disconnected`);
            } else {
                lines.push(`󰌙 Ethernet${iface}: Cable unplugged`);
            }

            return lines.join("\n");
        }

        // Left click: Open Control Center (main view with Ethernet & VPN cards)
        onClicked: {
            NetworkService.wifiPanelOpen = false;
            root.openRequested();
        }

        // Right click: Connect / disconnect Ethernet interface
        onRightClicked: {
            NetworkService.toggleWired();
        }
    }

    // 2. Wi-Fi Indicator Button
    IconButtonBar {
        id: wifiBtn

        available: NetworkService.hasWifiDevice
        active: NetworkService.wifiPowered && (NetworkService.wifiConnected || NetworkService.wifiConnecting)
        icon: NetworkService.wifiIcon

        // Show VPN badge here only if there is no Wired device button
        prefixIcon: (!NetworkService.hasWiredDevice && (NetworkService.vpnConnected || NetworkService.vpnConnecting))
            ? NetworkService.vpnIcon
            : ""
        prefixColor: NetworkService.vpnConnecting
            ? (Theme.warning || "#F59E0B")
            : (Theme.success || Theme.accent || "#10B981")

        iconColor: (NetworkService.wifiConnected && NetworkService.hasConnectivityWarning)
            ? (Theme.warning || "#F59E0B")
            : (Theme.textPrimary || "#ffffff")

        tooltip: {
            var lines = [];

            if (NetworkService.wifiConnected && NetworkService.hasConnectivityWarning) {
                lines.push("⚠ " + NetworkService.connectivityText);
            }

            if (NetworkService.vpnConnected || NetworkService.vpnConnecting) {
                var vState = NetworkService.vpnConnecting ? "Connecting..." : "Active";
                lines.push(`${NetworkService.vpnIcon} ${NetworkService.activeVpnType}: ${NetworkService.activeVpnName} (${vState})`);
            }

            var iface = NetworkService.wifiInterface ? ` (${NetworkService.wifiInterface})` : "";
            if (!NetworkService.wifiPowered) {
                lines.push(`󰤮 Wi-Fi${iface}: Off`);
            } else if (NetworkService.wifiConnecting) {
                lines.push(`󱛇 Wi-Fi${iface}: Connecting...`);
            } else if (NetworkService.wifiConnected) {
                var sec = NetworkService.wifiSecurity ? ` · ${NetworkService.wifiSecurity}` : "";
                lines.push(`󰤨 ${NetworkService.wifiSsid} · ${NetworkService.wifiSignalPct}%`);
                lines.push(`Network${iface}${sec} · IP: ${NetworkService.wifiIp}`);
            } else {
                lines.push(`󰤫 Wi-Fi${iface}: Disconnected`);
            }

            return lines.join("\n");
        }

        // Left click: Open native Wi-Fi network selector in Control Center
        onClicked: {
            NetworkService.wifiPanelOpen = true;
            root.openRequested();
        }

        // Right click: Turn Wi-Fi radio on / off
        onRightClicked: {
            NetworkService.toggleWifi();
        }
    }
}
