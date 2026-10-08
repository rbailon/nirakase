// themes/Light.qml

import QtQuick

QtObject {
    id: root

    // Metadata
    readonly property string id: "light"
    readonly property string name: "Light"

    // Background & Surfaces
    readonly property color background: "#F2F2F7"
    readonly property color surface: "#FFFFFF"
    readonly property color surfaceHover: "#E5E5EA"
    readonly property color surfaceActive: "#D1D1D6"

    // Borders
    readonly property color border: "#D1D1D6"
    readonly property color borderHover: "#AEAEB2"

    // Typography
    readonly property color textPrimary: "#000000"
    readonly property color textSecondary: "#6C6C70"
    readonly property color textMuted: "#8E8E93"

    // Accent & Status Colors
    readonly property color accent: "#007AFF"
    readonly property color danger: "#FF3B30"
    readonly property color success: "#34C759"
    readonly property color warning: "#FF9500"

    // Badges / Special Elements
    readonly property color badgeFocusedBg: "#000000"
    readonly property color badgeFocusedText: "#FFFFFF"
}
