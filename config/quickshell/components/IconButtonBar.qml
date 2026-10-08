import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: root

    // Icon and content properties
    property string icon: ""
    property string fontFamily: "JetBrainsMono Nerd Font Propo"
    property real iconSize: 15
    property color iconColor: Theme.textPrimary ? Theme.textPrimary : "#ffffff"

    // Dimensions and shape
    property real buttonSize: 24
    property real radiusSize: 4
    property bool available: true
    property bool active: true

    // Tooltip capabilities
    property string tooltip: ""
    property var tooltipAnchor: Edges.Bottom

    // Interaction signals
    signal clicked()
    signal rightClicked()

    // Integration with layouts (ColumnLayout / RowLayout)
    visible: available
    implicitWidth: available ? buttonSize : 0
    implicitHeight: available ? buttonSize : 0
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.alignment: Qt.AlignHCenter

    // Timer for tooltip delay (avoids triggering on fast cursor movements)
    Timer {
        id: tooltipTimer
        interval: 350
        running: false
        repeat: false
        onTriggered: {
            if (mouseArea.containsMouse && root.tooltip !== "") {
                tooltipWindow.visible = true;
            }
        }
    }

    // Wayland popup window for tooltip (Waybar style)
    PopupWindow {
        id: tooltipWindow
        anchor.item: buttonFrame
        anchor.edges: root.tooltipAnchor
        anchor.gravity: root.tooltipAnchor
        visible: false
        color: "transparent"

        implicitWidth: tooltipBubble.implicitWidth + 8
        implicitHeight: tooltipBubble.implicitHeight + 8

        Rectangle {
            id: tooltipBubble
            anchors.centerIn: parent
            implicitWidth: tooltipText.implicitWidth + 16
            implicitHeight: tooltipText.implicitHeight + 10
            color: Theme.surface ? Theme.surface : "#18181B"
            border.color: Theme.surfaceActive ? Theme.surfaceActive : "#3F3F46"
            border.width: 1
            radius: 6

            Text {
                id: tooltipText
                anchors.centerIn: parent
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Theme.textPrimary ? Theme.textPrimary : "#F4F4F5"
                text: root.tooltip
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Visual button container
    Rectangle {
        id: buttonFrame
        anchors.fill: parent

        // At rest it is transparent; on hover the button outline is drawn
        color: {
            if (mouseArea.pressed) return "#35ffffff";
            if (mouseArea.containsMouse) return "#1affffff";
            return "transparent";
        }
        border.color: mouseArea.containsMouse ? "#25ffffff" : "transparent"
        border.width: 1
        radius: root.radiusSize

        // Physical press feedback on click
        scale: mouseArea.pressed ? 0.88 : 1.0
        transformOrigin: Item.Center

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }

        // Center icon
        Text {
            id: iconText
            anchors.centerIn: parent
            font.family: root.fontFamily
            font.pixelSize: root.iconSize
            color: root.iconColor
            text: root.icon
            opacity: root.active ? 1.0 : 0.5
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        // Left/right click and tooltip hover detection
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onContainsMouseChanged: {
                if (containsMouse && root.tooltip !== "") {
                    tooltipTimer.restart();
                } else {
                    tooltipTimer.stop();
                    tooltipWindow.visible = false;
                }
            }

            onClicked: mouse => {
                tooltipTimer.stop();
                tooltipWindow.visible = false;
                if (mouse.button === Qt.LeftButton) {
                    root.clicked();
                } else if (mouse.button === Qt.RightButton) {
                    root.rightClicked();
                }
            }
        }
    }
}
