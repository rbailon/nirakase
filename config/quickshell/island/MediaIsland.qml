import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import ".."
import "../components"
import "../services"

Item {
    id: root

    // Target height when collapsed synchronizes with the main Dynamic Island
    property real targetHeight: 34

    // Small inner padding creating a border bezel in Theme.background around the cover art
    property int innerPadding: 3

    // Expansion state
    property bool expanded: false

    // Media Island is active only when an MPRIS player is active
    readonly property bool active: MediaService.hasPlayer

    // Collapse immediately if player becomes inactive/closes
    onActiveChanged: {
        if (!active) {
            root.expanded = false;
        }
    }

    // Geometry: circle when collapsed, rich card when expanded
    implicitHeight: expanded ? 84 : targetHeight
    implicitWidth: expanded ? 320 : targetHeight
    width: implicitWidth
    height: implicitHeight

    // Appearance / Disappearance animation towards its own center
    transformOrigin: Item.Center
    scale: active ? 1.0 : 0.0
    opacity: active ? 1.0 : 0.0
    visible: active || opacity > 0.001 || scale > 0.001

    Behavior on scale {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: 240
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: 240
            easing.type: Easing.InOutCubic
        }
    }

    // Timer to expand into card mode on hover with slight debounce
    Timer {
        id: expandTimer
        interval: 120
        repeat: false
        onTriggered: {
            if ((pillHover.hovered || (collapsedMouseArea && collapsedMouseArea.containsMouse)) && !root.expanded) {
                root.expanded = true;
            }
        }
    }

    // Timer to collapse back to circle mode when cursor leaves the expanded DIM
    Timer {
        id: collapseTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!pillHover.hovered && !(collapsedMouseArea && collapsedMouseArea.containsMouse) && root.expanded) {
                root.expanded = false;
            }
        }
    }

    // Main pill body (retains Theme.background matching the main Dynamic Island)
    Rectangle {
        id: pillBody
        anchors.fill: parent
        radius: root.expanded ? 16 : (root.targetHeight / 2)
        clip: true
        color: Theme.background
        border.color: pillHover.hovered ? Theme.borderHover : Theme.border
        border.width: 1

        Behavior on radius {
            NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        // Seamless hover tracking across the entire pill
        HoverHandler {
            id: pillHover
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                    if (!root.expanded) {
                        expandTimer.restart();
                    }
                } else {
                    expandTimer.stop();
                    if (root.expanded) {
                        collapseTimer.restart();
                    }
                }
            }
        }

        // Right-click anywhere on the pill toggles expand/collapse
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: {
                root.expanded = !root.expanded;
            }
        }

        // Mask item to clip the background to pillBody's rounded corners
        Item {
            id: bgCardMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                radius: pillBody.radius
                color: "black"
                antialiasing: true
            }
        }

        // Blurred Album Art Background (visible only when expanded and artwork is available)
        Item {
            id: bgBlurContainer
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: (root.expanded && MediaService.trackArtUrl !== "") ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bgCardMask
            }

            Image {
                id: bgArtImage
                anchors.fill: parent
                source: MediaService.trackArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.85
                    blurMax: 32
                }
            }

            // Theme-adaptive tint overlay: ensures contrast for both light and dark themes
            Rectangle {
                anchors.fill: parent
                color: Theme.background
                opacity: 0.78
            }
        }

        // ==========================================
        // 1. COLLAPSED VIEW: Circular Cover Art Mode
        // ==========================================
        Item {
            id: collapsedView
            anchors.centerIn: parent
            width: root.targetHeight
            height: root.targetHeight

            visible: opacity > 0.01
            opacity: root.expanded ? 0.0 : 1.0
            scale: root.expanded ? 0.75 : 1.0
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
            Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

            // Tactile scale feedback when pressed
            Item {
                anchors.fill: parent
                scale: collapsedMouseArea.pressed ? 0.92 : 1.0
                transformOrigin: Item.Center

                Behavior on scale {
                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }

                // Inner circle container holding the cover art with margin/padding
                Item {
                    id: innerContainer
                    anchors.fill: parent
                    anchors.margins: root.innerPadding
                    clip: true

                    // Circular mask for album art clipping
                    Item {
                        id: maskCircle
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "black"
                        }
                    }

                    // Fallback visual when album art is unavailable or loading
                    Rectangle {
                        id: fallbackContainer
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.surface
                        visible: !artImage.visible

                        Text {
                            anchors.centerIn: parent
                            text: "󰎆"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: Math.round(parent.height * 0.44)
                            color: MediaService.isPlaying ? Theme.accent : Theme.textSecondary

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    // Album Art Image
                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: MediaService.trackArtUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready && source !== ""

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: maskCircle
                        }
                    }

                    // Crisp inner border overlay around the album art circle
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.rgba(255, 255, 255, 0.12)
                        border.width: 1
                        z: 5
                    }
                }
            }

            // Mouse interaction for the collapsed circle
            MouseArea {
                id: collapsedMouseArea
                anchors.fill: parent
                enabled: !root.expanded
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onEntered: {
                    collapseTimer.stop();
                    if (!root.expanded) {
                        expandTimer.restart();
                    }
                }

                onExited: {
                    if (!pillHover.hovered) {
                        expandTimer.stop();
                        if (root.expanded) {
                            collapseTimer.restart();
                        }
                    }
                }

                onClicked: mouse => {
                    expandTimer.stop();
                    root.expanded = true;
                }
            }
        }

        // ==========================================
        // 2. EXPANDED VIEW: Rich Media Controller
        // ==========================================
        Item {
            id: expandedView
            anchors.fill: parent
            anchors.margins: 10

            visible: opacity > 0.01
            opacity: root.expanded ? 1.0 : 0.0
            scale: root.expanded ? 1.0 : 0.85
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
            Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                // --- TOP ROW: Artwork + Title/Artist + Controls ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // 1. Artwork Thumbnail (clickable to play/pause only when expanded)
                    Item {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        clip: true
                        scale: (artThumbMouse.pressed && root.expanded) ? 0.94 : 1.0
                        transformOrigin: Item.Center

                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                        Item {
                            id: expArtMask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "black"
                            }
                        }

                        Rectangle {
                            id: expFallback
                            anchors.fill: parent
                            radius: 8
                            color: Theme.surface
                            visible: !expArtImage.visible

                            Text {
                                anchors.centerIn: parent
                                text: "󰎆"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 18
                                color: MediaService.isPlaying ? Theme.accent : Theme.textSecondary
                            }
                        }

                        Image {
                            id: expArtImage
                            anchors.fill: parent
                            source: MediaService.trackArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready && source !== ""

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: expArtMask
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: "transparent"
                            border.color: Qt.rgba(255, 255, 255, 0.12)
                            border.width: 1
                            z: 4
                        }

                        // Light hover overlay on thumbnail (active only when expanded)
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.25)
                            opacity: (artThumbMouse.containsMouse && root.expanded) ? 1.0 : 0.0
                            z: 5

                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: MediaService.isPlaying ? "󰏤" : "󰐊"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 15
                                color: "#FFFFFF"
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.45)
                            }
                        }

                        MouseArea {
                            id: artThumbMouse
                            anchors.fill: parent
                            enabled: root.expanded
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MediaService.togglePlaying()
                        }
                    }

                    // 2. Track Title and Artist Details
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: MediaService.trackTitle !== "" ? MediaService.trackTitle : "Not playing"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: MediaService.trackArtist !== "" ? MediaService.trackArtist : (MediaService.identity !== "" ? MediaService.identity : "Unknown")
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 10
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // 3. Playback Controls (Previous, Play/Pause, Next)
                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        // Previous Track Button
                        Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 6
                            color: prevMouse.pressed ? "#35ffffff" : (prevMouse.containsMouse ? Theme.surfaceHover : "transparent")
                            scale: prevMouse.pressed ? 0.88 : 1.0
                            transformOrigin: Item.Center

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 13
                                color: MediaService.canGoPrevious ? Theme.textPrimary : Theme.textMuted
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: MediaService.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: MediaService.previous()
                            }
                        }

                        // Play / Pause Button
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: playMouse.pressed ? Qt.darker(Theme.accent, 1.2) : (playMouse.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                            scale: playMouse.pressed ? 0.88 : 1.0
                            transformOrigin: Item.Center

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: MediaService.isPlaying ? "󰏤" : "󰐊"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 13
                                color: Theme.badgeFocusedText || "#FFFFFF"
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MediaService.togglePlaying()
                            }
                        }

                        // Next Track Button
                        Rectangle {
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 6
                            color: nextMouse.pressed ? "#35ffffff" : (nextMouse.containsMouse ? Theme.surfaceHover : "transparent")
                            scale: nextMouse.pressed ? 0.88 : 1.0
                            transformOrigin: Item.Center

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 13
                                color: MediaService.canGoNext ? Theme.textPrimary : Theme.textMuted
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: MediaService.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: MediaService.next()
                            }
                        }
                    }
                }

                // --- BOTTOM ROW: Playback Timeline & Progress Bar ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // Current Position Text
                    Text {
                        text: MediaService.formatTime(MediaService.position)
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 9
                        color: Theme.textMuted
                        Layout.preferredWidth: 32
                        horizontalAlignment: Text.AlignRight
                    }

                    // Interactive Progress Slider Bar
                    Item {
                        id: progressContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12

                        // Track Background
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4
                            radius: 2
                            color: Theme.surfaceHover

                            // Filled Progress
                            Rectangle {
                                id: progressFill
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.min(parent.width, Math.max(0, parent.width * (MediaService.length > 0 ? (MediaService.position / MediaService.length) : 0)))
                                radius: 2
                                color: Theme.accent

                                Behavior on width {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }
                            }

                            // Scrubber Handle (visible when hovering or dragging)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - 8, progressFill.width - 4))
                                width: 8
                                height: 8
                                radius: 4
                                color: Theme.accent
                                border.color: "#FFFFFF"
                                border.width: 1
                                visible: progressMouse.containsMouse || progressMouse.pressed
                            }
                        }

                        // MouseArea for seeking along the timeline
                        MouseArea {
                            id: progressMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: mouse => {
                                if (MediaService.length > 0) {
                                    var pct = Math.max(0, Math.min(1.0, mouse.x / width));
                                    MediaService.setPosition(pct * MediaService.length);
                                }
                            }

                            onPositionChanged: mouse => {
                                if (pressed && MediaService.length > 0) {
                                    var pct = Math.max(0, Math.min(1.0, mouse.x / width));
                                    MediaService.setPosition(pct * MediaService.length);
                                }
                            }
                        }
                    }

                    // Total Length Text
                    Text {
                        text: MediaService.length > 0 ? MediaService.formatTime(MediaService.length) : "--:--"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 9
                        color: Theme.textMuted
                        Layout.preferredWidth: 32
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }
        }

        // Crisp outer border overlay matching the pill's rounded corners
        Rectangle {
            anchors.fill: parent
            radius: pillBody.radius
            color: "transparent"
            border.color: pillHover.hovered ? Theme.borderHover : Theme.border
            border.width: 1
            z: 20

            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }
        }
    }
}
