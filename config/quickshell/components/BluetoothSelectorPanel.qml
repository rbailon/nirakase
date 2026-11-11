import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import ".."
import "../services"

ColumnLayout {
    id: root

    signal backRequested()
    signal closeRequested()

    property string selectedAddress: ""

    // Pause scanning while the user has a device expanded to prevent the list from jumping
    onSelectedAddressChanged: {
        if (root.visible && BluetoothService.btPanelOpen) {
            BluetoothService.setDiscovering(selectedAddress === "");
        }
    }

    spacing: 8

    // ================= BLUETOOTH SELECTOR HEADER =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

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
            text: "Bluetooth"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.textPrimary
        }

        // Adapter badge (e.g. hci0)
        Rectangle {
            visible: BluetoothService.adapterId !== ""
            implicitWidth: adapterTxt.implicitWidth + 8
            implicitHeight: 16
            radius: 4
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Text {
                id: adapterTxt
                anchors.centerIn: parent
                text: BluetoothService.adapterId
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                color: Theme.textMuted
            }
        }

        // Scan / Discovery button & indicator
        Rectangle {
            visible: BluetoothService.isPowered
            implicitWidth: scanRow.implicitWidth + 10
            implicitHeight: 20
            radius: 5
            color: BluetoothService.isDiscovering ? Theme.surfaceActive : (scanMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
            border.color: BluetoothService.isDiscovering ? Theme.accent : Theme.border
            border.width: 1

            RowLayout {
                id: scanRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "󰑐"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    color: BluetoothService.isDiscovering ? Theme.accent : Theme.textSecondary
                }

                Text {
                    text: BluetoothService.isDiscovering ? "Scanning" : "Scan"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    font.weight: BluetoothService.isDiscovering ? Font.DemiBold : Font.Normal
                    color: BluetoothService.isDiscovering ? Theme.accent : Theme.textSecondary
                }
            }

            MouseArea {
                id: scanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.setDiscovering(!BluetoothService.isDiscovering)
            }
        }

        Item { Layout.fillWidth: true }

        // Bluetooth ON / OFF switch
        Rectangle {
            implicitWidth: 32
            implicitHeight: 16
            radius: 8
            color: BluetoothService.isPowered ? Theme.accent : (btSwitchMouse.containsMouse ? Theme.surfaceActive : Theme.border)

            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: BluetoothService.isPowered ? parent.width - width - 2 : 2
                width: 12
                height: 12
                radius: 6
                color: BluetoothService.isPowered ? (Theme.badgeFocusedText || "#FFFFFF") : Theme.textMuted

                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            }

            MouseArea {
                id: btSwitchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.toggleBluetooth()
            }
        }

        // Close button (󰅖)
        Text {
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: closeBtMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

            MouseArea {
                id: closeBtMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    // ================= POWERED OFF STATE =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !BluetoothService.isPowered
        spacing: 8

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰂲"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 32
            color: Theme.textMuted
            opacity: 0.5
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: BluetoothService.isBlocked ? "Bluetooth blocked by hardware" : "Bluetooth is turned off"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.textSecondary
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: !BluetoothService.isBlocked
            implicitWidth: 130
            implicitHeight: 28
            radius: 7
            color: turnOnBtMouse.containsMouse ? Theme.surfaceActive : Theme.surface
            border.color: Theme.accent
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Turn On Bluetooth"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: Theme.accent
            }

            MouseArea {
                id: turnOnBtMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.toggleBluetooth()
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ================= NO DEVICES STATE =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: BluetoothService.isPowered && BluetoothService.totalDevicesCount === 0
        spacing: 6

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰂰"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 28
            color: Theme.textMuted
            opacity: 0.5
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Searching for nearby Bluetooth devices..."
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 11
            color: Theme.textMuted
        }

        Item { Layout.fillHeight: true }
    }

    // ================= BLUETOOTH DEVICE LIST =================
    ListView {
        id: btList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        visible: BluetoothService.isPowered && BluetoothService.totalDevicesCount > 0
        model: ScriptModel {
            values: BluetoothService.allDevices
        }
        boundsBehavior: Flickable.StopAtBounds

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                var delta = wheel.angleDelta.y;
                if (delta !== 0) {
                    var step = delta * 0.8;
                    var maxScroll = Math.max(0, btList.contentHeight - btList.height);
                    btList.contentY = Math.max(0, Math.min(maxScroll, btList.contentY - step));
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: btScroll
            active: true
            policy: ScrollBar.AsNeeded
            width: 6

            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: btScroll.pressed ? Theme.accent : (btScroll.hovered ? Theme.borderHover : Theme.border)
                opacity: btScroll.active ? 0.8 : 0.4
            }
        }

        delegate: Rectangle {
            id: devCard

            readonly property bool isExpanded: root.selectedAddress === modelData.address
            readonly property bool isStateChanging: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting || modelData.pairing
            readonly property string displayName: modelData.name || modelData.deviceName || modelData.address
            readonly property int batPct: modelData.batteryAvailable ? Math.round((modelData.battery || 0) * 100) : -1
            readonly property string typeText: BluetoothService.deviceTypeLabel(modelData)

            width: btList.width - (btScroll.visible ? 8 : 0)
            implicitHeight: devCol.implicitHeight + 16
            radius: 10
            color: modelData.connected
                ? Theme.surfaceActive
                : (isExpanded ? Theme.surfaceHover : (devHeaderMouse.containsMouse ? Theme.surfaceHover : Theme.surface))
            border.color: modelData.connected
                ? Theme.accent
                : (isExpanded ? Theme.borderHover : Theme.border)
            border.width: modelData.connected ? 2 : 1

            ColumnLayout {
                id: devCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 6

                // Main device row
                Item {
                    Layout.fillWidth: true
                    implicitHeight: mainDevRow.implicitHeight

                    RowLayout {
                        id: mainDevRow
                        anchors.fill: parent
                        spacing: 8

                        // Icon by peripheral type (headphones, mouse, keyboard, controller...)
                        Text {
                            text: devCard.isStateChanging ? "󰂰" : BluetoothService.deviceIcon(modelData)
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 15
                            color: modelData.connected
                                ? Theme.accent
                                : (devCard.isStateChanging ? (Theme.warning || "#F59E0B") : Theme.textSecondary)
                        }

                        // Name and status
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: devCard.displayName
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 11
                                font.weight: modelData.connected ? Font.Bold : Font.DemiBold
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: modelData.connected || devCard.isStateChanging
                                text: {
                                    if (modelData.pairing) return "Pairing...";
                                    if (modelData.state === BluetoothDeviceState.Connecting) return "Connecting...";
                                    if (modelData.state === BluetoothDeviceState.Disconnecting) return "Disconnecting...";
                                    return "Connected · " + devCard.typeText;
                                }
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 9
                                color: devCard.isStateChanging ? (Theme.warning || "#F59E0B") : Theme.accent
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Bluetooth device battery badge (if available)
                        Rectangle {
                            visible: devCard.batPct >= 0
                            implicitWidth: batLbl.implicitWidth + 8
                            implicitHeight: 16
                            radius: 4
                            color: Theme.background
                            border.color: devCard.batPct < 20 ? Theme.danger : Theme.border
                            border.width: 1

                            Text {
                                id: batLbl
                                anchors.centerIn: parent
                                text: BluetoothService.batteryIcon(devCard.batPct) + " " + devCard.batPct + "%"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                color: devCard.batPct < 20
                                    ? Theme.danger
                                    : (devCard.batPct < 40 ? (Theme.warning || "#F59E0B") : (Theme.success || "#10B981"))
                            }
                        }

                        // "Saved" badge for paired but disconnected devices
                        Rectangle {
                            visible: modelData.paired && !modelData.connected
                            implicitWidth: pairedLbl.implicitWidth + 8
                            implicitHeight: 16
                            radius: 4
                            color: Theme.background
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                id: pairedLbl
                                anchors.centerIn: parent
                                text: "Saved"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 8
                                color: Theme.textSecondary
                            }
                        }

                        // Device type badge
                        Rectangle {
                            visible: !modelData.connected
                            implicitWidth: typeLbl.implicitWidth + 8
                            implicitHeight: 16
                            radius: 4
                            color: Theme.background
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                id: typeLbl
                                anchors.centerIn: parent
                                text: devCard.typeText
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 8
                                color: Theme.textMuted
                            }
                        }
                    }

                    MouseArea {
                        id: devHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedAddress = devCard.isExpanded ? "" : modelData.address;
                        }
                    }
                }

                // ================= EXPANDABLE ACTIONS & DETAILS SECTION =================
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: devCard.isExpanded
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.border
                        opacity: 0.5
                    }

                    // Device technical details
                    Text {
                        Layout.fillWidth: true
                        text: {
                            var info = `Type: ${devCard.typeText} · MAC: ${modelData.address}`;
                            if (devCard.batPct >= 0) info += ` · Battery: ${devCard.batPct}%`;
                            else if (modelData.paired) info += " · Paired";
                            return info;
                        }
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 9
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }

                    // Action buttons (Connect / Disconnect / Forget)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Connect / Pair button
                        Rectangle {
                            visible: !modelData.connected
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: btConnMouse.containsMouse ? Theme.surfaceActive : Theme.background
                            border.color: Theme.accent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.paired ? "󰂱 Connect" : "󰂰 Pair & Connect"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Theme.accent
                            }

                            MouseArea {
                                id: btConnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedAddress = "";
                                    BluetoothService.connectDevice(modelData);
                                }
                            }
                        }

                        // Disconnect button
                        Rectangle {
                            visible: modelData.connected
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: btDiscMouse.containsMouse ? Theme.surfaceActive : Theme.background
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰂲 Disconnect"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: btDiscMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedAddress = "";
                                    BluetoothService.disconnectDevice(modelData);
                                }
                            }
                        }

                        // Forget device button (if paired)
                        Rectangle {
                            visible: modelData.paired
                            Layout.fillWidth: true
                            implicitHeight: 24
                            radius: 6
                            color: btForgetMouse.containsMouse ? Theme.surfaceActive : Theme.background
                            border.color: btForgetMouse.containsMouse ? Theme.danger : Theme.border
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
                                id: btForgetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedAddress = "";
                                    BluetoothService.forgetDevice(modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
