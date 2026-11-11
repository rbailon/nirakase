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

    // Tabs: 0 = Output & Apps, 1 = Input (Microphone)
    property int currentTab: 0

    spacing: 8

    // ================= AUDIO MIXER HEADER =================
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
            text: "Audio & Mixer"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        // Close button (󰅖)
        Text {
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: closeAudioMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

            MouseArea {
                id: closeAudioMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    // ================= MASTER VOLUME CONTROLS (OUTPUT & MIC) =================
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5

        SystemSlider {
            icon: AudioService.sinkIcon
            value: AudioService.volume
            muted: AudioService.isMuted
            iconClickable: true
            onMoved: val => AudioService.setVolume(val)
            onIconClicked: AudioService.toggleMute()
        }

        SystemSlider {
            visible: AudioService.hasSource
            icon: AudioService.micIcon
            value: AudioService.micVolume
            muted: AudioService.isMicMuted
            iconClickable: true
            onMoved: val => AudioService.setMicVolume(val)
            onIconClicked: AudioService.toggleMicMute()
        }
    }

    // ================= SELECTOR TABS (OUTPUT + APPS / INPUT) =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 7
            color: root.currentTab === 0 ? Theme.surfaceActive : (tab0Mouse.containsMouse ? Theme.surfaceHover : Theme.surface)
            border.color: root.currentTab === 0 ? Theme.accent : Theme.border
            border.width: root.currentTab === 0 ? 2 : 1

            Text {
                anchors.centerIn: parent
                text: "󰕾 Outputs & Apps (" + (AudioService.sinks.length + AudioService.appStreams.length) + ")"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: root.currentTab === 0 ? Font.Bold : Font.Medium
                color: root.currentTab === 0 ? Theme.textPrimary : Theme.textSecondary
            }

            MouseArea {
                id: tab0Mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentTab = 0
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 7
            color: root.currentTab === 1 ? Theme.surfaceActive : (tab1Mouse.containsMouse ? Theme.surfaceHover : Theme.surface)
            border.color: root.currentTab === 1 ? Theme.accent : Theme.border
            border.width: root.currentTab === 1 ? 2 : 1

            Text {
                anchors.centerIn: parent
                text: "󰍬 Microphones (" + AudioService.sources.length + ")"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: root.currentTab === 1 ? Font.Bold : Font.Medium
                color: root.currentTab === 1 ? Theme.textPrimary : Theme.textSecondary
            }

            MouseArea {
                id: tab1Mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentTab = 1
            }
        }
    }

    // ================= TAB 0: OUTPUT DEVICES + APP MIXER =================
    Flickable {
        id: tab0Flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        visible: root.currentTab === 0
        contentWidth: width
        contentHeight: tab0Col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: tab0Scroll
            active: true
            policy: ScrollBar.AsNeeded
            width: 6
            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: tab0Scroll.pressed ? Theme.accent : (tab0Scroll.hovered ? Theme.borderHover : Theme.border)
                opacity: tab0Scroll.active ? 0.8 : 0.4
            }
        }

        ColumnLayout {
            id: tab0Col
            width: tab0Flick.width - (tab0Scroll.visible ? 8 : 0)
            spacing: 6

            // Section: Output devices
            Text {
                text: "OUTPUT DEVICES"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.textMuted
            }

            Repeater {
                model: ScriptModel {
                    values: AudioService.sinks
                }

                delegate: Rectangle {
                    id: sinkCard
                    readonly property bool isDefault: AudioService.sink === modelData
                    readonly property int nodeVol: (modelData && modelData.audio && !isNaN(modelData.audio.volume))
                        ? Math.round(modelData.audio.volume * 100)
                        : 0

                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 8
                    color: isDefault ? Theme.surfaceActive : (sinkMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                    border.color: isDefault ? Theme.accent : Theme.border
                    border.width: isDefault ? 2 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: AudioService.nodeIcon(modelData)
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 14
                            color: sinkCard.isDefault ? Theme.accent : Theme.textSecondary
                        }

                        Text {
                            text: AudioService.nodeDisplayName(modelData, "Audio Output")
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 10
                            font.weight: sinkCard.isDefault ? Font.Bold : Font.DemiBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: sinkCard.isDefault
                            implicitWidth: actSinkLbl.implicitWidth + 8
                            implicitHeight: 16
                            radius: 4
                            color: Theme.background
                            border.color: Theme.accent
                            border.width: 1

                            Text {
                                id: actSinkLbl
                                anchors.centerIn: parent
                                text: "Active"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: Theme.accent
                            }
                        }

                        Text {
                            text: sinkCard.nodeVol + "%"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 9
                            color: Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AudioService.setDefaultSink(modelData)
                    }
                }
            }

            // Section: Active Application Streams
            Text {
                visible: AudioService.appStreams.length > 0
                Layout.topMargin: 4
                text: "APPLICATIONS PLAYING AUDIO"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Theme.textMuted
            }

            Repeater {
                model: ScriptModel {
                    values: AudioService.appStreams
                }

                delegate: Rectangle {
                    id: streamCard
                    readonly property int streamVol: (modelData && modelData.audio && !isNaN(modelData.audio.volume))
                        ? Math.max(0, Math.min(100, Math.round(modelData.audio.volume * 100)))
                        : 0
                    readonly property bool streamMuted: (modelData && modelData.audio) ? modelData.audio.muted : false
                    readonly property string subLabel: AudioService.streamSubLabel(modelData)

                    Layout.fillWidth: true
                    implicitHeight: streamCol.implicitHeight + 12
                    radius: 8
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    ColumnLayout {
                        id: streamCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: streamCard.streamMuted ? "󰝟" : "󰎆"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 12
                                color: streamCard.streamMuted ? Theme.danger : Theme.accent
                            }

                            Text {
                                text: AudioService.nodeDisplayName(modelData, "Application")
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: streamCard.subLabel !== ""
                                text: "· " + streamCard.subLabel
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 9
                                color: Theme.textMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        SystemSlider {
                            icon: streamCard.streamMuted ? "󰝟" : "󰕾"
                            value: streamCard.streamVol
                            muted: streamCard.streamMuted
                            iconClickable: true
                            onMoved: val => AudioService.setNodeVolume(modelData, val)
                            onIconClicked: AudioService.toggleNodeMute(modelData)
                        }
                    }
                }
            }
        }
    }

    // ================= TAB 1: INPUT DEVICES (MICROPHONES) =================
    ListView {
        id: sourceList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        visible: root.currentTab === 1
        model: ScriptModel {
            values: AudioService.sources
        }
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: sourceCard
            readonly property bool isDefault: AudioService.source === modelData
            readonly property int srcVol: (modelData && modelData.audio && !isNaN(modelData.audio.volume))
                ? Math.round(modelData.audio.volume * 100)
                : 0

            width: sourceList.width
            implicitHeight: 36
            radius: 8
            color: isDefault ? Theme.surfaceActive : (srcMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
            border.color: isDefault ? Theme.accent : Theme.border
            border.width: isDefault ? 2 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: AudioService.nodeIcon(modelData)
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 14
                    color: sourceCard.isDefault ? Theme.accent : Theme.textSecondary
                }

                Text {
                    text: AudioService.nodeDisplayName(modelData, "Microphone")
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: sourceCard.isDefault ? Font.Bold : Font.DemiBold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: sourceCard.isDefault
                    implicitWidth: actSrcLbl.implicitWidth + 8
                    implicitHeight: 16
                    radius: 4
                    color: Theme.background
                    border.color: Theme.accent
                    border.width: 1

                    Text {
                        id: actSrcLbl
                        anchors.centerIn: parent
                        text: "Active"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: Theme.accent
                    }
                }

                Text {
                    text: sourceCard.srcVol + "%"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    color: Theme.textSecondary
                }
            }

            MouseArea {
                id: srcMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioService.setDefaultSource(modelData)
            }
        }
    }
}
