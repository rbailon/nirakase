import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../services"

FocusScope {
    id: root

    implicitWidth: 420
    implicitHeight: 580
    width: implicitWidth
    height: implicitHeight
    focus: true

    signal closeRequested()

    // Internal states
    property int brightnessLevel: 50

    readonly property var powerProfiles: [
        { id: "power-saver", name: "Power Saver", icon: "󰌪", color: Theme.success || "#10B981" },
        { id: "balanced", name: "Balanced", icon: "󰗑", color: Theme.accent || "#3B82F6" },
        { id: "performance", name: "Performance", icon: "󰓅", color: Theme.danger || "#EF4444" }
    ]

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
            root.refreshAll();
            NetworkService.setWifiScanner(NetworkService.wifiPanelOpen);
            BluetoothService.setDiscovering(BluetoothService.btPanelOpen);
        } else {
            NetworkService.setWifiScanner(false);
            NetworkService.wifiPanelOpen = false;
            BluetoothService.setDiscovering(false);
            BluetoothService.btPanelOpen = false;
            AudioService.audioPanelOpen = false;
            IdleService.idlePanelOpen = false;
        }
    }

    Connections {
        target: NetworkService
        function onWifiPanelOpenChanged() {
            if (NetworkService.wifiPanelOpen) {
                BluetoothService.btPanelOpen = false;
                AudioService.audioPanelOpen = false;
                IdleService.idlePanelOpen = false;
            }
            NetworkService.setWifiScanner(root.visible && NetworkService.wifiPanelOpen);
        }
    }

    Connections {
        target: BluetoothService
        function onBtPanelOpenChanged() {
            if (BluetoothService.btPanelOpen) {
                NetworkService.wifiPanelOpen = false;
                AudioService.audioPanelOpen = false;
                IdleService.idlePanelOpen = false;
            }
            BluetoothService.setDiscovering(root.visible && BluetoothService.btPanelOpen);
        }
    }

    Connections {
        target: AudioService
        function onAudioPanelOpenChanged() {
            if (AudioService.audioPanelOpen) {
                NetworkService.wifiPanelOpen = false;
                BluetoothService.btPanelOpen = false;
                IdleService.idlePanelOpen = false;
            }
        }
    }

    Connections {
        target: IdleService
        function onIdlePanelOpenChanged() {
            if (IdleService.idlePanelOpen) {
                NetworkService.wifiPanelOpen = false;
                BluetoothService.btPanelOpen = false;
                AudioService.audioPanelOpen = false;
            }
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (NetworkService.wifiPanelOpen) {
                NetworkService.wifiPanelOpen = false;
            } else if (BluetoothService.btPanelOpen) {
                BluetoothService.btPanelOpen = false;
            } else if (AudioService.audioPanelOpen) {
                AudioService.audioPanelOpen = false;
            } else if (IdleService.idlePanelOpen) {
                IdleService.idlePanelOpen = false;
            } else {
                root.closeRequested();
            }
            event.accepted = true;
        }
    }

    // Helper process to execute system commands and changes
    Process {
        id: execProc
    }

    // -------------------------------------------------------------
    // Wi-Fi and Bluetooth Actions
    // -------------------------------------------------------------
    function toggleWifi() {
        NetworkService.toggleWifi();
    }

    function openWifiManager() {
        BluetoothService.btPanelOpen = false;
        AudioService.audioPanelOpen = false;
        NetworkService.wifiPanelOpen = true;
    }

    function toggleBluetooth() {
        BluetoothService.toggleBluetooth();
    }

    function openBluetoothManager() {
        NetworkService.wifiPanelOpen = false;
        AudioService.audioPanelOpen = false;
        BluetoothService.btPanelOpen = true;
    }

    // -------------------------------------------------------------
    // Audio and Brightness Actions
    // -------------------------------------------------------------
    function setVolume(val) {
        AudioService.setVolume(val);
    }

    function toggleMute() {
        AudioService.toggleMute();
    }

    function openAudioManager() {
        NetworkService.wifiPanelOpen = false;
        BluetoothService.btPanelOpen = false;
        AudioService.audioPanelOpen = true;
    }

    function setBrightness(val) {
        root.brightnessLevel = val;
        execProc.exec(["brightnessctl", "set", val + "%"]);
    }

    // -------------------------------------------------------------
    // Idle and Power Profile Actions
    // -------------------------------------------------------------
    function toggleIdle() {
        IdleService.toggleInhibit();
    }

    function openIdleManager() {
        NetworkService.wifiPanelOpen = false;
        BluetoothService.btPanelOpen = false;
        AudioService.audioPanelOpen = false;
        IdleService.idlePanelOpen = true;
    }

    function setPowerProfile(profile) {
        OsdService.powerProfileSet(profile);
    }

    function refreshAll() {
        if (!statusProc.running) statusProc.running = true;
        NetworkService.refreshVpns();
    }

    // Process to query current brightness
    Process {
        id: statusProc
        command: [
            "bash",
            "-c",
            "bri=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'); echo \"BRI:$bri\""
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim();
                if (line.startsWith("BRI:")) {
                    var bVal = parseInt(line.substring(4));
                    if (!isNaN(bVal)) root.brightnessLevel = bVal;
                }
            }
        }
    }

    // Periodic refresh every 3.5 seconds when the control center is visible
    Timer {
        interval: 3500
        running: root.visible
        repeat: true
        onTriggered: root.refreshAll()
    }

    // ================= NATIVE WI-FI NETWORK SELECTOR VIEW =================
    WifiSelectorPanel {
        anchors.fill: parent
        anchors.margins: 10
        visible: NetworkService.wifiPanelOpen
        onBackRequested: NetworkService.wifiPanelOpen = false
        onCloseRequested: root.closeRequested()
    }

    // ================= NATIVE BLUETOOTH SELECTOR VIEW =================
    BluetoothSelectorPanel {
        anchors.fill: parent
        anchors.margins: 10
        visible: BluetoothService.btPanelOpen
        onBackRequested: BluetoothService.btPanelOpen = false
        onCloseRequested: root.closeRequested()
    }

    // ================= NATIVE AUDIO SELECTOR / MIXER VIEW =================
    AudioSelectorPanel {
        anchors.fill: parent
        anchors.margins: 10
        visible: AudioService.audioPanelOpen
        onBackRequested: AudioService.audioPanelOpen = false
        onCloseRequested: root.closeRequested()
    }

    // ================= IDLE & INACTIVITY SETTINGS VIEW =================
    IdleSelectorPanel {
        anchors.fill: parent
        anchors.margins: 10
        visible: IdleService.idlePanelOpen
        onBackRequested: IdleService.idlePanelOpen = false
        onCloseRequested: root.closeRequested()
    }

    // ================= MAIN CONTAINER =================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 9
        visible: !NetworkService.wifiPanelOpen && !BluetoothService.btPanelOpen && !AudioService.audioPanelOpen && !IdleService.idlePanelOpen

        // ================= HEADER =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Control Center"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Theme.textPrimary
            }

            // Warning badge if there is no Internet access or Captive Portal
            Rectangle {
                visible: NetworkService.hasConnectivityWarning
                implicitWidth: netWarnLbl.implicitWidth + 10
                implicitHeight: 18
                radius: 5
                color: Theme.surface
                border.color: Theme.warning || "#F59E0B"
                border.width: 1

                Text {
                    id: netWarnLbl
                    anchors.centerIn: parent
                    text: "󰀦 " + NetworkService.connectivityText
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: Theme.warning || "#F59E0B"
                }
            }

            Item { Layout.fillWidth: true }

            // Close button (󰅖)
            Text {
                text: "󰅖"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 14
                color: closeMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ================= CONNECTIVITY CARDS =================
        // Wi-Fi & Bluetooth
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            QuickToggleTile {
                icon: NetworkService.wifiIcon
                title: NetworkService.wifiInterface ? ("Wi-Fi · " + NetworkService.wifiInterface) : "Wi-Fi"
                deviceName: !NetworkService.wifiPowered
                    ? "Off"
                    : (NetworkService.wifiConnecting
                        ? "Connecting..."
                        : (NetworkService.wifiConnected ? NetworkService.wifiSsid : "Disconnected"))
                statusText: {
                    if (!NetworkService.wifiPowered) return "Radio turned off";
                    if (NetworkService.wifiConnecting) return "Negotiating connection...";
                    if (!NetworkService.wifiConnected) return "No active connection";
                    if (NetworkService.hasConnectivityWarning) {
                        return "⚠ " + (NetworkService.isCaptivePortal ? "Captive portal" : "No Internet") + " · " + NetworkService.wifiSignalPct + "%";
                    }
                    var sec = NetworkService.wifiSecurity ? (" · " + NetworkService.wifiSecurity) : "";
                    return NetworkService.wifiSignalPct + "%" + sec + " · " + NetworkService.wifiIp;
                }
                actionLabel: NetworkService.wifiPowered && NetworkService.wifiNetworksCount > 0
                    ? ("Wi-Fi Networks (" + NetworkService.wifiNetworksCount + ")")
                    : "Wi-Fi Networks"
                active: NetworkService.wifiPowered && NetworkService.wifiConnected
                powered: NetworkService.wifiPowered
                onToggled: root.toggleWifi()
                onActionClicked: root.openWifiManager()
            }

            QuickToggleTile {
                icon: BluetoothService.isConnected && BluetoothService.primaryDevice
                    ? BluetoothService.deviceIcon(BluetoothService.primaryDevice)
                    : BluetoothService.btIcon
                title: BluetoothService.adapterId ? ("Bluetooth · " + BluetoothService.adapterId) : "Bluetooth"
                deviceName: {
                    if (!BluetoothService.isPowered) return "Off";
                    if (BluetoothService.isConnecting) return "Connecting...";
                    if (!BluetoothService.isConnected) return "Disconnected";
                    if (BluetoothService.connectedCount > 1) {
                        return BluetoothService.primaryDeviceName + " (+" + (BluetoothService.connectedCount - 1) + ")";
                    }
                    return BluetoothService.primaryDeviceName;
                }
                statusText: {
                    if (!BluetoothService.isPowered) return "Radio turned off";
                    if (BluetoothService.isConnecting) return "Negotiating link...";
                    if (!BluetoothService.isConnected) return "No active devices";
                    var typeStr = BluetoothService.deviceTypeLabel(BluetoothService.primaryDevice);
                    if (BluetoothService.primaryHasBattery) {
                        return typeStr + " · " + BluetoothService.primaryBatteryPct + "% battery";
                    }
                    return typeStr + " · Connected";
                }
                actionLabel: BluetoothService.isPowered && BluetoothService.totalDevicesCount > 0
                    ? ("Devices (" + BluetoothService.totalDevicesCount + ")")
                    : "Devices"
                active: BluetoothService.isPowered && BluetoothService.isConnected
                powered: BluetoothService.isPowered
                onToggled: root.toggleBluetooth()
                onActionClicked: root.openBluetoothManager()
            }
        }

        // Compact Wired Network (Ethernet) card when an Ethernet interface exists
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 9
            visible: NetworkService.hasWiredDevice
            color: Theme.surface
            border.color: NetworkService.wiredConnected
                ? (NetworkService.hasConnectivityWarning ? (Theme.warning || "#F59E0B") : Theme.accent)
                : Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: NetworkService.wiredIcon
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 14
                    color: NetworkService.wiredConnected
                        ? (NetworkService.hasConnectivityWarning ? (Theme.warning || "#F59E0B") : Theme.accent)
                        : Theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Ethernet (" + NetworkService.wiredInterface + ")"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            if (!NetworkService.wiredHasLink) return "Cable unplugged";
                            if (NetworkService.wiredConnecting) return "Obtaining IP address...";
                            if (!NetworkService.wiredConnected) return "Physical link detected · Disconnected";
                            var spd = NetworkService.wiredLinkSpeed > 0 ? (NetworkService.wiredLinkSpeed + " Mbps · ") : "";
                            return spd + "IP: " + NetworkService.wiredIp;
                        }
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 9
                        color: NetworkService.wiredConnected ? Theme.accent : Theme.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Connect / Disconnect Ethernet button if cable is plugged in
                Rectangle {
                    visible: NetworkService.wiredHasLink
                    implicitWidth: ethBtnLbl.implicitWidth + 12
                    implicitHeight: 22
                    radius: 6
                    color: ethBtnMouse.containsMouse ? Theme.surfaceActive : Theme.background
                    border.color: ethBtnMouse.containsMouse ? Theme.borderHover : Theme.border
                    border.width: 1

                    Text {
                        id: ethBtnLbl
                        anchors.centerIn: parent
                        text: NetworkService.wiredConnected ? "Disconnect" : "Connect"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: NetworkService.wiredConnected ? Theme.textSecondary : Theme.accent
                    }

                    MouseArea {
                        id: ethBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NetworkService.toggleWired()
                    }
                }
            }
        }

        // Compact VPN / WireGuard card when VPN profiles exist in NetworkManager
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 9
            visible: NetworkService.hasVpnProfiles
            color: Theme.surface
            border.color: NetworkService.vpnConnected
                ? (Theme.success || Theme.accent)
                : (NetworkService.vpnConnecting ? (Theme.warning || "#F59E0B") : Theme.border)
            border.width: NetworkService.vpnConnected ? 2 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: NetworkService.vpnIcon
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 14
                    color: NetworkService.vpnConnected
                        ? (Theme.success || Theme.accent)
                        : (NetworkService.vpnConnecting ? (Theme.warning || "#F59E0B") : Theme.textMuted)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 0

                        Text {
                            text: NetworkService.primaryVpn
                                ? (NetworkService.primaryVpn.typeLabel + " · " + NetworkService.primaryVpn.name)
                                : "VPN"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                if (NetworkService.lastVpnError !== "") return "⚠ " + NetworkService.lastVpnError;
                                if (NetworkService.vpnConnecting) return "Establishing secure tunnel...";
                                if (NetworkService.vpnConnected) {
                                    var dev = (NetworkService.activeVpn && NetworkService.activeVpn.device)
                                        ? (" (" + NetworkService.activeVpn.device + ")")
                                        : "";
                                    return "Active tunnel" + dev;
                                }
                                if (NetworkService.vpnCount > 1) {
                                    return "Disconnected · " + NetworkService.vpnCount + " profiles available";
                                }
                                return "Disconnected";
                            }
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 9
                            color: NetworkService.lastVpnError !== ""
                                ? Theme.danger
                                : (NetworkService.vpnConnected
                                    ? (Theme.success || Theme.accent)
                                    : (NetworkService.vpnConnecting ? (Theme.warning || "#F59E0B") : Theme.textMuted))
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openWifiManager()
                    }
                }

                // 1-click Connect / Disconnect VPN button
                Rectangle {
                    implicitWidth: vpnBtnLbl.implicitWidth + 12
                    implicitHeight: 22
                    radius: 6
                    color: vpnBtnMouse.containsMouse ? Theme.surfaceActive : Theme.background
                    border.color: NetworkService.vpnConnected
                        ? Theme.border
                        : (vpnBtnMouse.containsMouse ? Theme.borderHover : (Theme.success || Theme.accent))
                    border.width: 1

                    Text {
                        id: vpnBtnLbl
                        anchors.centerIn: parent
                        text: (NetworkService.vpnConnected || NetworkService.vpnConnecting) ? "Disable" : "Enable"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: (NetworkService.vpnConnected || NetworkService.vpnConnecting)
                            ? Theme.textSecondary
                            : (Theme.success || Theme.accent)
                    }

                    MouseArea {
                        id: vpnBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NetworkService.togglePrimaryVpn()
                    }
                }
            }
        }

        // ================= SYSTEM SLIDERS =================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                SystemSlider {
                    Layout.fillWidth: true
                    icon: AudioService.sinkIcon
                    value: AudioService.volume
                    muted: AudioService.isMuted
                    iconClickable: true
                    onMoved: val => root.setVolume(val)
                    onIconClicked: root.toggleMute()
                }

                // Button to open output/input selector & app mixer
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 8
                    color: audioMixMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                    border.color: audioMixMouse.containsMouse ? Theme.borderHover : Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰍜"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 13
                        color: audioMixMouse.containsMouse ? Theme.accent : Theme.textSecondary
                    }

                    MouseArea {
                        id: audioMixMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openAudioManager()
                    }
                }
            }

            SystemSlider {
                icon: "󰃠"
                value: root.brightnessLevel
                from: 5
                iconClickable: false
                onMoved: val => root.setBrightness(val)
            }
        }

        // ================= QUICK ACTIONS (DO NOT DISTURB + IDLE) =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Do Not Disturb (DND) button
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: NotificationService.dnd ? Theme.surfaceActive : (dndMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                border.color: NotificationService.dnd ? Theme.danger : Theme.border
                border.width: NotificationService.dnd ? 2 : 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: NotificationService.dnd ? "󰂛" : "󰂚"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 12
                        color: NotificationService.dnd ? Theme.danger : Theme.textSecondary
                    }

                    Text {
                        text: NotificationService.dnd ? "Do Not Disturb (ON)" : "Do Not Disturb"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: NotificationService.dnd ? Theme.danger : Theme.textPrimary
                    }
                }

                MouseArea {
                    id: dndMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.toggleDnd()
                }
            }

            // Automatic Idle (Caffeine Mode) + Timeout configuration button
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: IdleService.inhibited ? Theme.surfaceActive : (idleMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                border.color: IdleService.inhibited ? Theme.warning : Theme.border
                border.width: IdleService.inhibited ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: IdleService.icon
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 12
                                color: IdleService.inhibited ? Theme.warning : Theme.textSecondary
                            }

                            Text {
                                text: IdleService.inhibited
                                    ? "Idle: Inhibited"
                                    : ("Idle · " + IdleService.formatDuration(IdleService.lockTimeout))
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: IdleService.inhibited ? Theme.warning : Theme.textPrimary
                            }
                        }

                        MouseArea {
                            id: idleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.openIdleManager();
                                } else {
                                    root.toggleIdle();
                                }
                            }
                        }
                    }

                    // Vertical separator and idle timeout settings button
                    Rectangle {
                        implicitWidth: 1
                        implicitHeight: 16
                        color: Theme.border
                        opacity: 0.6
                    }

                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 20
                        radius: 5
                        color: idleCfgMouse.containsMouse ? Theme.surfaceActive : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 11
                            color: idleCfgMouse.containsMouse ? Theme.accent : Theme.textMuted
                        }

                        MouseArea {
                            id: idleCfgMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openIdleManager()
                        }
                    }
                }
            }
        }

        // ================= POWER PROFILE SELECTOR (3 OPTIONS) =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.powerProfiles

                Rectangle {
                    id: pwrBtn
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 7

                    readonly property bool isSelected: PowerService.currentProfileId === modelData.id

                    color: isSelected ? Theme.surfaceActive : (pwrMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                    border.color: isSelected ? modelData.color : (pwrMouse.containsMouse ? Theme.borderHover : Theme.border)
                    border.width: isSelected ? 2 : 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: modelData.icon
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 11
                            color: pwrBtn.isSelected ? modelData.color : Theme.textMuted
                        }

                        Text {
                            text: modelData.name
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 10
                            font.weight: pwrBtn.isSelected ? Font.Bold : Font.Normal
                            color: pwrBtn.isSelected ? Theme.textPrimary : Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: pwrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setPowerProfile(modelData.id)
                    }
                }
            }
        }

        // Divider line between controls and notifications
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
            opacity: 0.5
        }

        // ================= NOTIFICATIONS SECTION =================
        // Notifications header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰂚 Notifications"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 13
                font.weight: Font.Bold
                color: Theme.textPrimary
            }

            Rectangle {
                visible: NotificationService.unreadCount > 0
                implicitWidth: countText.implicitWidth + 8
                implicitHeight: 16
                radius: 8
                color: Theme.accent

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: String(NotificationService.unreadCount)
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.badgeFocusedText || "#FFFFFF"
                }
            }

            Item { Layout.fillWidth: true }

            // Clear All button
            Rectangle {
                visible: NotificationService.unreadCount > 0
                implicitWidth: clearRow.implicitWidth + 10
                implicitHeight: 22
                radius: 6
                color: clearMouse.containsMouse ? Theme.surfaceHover : "transparent"
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰆴"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 11
                        color: Theme.danger
                    }

                    Text {
                        text: "Clear"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.danger
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearAll()
                }
            }
        }

        // Empty state when there are no notifications
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.unreadCount === 0
            spacing: 4

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰂜"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 28
                color: Theme.textMuted
                opacity: 0.4
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No pending notifications"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: Theme.textMuted
            }

            Item { Layout.fillHeight: true }
        }

        // Notification list with ScrollBar reusing NotificationsCard
        ListView {
            id: notifList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: NotificationService.history
            boundsBehavior: Flickable.StopAtBounds
            visible: NotificationService.unreadCount > 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    var delta = wheel.angleDelta.y;
                    if (delta !== 0) {
                        var step = delta * 0.8;
                        var maxScroll = Math.max(0, notifList.contentHeight - notifList.height);
                        notifList.contentY = Math.max(0, Math.min(maxScroll, notifList.contentY - step));
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: vbar
                active: true
                policy: ScrollBar.AsNeeded
                width: 6

                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: vbar.pressed ? Theme.accent : (vbar.hovered ? Theme.borderHover : Theme.border)
                    opacity: vbar.active ? 0.8 : 0.4
                }
            }

            delegate: NotificationsCard {
                width: notifList.width - (vbar.visible ? 8 : 0)
                notification: modelData
            }
        }
    }
}
