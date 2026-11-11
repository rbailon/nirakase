import QtQuick
import QtQuick.Layouts
import Quickshell
import '../components/'
import "../services"
import ".."

IconButtonBar {
    id: root

    signal openRequested()

    // Reactive IconButtonBar configuration via BluetoothService (Quickshell.Bluetooth)
    available: BluetoothService.hasAdapter
    active: BluetoothService.isPowered
    icon: BluetoothService.btIcon

    tooltip: {
        if (!BluetoothService.hasAdapter) return "No Bluetooth adapter";
        if (BluetoothService.isBlocked) return "󰂲 Bluetooth blocked";
        if (!BluetoothService.isPowered) return "󰂲 Bluetooth off";
        if (BluetoothService.isConnecting) return "󰂰 Bluetooth: Connecting...";
        if (!BluetoothService.isConnected) return "󰂯 Bluetooth on (Disconnected)";

        var lines = [];
        var devs = BluetoothService.connectedDevices;
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (!d) continue;
            var dName = d.name || d.deviceName || d.address;
            var dIcon = BluetoothService.deviceIcon(d);
            var batStr = "";
            if (d.batteryAvailable) {
                var pct = Math.round((d.battery || 0) * 100);
                batStr = ` · ${pct}% ${BluetoothService.batteryIcon(pct)}`;
            }
            lines.push(`${dIcon} ${dName}${batStr}`);
        }
        return lines.join("\n");
    }

    // Left click: Open native Bluetooth selector panel in Control Center
    onClicked: {
        NetworkService.wifiPanelOpen = false;
        BluetoothService.btPanelOpen = true;
        root.openRequested();
    }

    // Right click: Toggle Bluetooth power natively via BlueZ D-Bus
    onRightClicked: {
        BluetoothService.toggleBluetooth();
    }
}
