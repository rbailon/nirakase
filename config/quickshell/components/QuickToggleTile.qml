import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string deviceName: "Disconnected"
    property string statusText: ""
    property string actionLabel: "Manage"
    property bool active: false
    property bool powered: true

    signal toggled()
    signal actionClicked()

    Layout.fillWidth: true
    implicitHeight: 96
    radius: 12
    color: Theme.surface
    border.color: root.active ? Theme.accent : Theme.border
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        // Top Row: Icon, Title, and Power On/Off Switch
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.icon
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 13
                color: root.active ? Theme.accent : Theme.textMuted
            }

            Text {
                text: root.title
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: Theme.textPrimary
                Layout.fillWidth: true
            }

            // Visual ON / OFF switch
            Rectangle {
                id: toggleSwitch
                implicitWidth: 32
                implicitHeight: 16
                radius: 8
                color: root.powered ? Theme.accent : (switchMouse.containsMouse ? Theme.surfaceActive : Theme.border)

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.powered ? parent.width - width - 2 : 2
                    width: 12
                    height: 12
                    radius: 6
                    color: root.powered ? (Theme.badgeFocusedText || "#FFFFFF") : Theme.textMuted

                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }

                MouseArea {
                    id: switchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggled()
                }
            }
        }

        // Middle Info Area (Device / network name and signal status)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: root.deviceName
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.statusText
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                color: root.active ? Theme.accent : Theme.textMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Bottom Button: Clear action to switch network or manage devices
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 22
            radius: 6
            color: actionMouse.containsMouse ? Theme.surfaceActive : Theme.background
            border.color: actionMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6

                Text {
                    text: root.actionLabel
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: actionMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "󰅂"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 11
                    color: actionMouse.containsMouse ? Theme.accent : Theme.textMuted
                }
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionClicked()
            }
        }
    }
}
