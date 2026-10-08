// themes/Horizon.qml

import QtQuick

QtObject {
    id: root

    // Metadata
    readonly property string id: "horizon"
    readonly property string name: "Horizon"

    // Background & Surfaces (Deep twilight purple & warm midnight)
    readonly property color background: "#1C1E26"
    readonly property color surface: "#232530"
    readonly property color surfaceHover: "#2E303E"
    readonly property color surfaceActive: "#3B3E50"

    // Borders (Sunset purple/magenta borders)
    readonly property color border: "#2E303E"
    readonly property color borderHover: "#4A4D63"

    // Typography (Soft warm light & lavender)
    readonly property color textPrimary: "#FDFDFD"
    readonly property color textSecondary: "#C7C9D3"
    readonly property color textMuted: "#6C6F93"

    // Accent & Status Colors (Horizon coral / warm neon orange)
    readonly property color accent: "#E95678"
    readonly property color danger: "#E95678"
    readonly property color success: "#25B0BC"
    readonly property color warning: "#FAB795"

    // Badges / Special Elements
    readonly property color badgeFocusedBg: "#E95678"
    readonly property color badgeFocusedText: "#1C1E26"
}
