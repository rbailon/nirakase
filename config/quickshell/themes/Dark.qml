// themes/Dark.qml

import QtQuick

QtObject {
    id: root

    // Metadata
    readonly property string id: "dark"
    readonly property string name: "Dark"

    // Background & Surfaces
    readonly property color background: "#0F0F11"
    readonly property color surface: "#1A1A1E"
    readonly property color surfaceHover: "#2C2C2E"
    readonly property color surfaceActive: "#3A3A3C"

    // Borders
    readonly property color border: "#2C2C2E"
    readonly property color borderHover: "#45454A"

    // Typography
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#A0A0A5"
    readonly property color textMuted: "#4A4A4E"

    // Accent & Status Colors
    readonly property color accent: "#007AFF"
    readonly property color danger: "#E03838"
    readonly property color success: "#34C759"
    readonly property color warning: "#FF9500"

    // Badges / Special Elements
    readonly property color badgeFocusedBg: "#FFFFFF"
    readonly property color badgeFocusedText: "#000000"
}
