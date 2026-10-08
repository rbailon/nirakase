// themes/EInkDark.qml

import QtQuick

QtObject {
    id: root

    // Metadata
    readonly property string id: "e-ink dark"
    readonly property string name: "E-ink dark"

    // Background & Surfaces (Stark black/dark ink)
    readonly property color background: "#0D0D0D"
    readonly property color surface: "#1A1A1A"
    readonly property color surfaceHover: "#2A2A2A"
    readonly property color surfaceActive: "#383838"

    // Borders (High-contrast ink outlines)
    readonly property color border: "#404040"
    readonly property color borderHover: "#707070"

    // Typography (Pure white & paper gray)
    readonly property color textPrimary: "#F0F0F0"
    readonly property color textSecondary: "#B0B0B0"
    readonly property color textMuted: "#666666"

    // Accent & Status Colors (Monochrome paper white accent)
    readonly property color accent: "#E6E6E6"
    readonly property color danger: "#D9534F"
    readonly property color success: "#5CB85C"
    readonly property color warning: "#F0AD4E"

    // Badges / Special Elements
    readonly property color badgeFocusedBg: "#FFFFFF"
    readonly property color badgeFocusedText: "#000000"
}
