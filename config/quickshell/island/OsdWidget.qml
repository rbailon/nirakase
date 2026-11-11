import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../services"

Item {
    id: root

    implicitWidth: 260
    implicitHeight: 22

    readonly property bool isProgress: OsdService.osdType === "volume" || 
                                       OsdService.osdType === "mic" || 
                                       OsdService.osdType === "brightness" || 
                                       OsdService.osdType === "kbd_brightness"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 10

        // 1. Icon (Left)
        Label {
            text: OsdService.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: OsdService.stateColor
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
        }

        // 2. Center Content (Progress bar OR Badge)
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter

            // Option A: Progress Bar
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 5
                radius: 2.5
                color: Theme.surfaceHover
                visible: root.isProgress

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.min(parent.width, Math.max(0, parent.width * (OsdService.level / 100.0)))
                    radius: 2.5
                    color: OsdService.stateColor

                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }

            // Option B: State Badge (Caps Lock, Num Lock, Power Profiles)
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, badgeText.implicitWidth + 16)
                height: 18
                radius: 9
                color: Qt.rgba(OsdService.stateColor.r, OsdService.stateColor.g, OsdService.stateColor.b, 0.15)
                border.width: 1
                border.color: Qt.rgba(OsdService.stateColor.r, OsdService.stateColor.g, OsdService.stateColor.b, 0.4)
                visible: !root.isProgress

                Label {
                    id: badgeText
                    anchors.centerIn: parent
                    text: OsdService.stateText
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                    color: OsdService.stateColor
                }
            }
        }

        // 3. Right Status / Percentage
        Label {
            visible: root.isProgress
            text: OsdService.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.bold: true
            color: OsdService.isMuted ? Theme.danger : Theme.textSecondary
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
        }
    }
}
