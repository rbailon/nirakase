import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import ".."
import "../services"

ColumnLayout {
    id: root

    signal backRequested()
    signal closeRequested()

    property string selectedSsid: ""
    property string passwordSsid: ""
    property string passwordText: ""
    property bool revealPassword: false

    // Pause automatic scanning while the user has a network expanded / typing a password
    // to prevent the list from reordering under the cursor
    onSelectedSsidChanged: {
        if (root.visible && NetworkService.wifiPanelOpen) {
            NetworkService.setWifiScanner(selectedSsid === "");
        }
    }

    spacing: 8

    // ================= WI-FI SELECTOR HEADER =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Back button (󰁍)
        Rectangle {
            implicitWidth: backRow.implicitWidth + 12
            implicitHeight: 24
            radius: 6
            color: backMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: backMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            RowLayout {
                id: backRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "󰁍"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 12
                    color: Theme.textPrimary
                }

                Text {
                    text: "Back"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backRequested()
            }
        }

        Text {
            text: "Wi-Fi Networks"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.textPrimary
        }

        // Interface badge (e.g. wlan0)
        Rectangle {
            visible: NetworkService.wifiInterface !== ""
            implicitWidth: ifaceTxt.implicitWidth + 8
            implicitHeight: 16
            radius: 4
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Text {
                id: ifaceTxt
                anchors.centerIn: parent
                text: NetworkService.wifiInterface
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                color: Theme.textMuted
            }
        }

        // Active scanning indicator
        Text {
            visible: NetworkService.wifiPowered && NetworkService.wifiScanning
            text: "󰑐 Scanning"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 9
            color: Theme.accent
        }

        Item { Layout.fillWidth: true }

        // Wi-Fi ON / OFF switch
        Rectangle {
            implicitWidth: 32
            implicitHeight: 16
            radius: 8
            color: NetworkService.wifiPowered ? Theme.accent : (wifiSwitchMouse.containsMouse ? Theme.surfaceActive : Theme.border)

            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: NetworkService.wifiPowered ? parent.width - width - 2 : 2
                width: 12
                height: 12
                radius: 6
                color: NetworkService.wifiPowered ? (Theme.badgeFocusedText || "#FFFFFF") : Theme.textMuted

                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            }

            MouseArea {
                id: wifiSwitchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NetworkService.toggleWifi()
            }
        }

        // Close button (󰅖)
        Text {
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: closeWifiMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

            MouseArea {
                id: closeWifiMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    // ================= NETWORKMANAGER VPN / WIREGUARD PROFILES =================
    ColumnLayout {
        Layout.fillWidth: true
        visible: NetworkService.hasVpnProfiles
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "󰦝 VPN & WireGuard"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: Theme.textSecondary
            }

            Item { Layout.fillWidth: true }

            Text {
                text: NetworkService.lastVpnError !== ""
                    ? ("⚠ " + NetworkService.lastVpnError)
                    : (NetworkService.vpnConnecting
                        ? "Connecting..."
                        : (NetworkService.vpnConnected ? ("Active: " + NetworkService.activeVpnName) : "Disconnected"))
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                color: NetworkService.lastVpnError !== ""
                    ? Theme.danger
                    : (NetworkService.vpnConnecting
                        ? (Theme.warning || "#F59E0B")
                        : (NetworkService.vpnConnected ? (Theme.success || Theme.accent) : Theme.textMuted))
                elide: Text.ElideRight
                Layout.maximumWidth: 220
            }
        }

        Repeater {
            model: ScriptModel {
                values: NetworkService.vpnProfiles
            }

            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 8
                color: modelData.connected
                    ? Theme.surfaceActive
                    : (vpnRowMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                border.color: modelData.connected
                    ? (Theme.success || Theme.accent)
                    : (modelData.connecting ? (Theme.warning || "#F59E0B") : Theme.border)
                border.width: modelData.connected ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: modelData.connecting ? "󰦞" : "󰦝"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 13
                        color: modelData.connected
                            ? (Theme.success || Theme.accent)
                            : (modelData.connecting ? (Theme.warning || "#F59E0B") : Theme.textMuted)
                    }

                    Text {
                        text: modelData.name
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        font.weight: modelData.connected ? Font.Bold : Font.DemiBold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: vpnTypeLbl.implicitWidth + 8
                        implicitHeight: 16
                        radius: 4
                        color: Theme.background
                        border.color: Theme.border
                        border.width: 1

                        Text {
                            id: vpnTypeLbl
                            anchors.centerIn: parent
                            text: modelData.typeLabel
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            color: Theme.textMuted
                        }
                    }

                    // ON / OFF switch for each VPN profile
                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 16
                        radius: 8
                        color: (modelData.connected || modelData.connecting)
                            ? (Theme.success || Theme.accent)
                            : Theme.border

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: (modelData.connected || modelData.connecting) ? parent.width - width - 2 : 2
                            width: 12
                            height: 12
                            radius: 6
                            color: (modelData.connected || modelData.connecting)
                                ? (Theme.badgeFocusedText || "#FFFFFF")
                                : Theme.textMuted

                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }
                    }
                }

                MouseArea {
                    id: vpnRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkService.toggleVpn(modelData.uuid)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
            opacity: 0.5
        }
    }

    // ================= INTERNET / CAPTIVE PORTAL WARNING =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 7
        visible: NetworkService.hasConnectivityWarning
        color: Theme.surface
        border.color: Theme.warning || "#F59E0B"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
                text: "󰀦"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                color: Theme.warning || "#F59E0B"
            }

            Text {
                text: NetworkService.connectivityText
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.warning || "#F59E0B"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }

    // ================= WI-FI CONNECTION ERROR BANNER =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 7
        visible: NetworkService.lastWifiError !== ""
        color: Theme.surface
        border.color: Theme.danger
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
                text: "󰅙"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                color: Theme.danger
            }

            Text {
                text: (NetworkService.lastFailedSsid ? (NetworkService.lastFailedSsid + ": ") : "") + NetworkService.lastWifiError
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.danger
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: "󰅖"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: Theme.textMuted

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NetworkService.lastWifiError = "";
                        NetworkService.lastFailedSsid = "";
                    }
                }
            }
        }
    }

    // ================= POWERED OFF STATE =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !NetworkService.wifiPowered
        spacing: 8

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰤮"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 32
            color: Theme.textMuted
            opacity: 0.5
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: NetworkService.wifiHardwareEnabled ? "Wi-Fi is turned off" : "Wi-Fi blocked by hardware"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.textSecondary
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: NetworkService.wifiHardwareEnabled
            implicitWidth: 110
            implicitHeight: 28
            radius: 7
            color: turnOnMouse.containsMouse ? Theme.surfaceActive : Theme.surface
            border.color: Theme.accent
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Turn On Wi-Fi"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: Theme.accent
            }

            MouseArea {
                id: turnOnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NetworkService.toggleWifi()
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ================= NO NETWORKS FOUND STATE =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: NetworkService.wifiPowered && NetworkService.wifiNetworksCount === 0
        spacing: 6

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󱛇"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 28
            color: Theme.textMuted
            opacity: 0.5
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Searching for nearby Wi-Fi networks..."
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 11
            color: Theme.textMuted
        }

        Item { Layout.fillHeight: true }
    }

    // ================= AVAILABLE WI-FI NETWORKS LIST =================
    ListView {
        id: wifiList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        visible: NetworkService.wifiPowered && NetworkService.wifiNetworksCount > 0
        model: ScriptModel {
            values: NetworkService.wifiNetworks
        }
        boundsBehavior: Flickable.StopAtBounds

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                var delta = wheel.angleDelta.y;
                if (delta !== 0) {
                    var step = delta * 0.8;
                    var maxScroll = Math.max(0, wifiList.contentHeight - wifiList.height);
                    wifiList.contentY = Math.max(0, Math.min(maxScroll, wifiList.contentY - step));
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: wifiScroll
            active: true
            policy: ScrollBar.AsNeeded
            width: 6

            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: wifiScroll.pressed ? Theme.accent : (wifiScroll.hovered ? Theme.borderHover : Theme.border)
                opacity: wifiScroll.active ? 0.8 : 0.4
            }
        }

        delegate: Rectangle {
            id: netCard

            readonly property bool isExpanded: root.selectedSsid === modelData.name
            readonly property bool showPasswordInput: root.passwordSsid === modelData.name
            readonly property bool isSecure: NetworkService.isNetworkSecure(modelData)
            readonly property int sigPct: Math.round((modelData.signalStrength || 0) * 100)
            readonly property string secText: NetworkService.securityLabel(modelData.security)

            width: wifiList.width - (wifiScroll.visible ? 8 : 0)
            implicitHeight: cardCol.implicitHeight + 16
            radius: 10
            color: modelData.connected
                ? Theme.surfaceActive
                : (isExpanded ? Theme.surfaceHover : (headerMouse.containsMouse ? Theme.surfaceHover : Theme.surface))
            border.color: modelData.connected
                ? (NetworkService.hasConnectivityWarning ? (Theme.warning || "#F59E0B") : Theme.accent)
                : (isExpanded ? Theme.borderHover : Theme.border)
            border.width: modelData.connected ? 2 : 1

            Connections {
                target: modelData
                function onConnectionFailed(reason) {
                    NetworkService.lastFailedSsid = modelData.name;
                    NetworkService.lastWifiError = NetworkService.failReasonText(reason);
                    root.selectedSsid = modelData.name;
                    if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout) {
                        root.passwordSsid = modelData.name;
                        pwdField.forceActiveFocus();
                    }
                }
            }

            ColumnLayout {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 6

                // Main network row
                Item {
                    Layout.fillWidth: true
                    implicitHeight: mainNetRow.implicitHeight

                    RowLayout {
                        id: mainNetRow
                        anchors.fill: parent
                        spacing: 8

                        // Signal strength icon
                        Text {
                            text: modelData.stateChanging ? "󱛇" : NetworkService.networkIcon(modelData)
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 15
                            color: modelData.connected
                                ? (NetworkService.hasConnectivityWarning ? (Theme.warning || "#F59E0B") : Theme.accent)
                                : (modelData.stateChanging ? (Theme.warning || "#F59E0B") : Theme.textSecondary)
                        }

                        // SSID and quick summary
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modelData.name
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 11
                                font.weight: modelData.connected ? Font.Bold : Font.DemiBold
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: modelData.connected || modelData.stateChanging
                                text: modelData.stateChanging
                                    ? (modelData.state === ConnectionState.Disconnecting ? "Disconnecting..." : "Connecting...")
                                    : (NetworkService.hasConnectivityWarning
                                        ? ("⚠ " + NetworkService.connectivityText + " · " + NetworkService.wifiIp)
                                        : ("Connected · IP: " + NetworkService.wifiIp))
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 9
                                color: modelData.stateChanging || NetworkService.hasConnectivityWarning
                                    ? (Theme.warning || "#F59E0B")
                                    : Theme.accent
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // "Saved" badge for known networks not currently connected
                        Rectangle {
                            visible: modelData.known && !modelData.connected
                            implicitWidth: savedLbl.implicitWidth + 8
                            implicitHeight: 16
                            radius: 4
                            color: Theme.background
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                id: savedLbl
                                anchors.centerIn: parent
                                text: "Saved"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 8
                                color: Theme.textSecondary
                            }
                        }

                        // Security badge (WPA2 / WPA3 / Open)
                        Rectangle {
                            implicitWidth: secLbl.implicitWidth + 8
                            implicitHeight: 16
                            radius: 4
                            color: Theme.background
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                id: secLbl
                                anchors.centerIn: parent
                                text: (netCard.isSecure ? "󰌾 " : "󰌿 ") + netCard.secText
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 8
                                color: Theme.textMuted
                            }
                        }

                        // Signal percentage
                        Text {
                            text: netCard.sigPct + "%"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: headerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (netCard.isExpanded) {
                                root.selectedSsid = "";
                                root.passwordSsid = "";
                                root.passwordText = "";
                            } else {
                                root.selectedSsid = modelData.name;
                                root.passwordText = "";
                                if (!modelData.connected && netCard.isSecure && !modelData.known) {
                                    root.passwordSsid = modelData.name;
                                    pwdField.forceActiveFocus();
                                } else {
                                    root.passwordSsid = "";
                                }
                            }
                        }
                    }
                }

                // ================= EXPANDABLE ACTIONS & DETAILS SECTION =================
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: netCard.isExpanded
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.border
                        opacity: 0.5
                    }

                    // Technical details of the network
                    Text {
                        Layout.fillWidth: true
                        text: modelData.connected
                            ? `Signal: ${netCard.sigPct}% · Security: ${netCard.secText} · Interface: ${NetworkService.wifiInterface} · IP: ${NetworkService.wifiIp}`
                            : `Signal: ${netCard.sigPct}% · Security: ${netCard.secText}` + (modelData.known ? " · Saved profile in NetworkManager" : "")
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 9
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }

                    // WPA / WPA2 / WPA3 password field (for new secure networks or when clicking Password)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !modelData.connected && netCard.showPasswordInput
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: 6
                            color: Theme.background
                            border.color: pwdField.activeFocus ? Theme.accent : Theme.border
                            border.width: pwdField.activeFocus ? 2 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 4

                                TextInput {
                                    id: pwdField
                                    Layout.fillWidth: true
                                    font.family: "JetBrainsMono Nerd Font Propo"
                                    font.pixelSize: 10
                                    color: Theme.textPrimary
                                    echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
                                    clip: true
                                    selectByMouse: true
                                    text: root.passwordText
                                    onTextEdited: root.passwordText = text
                                    onVisibleChanged: {
                                        if (visible) pwdField.forceActiveFocus();
                                    }

                                    Keys.onReturnPressed: {
                                        if (pwdField.text.length > 0) {
                                            var p = pwdField.text;
                                            root.passwordText = "";
                                            root.passwordSsid = "";
                                            root.selectedSsid = "";
                                            NetworkService.connectToWifi(modelData, p);
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: pwdField.text.length === 0
                                        text: "Wi-Fi Password..."
                                        font.family: "JetBrainsMono Nerd Font Propo"
                                        font.pixelSize: 10
                                        color: Theme.textMuted
                                    }
                                }

                                // Show / hide password
                                Text {
                                    text: root.revealPassword ? "󰈉" : "󰈈"
                                    font.family: "JetBrainsMono Nerd Font Propo"
                                    font.pixelSize: 12
                                    color: eyeMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

                                    MouseArea {
                                        id: eyeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.revealPassword = !root.revealPassword
                                    }
                                }
                            }
                        }

                        // Connect with password button
                        Rectangle {
                            implicitWidth: 72
                            implicitHeight: 26
                            radius: 6
                            opacity: pwdField.text.length > 0 ? 1.0 : 0.5
                            color: connectPwdMouse.containsMouse && pwdField.text.length > 0 ? Theme.surfaceActive : Theme.background
                            border.color: Theme.accent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Theme.accent
                            }

                            MouseArea {
                                id: connectPwdMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: pwdField.text.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (pwdField.text.length > 0) {
                                        var p = pwdField.text;
                                        root.passwordText = "";
                                        root.passwordSsid = "";
                                        root.selectedSsid = "";
                                        NetworkService.connectToWifi(modelData, p);
                                    }
                                }
                            }
                        }
                    }

                    // Action buttons row (Connect / Disconnect / Password / Forget)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: modelData.connected || !netCard.showPasswordInput
                        spacing: 6

                        // Connect button (for open or saved networks)
                        Rectangle {
                            visible: !modelData.connected
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: btnConnMouse.containsMouse ? Theme.surfaceActive : Theme.background
                            border.color: Theme.accent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰤨 Connect"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Theme.accent
                            }

                            MouseArea {
                                id: btnConnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedSsid = "";
                                    NetworkService.connectToWifi(modelData, "");
                                }
                            }
                        }

                        // Password button (if network is secured)
                        Rectangle {
                            visible: !modelData.connected && netCard.isSecure
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: btnKeyMouse.containsMouse ? Theme.surfaceActive : Theme.background
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰌆 Password"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: btnKeyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.passwordSsid = modelData.name;
                                    pwdField.forceActiveFocus();
                                }
                            }
                        }

                        // Disconnect button (if currently connected)
                        Rectangle {
                            visible: modelData.connected
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: btnDiscMouse.containsMouse ? Theme.surfaceActive : Theme.background
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰤭 Disconnect"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: btnDiscMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkService.disconnectWifi()
                            }
                        }

                        // Forget network button (if saved in NetworkManager)
                        Rectangle {
                            visible: modelData.known
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: btnForgetMouse.containsMouse ? Theme.surfaceActive : Theme.background
                            border.color: btnForgetMouse.containsMouse ? Theme.danger : Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴 Forget"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.danger
                            }

                            MouseArea {
                                id: btnForgetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    NetworkService.forgetWifi(modelData);
                                    root.selectedSsid = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
