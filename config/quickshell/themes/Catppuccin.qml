// themes/Catppuccin.qml

import QtQuick

QtObject {
    id: root

    // Metadata
    readonly property string id: "catppuccin"
    readonly property string name: "Catppuccin"
    readonly property bool isDark: true

    // Background & Surfaces
    readonly property color background: "#1e1e2e"
    readonly property color surface: "#181825"
    readonly property color surfaceHover: "#313244"
    readonly property color surfaceActive: "#45475a"

    // Borders
    readonly property color border: "#313244"
    readonly property color borderHover: "#585b70"

    // Typography
    readonly property color textPrimary: "#cdd6f4"
    readonly property color textSecondary: "#a6adc8"
    readonly property color textMuted: "#6c7086"

    // Accent & Status Colors
    readonly property color accent: "#89b4fa"
    readonly property color danger: "#f38ba8"
    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"

    // Badges / Special Elements
    readonly property color badgeFocusedBg: "#89b4fa"
    readonly property color badgeFocusedText: "#11111b"
}
