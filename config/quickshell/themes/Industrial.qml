// themes/Industrial.qml

import QtQuick

QtObject {
    id: root

    // Metadata
    readonly property string id: "industrial"
    readonly property string name: "Industrial"

    // Background & Surfaces (Steel slate & dark concrete)
    readonly property color background: "#181A1B"
    readonly property color surface: "#222527"
    readonly property color surfaceHover: "#2D3135"
    readonly property color surfaceActive: "#3A3F44"

    // Borders (Concrete & metallic edges)
    readonly property color border: "#353A3E"
    readonly property color borderHover: "#525A60"

    // Typography (Steel white & warm gray)
    readonly property color textPrimary: "#ECEFF1"
    readonly property color textSecondary: "#90A4AE"
    readonly property color textMuted: "#546E7A"

    // Accent & Status Colors (Industrial safety amber/orange)
    readonly property color accent: "#F59E0B"
    readonly property color danger: "#EF4444"
    readonly property color success: "#10B981"
    readonly property color warning: "#F59E0B"

    // Badges / Special Elements
    readonly property color badgeFocusedBg: "#F59E0B"
    readonly property color badgeFocusedText: "#181A1B"
}
