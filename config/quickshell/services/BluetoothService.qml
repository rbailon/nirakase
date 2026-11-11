pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Item {
    id: root

    // Controls whether the native Bluetooth selector panel is open in Control Center
    property bool btPanelOpen: false

    // =============================================================
    // 1. Primary Bluetooth Adapter
    // =============================================================
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    readonly property bool isBlocked: adapter ? (adapter.state === BluetoothAdapterState.Blocked) : false
    readonly property bool isPowered: adapter ? adapter.enabled : false
    readonly property bool isTransitioning: adapter ? (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling) : false
    readonly property bool isDiscovering: adapter ? adapter.discovering : false
    readonly property bool isDiscoverable: adapter ? adapter.discoverable : false
    readonly property string adapterName: adapter ? (adapter.name || adapter.adapterId || "Bluetooth") : ""
    readonly property string adapterId: adapter ? (adapter.adapterId || "") : ""

    // =============================================================
    // 2. Bluetooth Devices (Connected, Paired & Discovered)
    // =============================================================

    // All valid devices (filtering out anonymous/empty MAC-only entries unless paired/connected)
    readonly property var allDevices: {
        var raw = Bluetooth.devices.values;
        if (!raw) return [];
        var list = [];
        for (var i = 0; i < raw.length; i++) {
            var d = raw[i];
            if (!d) continue;
            var dispName = d.name || d.deviceName || "";
            // Always show connected or paired devices; require readable name for discovered ones
            if (d.connected || d.paired || (dispName.trim() !== "" && dispName !== d.address)) {
                list.push(d);
            }
        }
        list.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            var aChanging = (a.state === BluetoothDeviceState.Connecting || a.state === BluetoothDeviceState.Disconnecting || a.pairing);
            var bChanging = (b.state === BluetoothDeviceState.Connecting || b.state === BluetoothDeviceState.Disconnecting || b.pairing);
            if (aChanging !== bChanging) return aChanging ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            var nameA = (a.name || a.deviceName || a.address || "").toLowerCase();
            var nameB = (b.name || b.deviceName || b.address || "").toLowerCase();
            return nameA.localeCompare(nameB);
        });
        return list;
    }

    // Currently connected devices
    readonly property var connectedDevices: {
        var list = [];
        var devs = allDevices;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].connected) {
                list.push(devs[i]);
            }
        }
        return list;
    }

    readonly property int connectedCount: connectedDevices.length
    readonly property int totalDevicesCount: allDevices.length
    readonly property var primaryDevice: connectedCount > 0 ? connectedDevices[0] : null

    // Is any device currently connecting or pairing?
    readonly property bool isConnecting: {
        var devs = allDevices;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i] && (devs[i].state === BluetoothDeviceState.Connecting || devs[i].pairing)) {
                return true;
            }
        }
        return false;
    }

    readonly property bool isConnected: isPowered && connectedCount > 0
    readonly property string primaryDeviceName: primaryDevice ? (primaryDevice.name || primaryDevice.deviceName || "Connected") : ""
    readonly property bool primaryHasBattery: primaryDevice ? primaryDevice.batteryAvailable : false
    readonly property int primaryBatteryPct: (primaryDevice && primaryDevice.batteryAvailable) ? Math.round((primaryDevice.battery || 0) * 100) : -1

    // =============================================================
    // 3. Reactive Icons
    // =============================================================
    readonly property string btIcon: {
        if (!isPowered) return "󰂲";        // Powered off
        if (isConnecting) return "󰂰";      // Connecting / Pairing
        if (isConnected) return "󰂱";       // Connected to device(s)
        return "󰂯";                        // Powered on without active connections
    }

    function deviceIcon(dev) {
        if (!dev) return "󰂯";
        var ic = (dev.icon || "").toLowerCase();
        if (ic.indexOf("headset") !== -1) return "󰋎";
        if (ic.indexOf("headphone") !== -1 || ic.indexOf("audio") !== -1) return "󰋋";
        if (ic.indexOf("mouse") !== -1) return "󰍽";
        if (ic.indexOf("keyboard") !== -1) return "󰌌";
        if (ic.indexOf("gaming") !== -1 || ic.indexOf("joypad") !== -1) return "󰊗";
        if (ic.indexOf("phone") !== -1) return "󰄜";
        if (ic.indexOf("computer") !== -1 || ic.indexOf("laptop") !== -1) return "💻";
        if (ic.indexOf("camera") !== -1) return "󰄀";
        return dev.connected ? "󰂱" : "󰂯";
    }

    function deviceTypeLabel(dev) {
        if (!dev) return "Device";
        var ic = (dev.icon || "").toLowerCase();
        if (ic.indexOf("headset") !== -1) return "Headset";
        if (ic.indexOf("headphone") !== -1) return "Headphones";
        if (ic.indexOf("audio") !== -1 || ic.indexOf("speaker") !== -1) return "Audio";
        if (ic.indexOf("mouse") !== -1) return "Mouse";
        if (ic.indexOf("keyboard") !== -1) return "Keyboard";
        if (ic.indexOf("gaming") !== -1 || ic.indexOf("joypad") !== -1) return "Controller";
        if (ic.indexOf("phone") !== -1) return "Phone";
        return "Bluetooth";
    }

    function batteryIcon(pct) {
        if (pct < 0) return "";
        if (pct <= 15) return "󰁺";
        if (pct <= 30) return "󰁼";
        if (pct <= 50) return "󰁾";
        if (pct <= 70) return "󰂀";
        if (pct <= 90) return "󰂂";
        return "󰁹";
    }

    // =============================================================
    // 4. Control Actions
    // =============================================================
    Process {
        id: launcherProc
    }

    function toggleBluetooth() {
        if (!adapter) return;
        adapter.enabled = !adapter.enabled;
    }

    function setDiscovering(enabled) {
        if (!adapter) return;
        if (adapter.enabled && adapter.discovering !== enabled) {
            adapter.discovering = enabled;
        } else if (!enabled && adapter.discovering) {
            adapter.discovering = false;
        }
    }

    function toggleDiscoverable() {
        if (!adapter || !adapter.enabled) return;
        adapter.discoverable = !adapter.discoverable;
    }

    function connectDevice(dev) {
        if (!dev) return;
        if (!dev.paired) {
            dev.pair();
        }
        dev.trusted = true;
        dev.connect();
    }

    function disconnectDevice(dev) {
        if (!dev) return;
        dev.disconnect();
    }

    function forgetDevice(dev) {
        if (!dev) return;
        dev.forget();
    }

    function openExternalManager() {
        launcherProc.exec(["xdg-terminal-exec", "--app-id=org.nirakase.bluetooth", "-e", "bluetui"]);
    }
}
