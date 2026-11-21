pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Item {
    id: root

    // Controls whether the Wi-Fi selector panel in Control Center is open
    property bool wifiPanelOpen: false

    // Last Wi-Fi connection error message (for UI feedback)
    property string lastWifiError: ""
    property string lastFailedSsid: ""

    // NetworkManager VPN / WireGuard profiles
    property var vpnProfiles: []
    property var _pendingVpns: []
    property bool _vpnRefreshQueued: false
    property string lastVpnError: ""
    property string _vpnStderrBuffer: ""

    // Physical carrier, link speed & IPv4 per interface (from /sys/class/net & ip -4)
    property var wiredCarriers: ({})
    property var _pendingCarriers: ({})
    property bool _carrierRefreshQueued: false
    property int _ipRetryCount: 0
    property string preferredWiredName: ""

    Component.onCompleted: {
        if (Networking.canCheckConnectivity) {
            Networking.connectivityCheckEnabled = true;
        }
        root.refreshWiredCarriers();
        root.refreshVpns();
    }

    // =============================================================
    // 1. Detected Devices (Wi-Fi & Wired / Ethernet)
    // =============================================================

    // Primary Wi-Fi device (prioritizes connected device if multiple exist)
    readonly property var wifiDevice: {
        var devs = Networking.devices.values;
        if (!devs) return null;
        var firstWifi = null;
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (d && d.type === DeviceType.Wifi) {
                if (d.connected) return d;
                if (!firstWifi) firstWifi = d;
            }
        }
        return firstWifi;
    }

    // Primary Ethernet / Wired device (prioritizes connected -> connecting -> physical link -> last active)
    readonly property var wiredDevice: {
        var devs = Networking.devices.values;
        if (!devs) return null;
        var firstConnecting = null;
        var firstWithLink = null;
        var preferredDev = null;
        var firstWired = null;
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (d && d.type === DeviceType.Wired) {
                if (d.connected) return d;
                if (d.state === ConnectionState.Connecting && !firstConnecting) firstConnecting = d;
                var cInfo = root.wiredCarriers[d.name];
                var hasPhysLink = (cInfo && cInfo.carrier) || d.hasLink || (d.linkSpeed || 0) > 0;
                if (hasPhysLink && !firstWithLink) firstWithLink = d;
                if (root.preferredWiredName !== "" && d.name === root.preferredWiredName) preferredDev = d;
                if (!firstWired) firstWired = d;
            }
        }
        if (firstConnecting) return firstConnecting;
        if (firstWithLink) return firstWithLink;
        if (preferredDev) return preferredDev;
        return firstWired;
    }

    onWiredConnectedChanged: {
        if (wiredConnected && wiredDevice && wiredDevice.name) {
            root.preferredWiredName = wiredDevice.name;
        }
        root._ipRetryCount = 0;
        root.refreshWiredCarriers();
    }

    onWifiConnectedChanged: {
        root._ipRetryCount = 0;
        root.refreshWiredCarriers();
    }

    // Currently active Wi-Fi network
    readonly property var activeWifiNetwork: {
        if (!wifiDevice || !wifiDevice.networks) return null;
        var nets = wifiDevice.networks.values;
        if (!nets) return null;
        for (var i = 0; i < nets.length; i++) {
            if (nets[i] && nets[i].connected) {
                return nets[i];
            }
        }
        return null;
    }

    // Sorted list of available Wi-Fi networks (connected -> saved -> strongest signal)
    readonly property var wifiNetworks: {
        if (!wifiDevice || !wifiDevice.networks) return [];
        var raw = wifiDevice.networks.values;
        if (!raw) return [];
        var list = [];
        for (var i = 0; i < raw.length; i++) {
            var n = raw[i];
            if (n && n.name && n.name.trim() !== "") {
                list.push(n);
            }
        }
        list.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.stateChanging !== b.stateChanging) return a.stateChanging ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        return list;
    }

    readonly property int wifiNetworksCount: wifiNetworks.length

    // =============================================================
    // 2. Global Connectivity / Internet State
    // =============================================================
    readonly property int connectivity: Networking.connectivity
    readonly property bool hasInternet: connectivity === NetworkConnectivity.Full || connectivity === NetworkConnectivity.Unknown
    readonly property bool isLimited: connectivity === NetworkConnectivity.Limited
    readonly property bool isCaptivePortal: connectivity === NetworkConnectivity.Portal
    readonly property bool hasConnectivityWarning: (wifiConnected || wiredConnected) && (isLimited || isCaptivePortal)

    readonly property string connectivityText: {
        switch (connectivity) {
            case NetworkConnectivity.Full:    return "Connected to Internet";
            case NetworkConnectivity.Limited: return "No Internet access";
            case NetworkConnectivity.Portal:  return "Sign-in required (Captive portal)";
            case NetworkConnectivity.None:    return "Disconnected";
            default:                          return "Connected";
        }
    }

    // =============================================================
    // 3. Reactive Wi-Fi Properties
    // =============================================================
    readonly property bool hasWifiDevice: wifiDevice !== null
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool wifiPowered: Networking.wifiEnabled && Networking.wifiHardwareEnabled
    readonly property bool wifiConnected: wifiDevice ? wifiDevice.connected : false
    readonly property bool wifiConnecting: wifiDevice ? (wifiDevice.state === ConnectionState.Connecting) : false
    readonly property bool wifiDisconnecting: wifiDevice ? (wifiDevice.state === ConnectionState.Disconnecting) : false
    readonly property bool wifiScanning: wifiDevice ? wifiDevice.scannerEnabled : false
    readonly property string wifiInterface: wifiDevice ? (wifiDevice.name || "") : ""
    readonly property string wifiSsid: activeWifiNetwork ? (activeWifiNetwork.name || "Unknown") : ""
    readonly property int wifiSignalPct: activeWifiNetwork ? Math.round((activeWifiNetwork.signalStrength || 0) * 100) : 0
    readonly property int wifiSignalLevel: signalToLevel(wifiSignalPct)
    readonly property string wifiIp: {
        if (!wifiDevice) return "No IP";
        var cInfo = root.wiredCarriers[wifiDevice.name];
        if (cInfo && cInfo.ipv4 && cInfo.ipv4 !== "") return cInfo.ipv4;
        return "No IP";
    }
    readonly property string wifiSecurity: activeWifiNetwork ? securityLabel(activeWifiNetwork.security) : ""

    readonly property string wifiIcon: {
        if (!wifiPowered) return "󰤮";          // Powered off
        if (wifiConnecting) return "󱛇";        // Connecting
        if (!wifiConnected) return "󰤫";        // Disconnected
        if (isLimited || isCaptivePortal) {
            switch (wifiSignalLevel) {
                case 1: return "󰤠";
                case 2: return "󰤣";
                case 3: return "󰤦";
                case 4:
                default: return "󰤩";           // Connected without Internet / Portal
            }
        }
        return levelToWifiIcon(wifiSignalLevel);
    }

    // =============================================================
    // 4. Reactive Ethernet Properties (Wired NIC)
    // =============================================================
    readonly property bool hasWiredDevice: wiredDevice !== null
    readonly property bool wiredHasLink: {
        if (!wiredDevice) return false;
        var cInfo = root.wiredCarriers[wiredDevice.name];
        if (cInfo && cInfo.carrier !== undefined) {
            return cInfo.carrier || wiredDevice.connected;
        }
        return wiredDevice.hasLink || wiredDevice.connected || (wiredDevice.linkSpeed || 0) > 0;
    }
    readonly property bool wiredConnected: wiredDevice ? wiredDevice.connected : false
    readonly property bool wiredConnecting: wiredDevice ? (wiredDevice.state === ConnectionState.Connecting) : false
    readonly property string wiredInterface: wiredDevice ? (wiredDevice.name || "") : ""
    readonly property string wiredConnectionName: (wiredDevice && wiredDevice.network && wiredDevice.network.name) ? wiredDevice.network.name : (wiredInterface || "Ethernet")
    readonly property int wiredLinkSpeed: {
        if (!wiredDevice) return 0;
        if ((wiredDevice.linkSpeed || 0) > 0) return wiredDevice.linkSpeed;
        var cInfo = root.wiredCarriers[wiredDevice.name];
        return (cInfo && cInfo.speed > 0) ? cInfo.speed : 0;
    }
    readonly property string wiredIp: {
        if (!wiredDevice) return "No IP";
        var cInfo = root.wiredCarriers[wiredDevice.name];
        if (cInfo && cInfo.ipv4 && cInfo.ipv4 !== "") return cInfo.ipv4;
        return "No IP";
    }

    readonly property string wiredIcon: {
        if (!hasWiredDevice) return "󰌙";
        if (wiredConnecting) return "󰌘";
        if (wiredConnected) {
            if (isLimited || isCaptivePortal) return "󰌚";  // No Internet
            return "󰈀";                                   // Ethernet connected
        }
        return "󰌙";                                       // Disconnected / Unplugged
    }

    // =============================================================
    // 5. Reactive VPN / WireGuard Properties (NetworkManager)
    // =============================================================
    readonly property bool hasVpnProfiles: vpnProfiles.length > 0
    readonly property int vpnCount: vpnProfiles.length

    readonly property var activeVpn: {
        for (var i = 0; i < vpnProfiles.length; i++) {
            var v = vpnProfiles[i];
            if (v && (v.connected || v.connecting)) {
                return v;
            }
        }
        return null;
    }

    readonly property var primaryVpn: activeVpn ? activeVpn : (vpnProfiles.length > 0 ? vpnProfiles[0] : null)
    readonly property bool vpnConnected: activeVpn !== null && activeVpn.connected
    readonly property bool vpnConnecting: activeVpn !== null && activeVpn.connecting
    readonly property string activeVpnName: activeVpn ? (activeVpn.name || "VPN") : ""
    readonly property string activeVpnType: activeVpn ? (activeVpn.typeLabel || "VPN") : ""
    readonly property string vpnIcon: vpnConnecting ? "󰦞" : "󰦝"

    // =============================================================
    // 6. Combined State for Top Bar Icon (NetworkWidget)
    // =============================================================
    readonly property bool anyDeviceAvailable: hasWifiDevice || hasWiredDevice
    readonly property bool anyActive: (wifiPowered && wifiConnected) || wiredConnected

    // Prioritize Ethernet icon if connected while Wi-Fi is not
    readonly property string primaryIcon: {
        if (wiredConnected && (!wifiConnected || !wifiPowered)) {
            return wiredIcon;
        }
        if (hasWifiDevice) {
            return wifiIcon;
        }
        return wiredIcon;
    }

    // =============================================================
    // 6. Helper Functions & Network Actions
    // =============================================================
    function signalToLevel(pct) {
        if (pct >= 75) return 4;
        if (pct >= 50) return 3;
        if (pct >= 25) return 2;
        return 1;
    }

    function levelToWifiIcon(lvl) {
        switch (lvl) {
            case 1: return "󰤟";
            case 2: return "󰤢";
            case 3: return "󰤥";
            case 4:
            default: return "󰤨";
        }
    }

    function networkIcon(net) {
        if (!net) return "󰤫";
        var pct = Math.round((net.signalStrength || 0) * 100);
        return levelToWifiIcon(signalToLevel(pct));
    }

    function isNetworkSecure(net) {
        if (!net) return false;
        return net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Owe;
    }

    function securityLabel(sec) {
        switch (sec) {
            case WifiSecurityType.Open:          return "Open";
            case WifiSecurityType.Owe:           return "OWE";
            case WifiSecurityType.Sae:
            case WifiSecurityType.Wpa3SuiteB192: return "WPA3";
            case WifiSecurityType.Wpa2Psk:       return "WPA2";
            case WifiSecurityType.Wpa2Eap:
            case WifiSecurityType.WpaEap:        return "WPA-EAP";
            case WifiSecurityType.WpaPsk:        return "WPA";
            case WifiSecurityType.StaticWep:
            case WifiSecurityType.DynamicWep:
            case WifiSecurityType.Leap:          return "WEP";
            default:                             return "Secured";
        }
    }

    function failReasonText(reason) {
        switch (reason) {
            case ConnectionFailReason.NoSecrets:              return "Password required";
            case ConnectionFailReason.WifiAuthTimeout:        return "Incorrect password or timeout";
            case ConnectionFailReason.WifiClientFailed:       return "Failed to connect to access point";
            case ConnectionFailReason.WifiClientDisconnected: return "Disconnected by access point";
            case ConnectionFailReason.WifiNetworkLost:        return "Network signal lost";
            default:                                          return "Could not connect to network";
        }
    }

    function toggleWifi() {
        root.lastWifiError = "";
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function setWifiScanner(enabled) {
        if (wifiDevice) {
            wifiDevice.scannerEnabled = enabled;
        }
    }

    function connectToWifi(net, password) {
        if (!net) return;
        root.lastWifiError = "";
        root.lastFailedSsid = "";
        if (password !== undefined && password !== "") {
            net.connectWithPsk(password);
        } else {
            net.connect();
        }
    }

    function disconnectWifi() {
        if (activeWifiNetwork) {
            activeWifiNetwork.disconnect();
        } else if (wifiDevice) {
            wifiDevice.disconnect();
        }
    }

    function forgetWifi(net) {
        if (!net) return;
        net.forget();
    }

    function toggleWired() {
        if (!wiredDevice || wiredActionProc.running) return;
        var iface = wiredDevice.name || root.preferredWiredName;
        if (!iface) return;
        root.preferredWiredName = iface;
        var action = (wiredDevice.connected || wiredDevice.state === ConnectionState.Connecting)
            ? "disconnect"
            : "connect";
        wiredActionProc.command = ["nmcli", "device", action, iface];
        wiredActionProc.running = true;
    }

    function refreshWiredCarriers() {
        if (wiredCarrierProc.running) {
            root._carrierRefreshQueued = true;
            return;
        }
        root._carrierRefreshQueued = false;
        root._pendingCarriers = ({});
        wiredCarrierProc.running = true;
    }

    Timer {
        id: ipRetryTimer
        interval: 1000
        repeat: false
        onTriggered: root.refreshWiredCarriers()
    }

    Process {
        id: wiredActionProc
        environment: ({ "LC_ALL": "C.UTF-8", "LANG": "C.UTF-8" })
        onExited: {
            root._ipRetryCount = 0;
            root.refreshWiredCarriers();
            root.refreshVpns();
        }
    }

    Process {
        id: wiredCarrierProc
        command: [
            "sh",
            "-c",
            "for d in /sys/class/net/*; do [ -e \"$d/device\" ] || continue; n=${d##*/}; c=$(cat \"$d/carrier\" 2>/dev/null || echo 0); s=$(cat \"$d/speed\" 2>/dev/null || echo 0); ip4=$(ip -4 -o addr show dev \"$n\" 2>/dev/null | awk '{sub(/\\/.*/, \"\", $4); print $4; exit}'); echo \"$n:$c:$s:$ip4\"; done"
        ]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                var parts = line.split(":");
                if (parts.length < 3) return;
                var ifname = parts[0];
                var carrier = parseInt(parts[1]) === 1;
                var speed = parseInt(parts[2]);
                var ipv4 = parts.length >= 4 ? (parts[3] || "").trim() : "";
                root._pendingCarriers[ifname] = {
                    carrier: carrier,
                    speed: (!isNaN(speed) && speed > 0) ? speed : 0,
                    ipv4: ipv4
                };
            }
        }
        onExited: {
            root.wiredCarriers = Object.assign({}, root._pendingCarriers);
            if (root._carrierRefreshQueued) {
                root._carrierRefreshQueued = false;
                root.refreshWiredCarriers();
            } else if (((root.wifiConnected && root.wifiIp === "No IP") || (root.wiredConnected && root.wiredIp === "No IP")) && root._ipRetryCount < 6) {
                root._ipRetryCount++;
                ipRetryTimer.restart();
            }
        }
    }

    // =============================================================
    // 7. Reactive Monitor & Control for VPN / WireGuard Profiles
    // =============================================================
    function refreshVpns() {
        root.refreshWiredCarriers();
        if (vpnQueryProc.running) {
            root._vpnRefreshQueued = true;
            return;
        }
        root._vpnRefreshQueued = false;
        root._pendingVpns = [];
        vpnQueryProc.running = true;
    }

    function toggleVpn(uuid) {
        if (!uuid || vpnActionProc.running) return;
        root.lastVpnError = "";
        root._vpnStderrBuffer = "";

        var isUp = false;
        var updated = [];
        for (var i = 0; i < root.vpnProfiles.length; i++) {
            var v = Object.assign({}, root.vpnProfiles[i]);
            if (v.uuid === uuid) {
                isUp = v.connected || v.connecting;
                // Optimistic immediate update for instant UI feedback
                v.connecting = !isUp;
                v.connected = false;
                v.state = isUp ? "deactivating" : "activating";
            }
            updated.push(v);
        }
        root.vpnProfiles = updated;

        var action = isUp ? "down" : "up";
        vpnActionProc.command = ["nmcli", "connection", action, "uuid", uuid];
        vpnActionProc.running = true;
    }

    function togglePrimaryVpn() {
        if (root.primaryVpn && root.primaryVpn.uuid) {
            root.toggleVpn(root.primaryVpn.uuid);
        }
    }

    Process {
        id: vpnActionProc
        environment: ({ "LC_ALL": "C.UTF-8", "LANG": "C.UTF-8" })
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.trim() !== "") {
                    root._vpnStderrBuffer = data.trim();
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && root._vpnStderrBuffer !== "") {
                root.lastVpnError = root._vpnStderrBuffer.replace(/^Error:\s*/i, "");
            }
            root.refreshVpns();
        }
    }

    Timer {
        id: vpnDebounceTimer
        interval: 150
        repeat: false
        onTriggered: root.refreshVpns()
    }

    Timer {
        id: nmMonitorRestartTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!nmMonitorProc.running) {
                nmMonitorProc.running = true;
            }
        }
    }

    Timer {
        id: nmAgentRestartTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!nmSecretAgentProc.running) {
                nmSecretAgentProc.running = true;
            }
        }
    }

    // Headless NetworkManager D-Bus Secret Agent for VPNs (OpenConnect, OpenVPN, etc.)
    Process {
        id: nmSecretAgentProc
        command: ["python3", Quickshell.env("HOME") + "/.local/share/nirakase/local/bin/nirakase-nm-agent"]
        running: true
        onExited: nmAgentRestartTimer.restart()
    }

    // Listen to NetworkManager D-Bus events (0% idle CPU, no periodic polling)
    Process {
        id: nmMonitorProc
        command: ["nmcli", "connection", "monitor"]
        environment: ({ "LC_ALL": "C.UTF-8", "LANG": "C.UTF-8" })
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.trim() !== "") {
                    vpnDebounceTimer.restart();
                }
            }
        }
        onExited: nmMonitorRestartTimer.restart()
    }

    // Query vpn and wireguard profiles when a connection event occurs
    Process {
        id: vpnQueryProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE,STATE,DEVICE", "connection", "show"]
        environment: ({ "LC_ALL": "C.UTF-8", "LANG": "C.UTF-8" })
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim();
                if (!line) return;
                // nmcli -t escapes ':' in names as '\:'; split from the end (UUID:TYPE:ACTIVE:STATE:DEVICE)
                var parts = line.split(":");
                if (parts.length < 6) return;
                var dev = parts[parts.length - 1] || "";
                var st = (parts[parts.length - 2] || "").toLowerCase();
                var act = (parts[parts.length - 3] || "").toLowerCase();
                var tp = (parts[parts.length - 4] || "").toLowerCase();
                var uuid = parts[parts.length - 5] || "";
                var name = parts.slice(0, parts.length - 5).join(":").replace(/\\:/g, ":");

                if (tp === "vpn" || tp === "wireguard") {
                    var connected = (st === "activated" || act === "yes") && st !== "activating";
                    var connecting = (st === "activating");
                    root._pendingVpns.push({
                        name: name || "VPN",
                        uuid: uuid,
                        type: tp,
                        typeLabel: tp === "wireguard" ? "WireGuard" : "VPN",
                        state: st,
                        device: dev,
                        connected: connected,
                        connecting: connecting
                    });
                }
            }
        }
        onExited: {
            var list = root._pendingVpns.slice();
            list.sort(function(a, b) {
                if (a.connected !== b.connected) return a.connected ? -1 : 1;
                if (a.connecting !== b.connecting) return a.connecting ? -1 : 1;
                return a.name.localeCompare(b.name);
            });
            root.vpnProfiles = list;
            if (root._vpnRefreshQueued) {
                root._vpnRefreshQueued = false;
                vpnDebounceTimer.restart();
            }
        }
    }
}
