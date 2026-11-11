import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."
import "../services"

ColumnLayout {
    id: root

    signal backRequested()
    signal closeRequested()

    spacing: 8

    readonly property var stageDefinitions: [
        {
            key: "dim",
            title: "Dim screen",
            subtitle: "Lowers brightness to minimum on inactivity",
            icon: "󰃞",
            currentValue: IdleService.dimTimeout,
            presets: [
                { label: "Never", value: 0 },
                { label: "1m", value: 60 },
                { label: "2m 30s", value: 150 },
                { label: "5m", value: 300 },
                { label: "10m", value: 600 }
            ]
        },
        {
            key: "lock",
            title: "Lock session",
            subtitle: "Locks the screen with swaylock",
            icon: "󰌾",
            currentValue: IdleService.lockTimeout,
            presets: [
                { label: "Never", value: 0 },
                { label: "2m", value: 120 },
                { label: "5m", value: 300 },
                { label: "10m", value: 600 },
                { label: "15m", value: 900 }
            ]
        },
        {
            key: "dpms",
            title: "Turn off monitors (DPMS)",
            subtitle: "Powers off display output via Niri",
            icon: "󰍹",
            currentValue: IdleService.dpmsTimeout,
            presets: [
                { label: "Never", value: 0 },
                { label: "3m", value: 180 },
                { label: "5m 30s", value: 330 },
                { label: "10m", value: 600 },
                { label: "20m", value: 1200 }
            ]
        },
        {
            key: "suspend",
            title: "Suspend system",
            subtitle: "Suspends to RAM after locking",
            icon: "󰤄",
            currentValue: IdleService.suspendTimeout,
            presets: [
                { label: "Never", value: 0 },
                { label: "10m", value: 600 },
                { label: "15m", value: 900 },
                { label: "30m", value: 1800 },
                { label: "1h", value: 3600 }
            ]
        }
    ]

    function applyStageTimeout(key, seconds) {
        if (key === "dim") IdleService.setDimTimeout(seconds);
        else if (key === "lock") IdleService.setLockTimeout(seconds);
        else if (key === "dpms") IdleService.setDpmsTimeout(seconds);
        else if (key === "suspend") IdleService.setSuspendTimeout(seconds);
    }

    // ================= IDLE PANEL HEADER =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Back button (󰁍)
        Rectangle {
            implicitWidth: backRow.implicitWidth + 12
            implicitHeight: 24
            radius: 6
            color: backMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: backMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            RowLayout {
                id: backRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "󰁍"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 12
                    color: Theme.textPrimary
                }

                Text {
                    text: "Back"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backRequested()
            }
        }

        Text {
            text: "Idle & Inactivity"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        // Restore defaults button
        Rectangle {
            implicitWidth: resetLbl.implicitWidth + 10
            implicitHeight: 22
            radius: 6
            color: resetMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: resetMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            Text {
                id: resetLbl
                anchors.centerIn: parent
                text: "󰑐 Defaults"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: resetMouse.containsMouse ? Theme.accent : Theme.textSecondary
            }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: IdleService.resetDefaults()
            }
        }

        // Close button (󰅖)
        Text {
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: closeIdleMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

            MouseArea {
                id: closeIdleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    // ================= CAFFEINE MODE STATUS CARD =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: 10
        color: IdleService.inhibited ? Theme.surfaceActive : Theme.surface
        border.color: IdleService.inhibited ? (Theme.warning || "#F59E0B") : Theme.border
        border.width: IdleService.inhibited ? 2 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: IdleService.icon
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 18
                color: IdleService.inhibited ? (Theme.warning || "#F59E0B") : Theme.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: IdleService.inhibited ? "Caffeine Mode active (Idle inhibited)" : "Automatic idle active (Native Wayland)"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: IdleService.inhibited ? (Theme.warning || "#F59E0B") : Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: IdleService.inhibited
                        ? "Screen will not dim, lock, or suspend automatically"
                        : "Respects video/audio inhibitors (Firefox, mpv, games)"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                implicitWidth: cafToggleLbl.implicitWidth + 14
                implicitHeight: 24
                radius: 6
                color: IdleService.inhibited
                    ? (Theme.warning || "#F59E0B")
                    : (cafToggleMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                border.color: IdleService.inhibited ? (Theme.warning || "#F59E0B") : Theme.border
                border.width: 1

                Text {
                    id: cafToggleLbl
                    anchors.centerIn: parent
                    text: IdleService.inhibited ? "Disable" : "Inhibit"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: IdleService.inhibited ? "#11111B" : Theme.textPrimary
                }

                MouseArea {
                    id: cafToggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: IdleService.toggleInhibit()
                }
            }
        }
    }

    // ================= STAGE TIMEOUT CONFIGURATION =================
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        Repeater {
            model: root.stageDefinitions

            delegate: Rectangle {
                id: stageCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 9
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                opacity: IdleService.inhibited ? 0.55 : 1.0

                readonly property var stage: modelData

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: stageCard.stage.icon
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 14
                            color: stageCard.stage.currentValue > 0 ? Theme.accent : Theme.textMuted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: stageCard.stage.title
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: stageCard.stage.subtitle
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 9
                                color: Theme.textMuted
                            }
                        }

                        Rectangle {
                            implicitWidth: curBadge.implicitWidth + 10
                            implicitHeight: 18
                            radius: 5
                            color: Theme.background
                            border.color: stageCard.stage.currentValue > 0 ? Theme.accent : Theme.border
                            border.width: 1

                            Text {
                                id: curBadge
                                anchors.centerIn: parent
                                text: IdleService.formatDuration(stageCard.stage.currentValue)
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: stageCard.stage.currentValue > 0 ? Theme.accent : Theme.textMuted
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: stageCard.stage.presets

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 24
                                radius: 6

                                readonly property bool selected: stageCard.stage.currentValue === modelData.value

                                color: selected
                                    ? Theme.surfaceActive
                                    : (presetMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                                border.color: selected
                                    ? Theme.accent
                                    : (presetMouse.containsMouse ? Theme.borderHover : Theme.border)
                                border.width: selected ? 2 : 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: "JetBrainsMono Nerd Font Propo"
                                    font.pixelSize: 9
                                    font.weight: selected ? Font.Bold : Font.Medium
                                    color: selected ? Theme.accent : Theme.textSecondary
                                }

                                MouseArea {
                                    id: presetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyStageTimeout(stageCard.stage.key, modelData.value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= IMMEDIATE ACTIONS =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 7
            color: lockNowMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: lockNowMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰌾"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 11
                    color: Theme.accent
                }

                Text {
                    text: "Lock now"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: lockNowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.closeRequested();
                    IdleService.lockNow();
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 7
            color: suspNowMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: suspNowMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰤄"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 11
                    color: Theme.accent
                }

                Text {
                    text: "Suspend now"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: suspNowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.closeRequested();
                    IdleService.suspendNow();
                }
            }
        }
    }
}
