import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: root

    // Icon properties
    property string icon: ""
    property string fontFamily: "JetBrainsMono Nerd Font Propo"
    property real iconSize: 15
    property color iconColor: Theme.textPrimary ? Theme.textPrimary : "#ffffff"

    // Dimensions and shape
    property real buttonSize: 22
    property real radiusSize: 4
    property bool available: true
    property bool active: true

    // Counter and status badge (notifications, updates, etc.)
    property int count: 0
    property bool dotOnly: false
    property bool showBadge: (count > 0) || dotOnly
    property color badgeColor: Theme.danger ? Theme.danger : "#E03838"
    property color badgeTextColor: Theme.textPrimary ? Theme.textPrimary : "#FFFFFF"

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

    // Tooltip delay timer
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

        // Clean style at rest; intensifies on hover or press
        color: {
            if (mouseArea.pressed) return "#35ffffff";
            if (mouseArea.containsMouse) return "#1affffff";
            return "transparent";
        }
        border.color: mouseArea.containsMouse ? "#25ffffff" : "transparent"
        border.width: 1
        radius: root.radiusSize

        // Physical press feedback
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

        // Badge / Status indicator or counter
        Rectangle {
            id: badge
            visible: root.showBadge
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: root.dotOnly ? 4 : 2
            anchors.rightMargin: root.dotOnly ? 4 : 2

            // If dot-only, fixed small size; if it has text, it auto-adjusts
            width: root.dotOnly ? 7 : Math.max(14, badgeLabel.implicitWidth + 6)
            height: root.dotOnly ? 7 : 14
            radius: height / 2
            color: root.badgeColor
            border.color: "#1A1A1E"
            border.width: 1.5

            // Smooth badge entrance animation
            scale: root.showBadge ? 1.0 : 0.0
            Behavior on scale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutBack
                }
            }

            Text {
                id: badgeLabel
                visible: !root.dotOnly && root.count > 0
                anchors.centerIn: parent
                text: root.count > 99 ? "99+" : root.count.toString()
                color: root.badgeTextColor
                font.pixelSize: 8
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Click and hover detection for tooltip
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
