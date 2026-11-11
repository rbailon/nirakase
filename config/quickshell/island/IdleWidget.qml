import QtQuick
import QtQuick.Layouts
import Quickshell
import '../components/'
import "../services"
import ".."

StatusIndicatorButton {
    id: root

    signal openRequested()

    // Bindings with StatusIndicatorButton via native Wayland IdleService
    available: true
    active: IdleService.isIdleActive
    icon: IdleService.icon

    // Status dot configuration
    dotOnly: true
    showBadge: IdleService.inhibited // Shows the amber dot only when idle is inhibited (Caffeine mode)
    badgeColor: "#E5A50A"            // Warning amber/orange color

    tooltip: {
        if (IdleService.inhibited) {
            return "󰒳 Caffeine Mode: Idle inhibited\nLeft click: Enable idle · Right click: Configure timeouts";
        }
        var lines = ["󰒲 Automatic idle active"];
        lines.push(
            "Dim: " + IdleService.formatDuration(IdleService.dimTimeout) +
            " · Lock: " + IdleService.formatDuration(IdleService.lockTimeout)
        );
        lines.push(
            "Monitor: " + IdleService.formatDuration(IdleService.dpmsTimeout) +
            " · Suspend: " + IdleService.formatDuration(IdleService.suspendTimeout)
        );
        return lines.join("\n");
    }

    // Left click: Toggle Caffeine / Idle Inhibitor immediately
    onClicked: IdleService.toggleInhibit()

    // Right click: Open Idle timeout configuration panel in Control Center
    onRightClicked: {
        NetworkService.wifiPanelOpen = false;
        BluetoothService.btPanelOpen = false;
        AudioService.audioPanelOpen = false;
        IdleService.idlePanelOpen = true;
        root.openRequested();
    }
}
