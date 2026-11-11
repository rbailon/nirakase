import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    property string icon: ""
    property int value: 50
    property int from: 0
    property int to: 100
    property bool muted: false
    property string suffix: "%"

    property bool iconClickable: false

    signal moved(int newValue)
    signal iconClicked()

    spacing: 8
    Layout.fillWidth: true

    // Left icon (button if iconClickable, or info label if not)
    Rectangle {
        implicitWidth: 28
        implicitHeight: 28
        radius: 6
        color: (root.iconClickable && iconMouse.containsMouse) ? Theme.surfaceActive : "transparent"

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: root.muted ? Theme.danger : ((root.iconClickable && iconMouse.containsMouse) ? Theme.accent : Theme.textPrimary)
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            enabled: root.iconClickable
            hoverEnabled: root.iconClickable
            cursorShape: root.iconClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.iconClicked()
        }
    }

    // Interactive slider track
    Rectangle {
        id: track
        Layout.fillWidth: true
        implicitHeight: 16
        radius: 8
        color: Theme.surface
        border.color: trackMouse.containsMouse ? Theme.borderHover : Theme.border
        border.width: 1
        clip: true

        readonly property real normalized: Math.max(0, Math.min(1, (root.value - root.from) / Math.max(1, (root.to - root.from))))

        // Filled progress bar
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: track.width * track.normalized
            radius: 8
            color: root.muted ? Theme.textMuted : Theme.accent
        }

        MouseArea {
            id: trackMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function updateFromMouse(mouseX) {
                var pct = Math.max(0, Math.min(1, mouseX / track.width));
                var val = Math.round(root.from + pct * (root.to - root.from));
                root.moved(val);
            }

            onPressed: mouse => updateFromMouse(mouse.x)
            onPositionChanged: mouse => {
                if (pressed) updateFromMouse(mouse.x);
            }
            onWheel: wheel => {
                var step = wheel.angleDelta.y > 0 ? 5 : -5;
                var val = Math.max(root.from, Math.min(root.to, root.value + step));
                root.moved(val);
            }
        }
    }

    // Right label with numeric value
    Text {
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "MUTE" : (root.value + root.suffix)
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: root.muted ? Theme.danger : Theme.textSecondary
    }
}
