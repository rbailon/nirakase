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

    spacing: 7

    readonly property var layoutModesTop: [
        { id: "extend-left",  label: "Left",   icon: "󰁍", desc: "Secondary on left" },
        { id: "extend-right", label: "Right",  icon: "󰁔", desc: "Secondary on right" },
        { id: "extend-above", label: "Above",  icon: "󰁝", desc: "Secondary above" },
        { id: "extend-below", label: "Below",  icon: "󰁅", desc: "Secondary below" }
    ]

    readonly property var layoutModesBottom: [
        { id: "mirror",         label: "Clone / Mirror", icon: "󰍸", desc: "Duplicate primary" },
        { id: "primary-only",   label: "Primary Only",   icon: "󰌢", desc: "Disable secondary" },
        { id: "secondary-only", label: "External Only",  icon: "󰍹", desc: "Disable primary" }
    ]

    readonly property var scalePresets: [
        { label: "100%", value: 1.0 },
        { label: "125%", value: 1.25 },
        { label: "150%", value: 1.5 },
        { label: "175%", value: 1.75 },
        { label: "200%", value: 2.0 }
    ]

    readonly property var transformPresets: [
        { label: "0°",   value: "normal" },
        { label: "90°",  value: "90" },
        { label: "180°", value: "180" },
        { label: "270°", value: "270" }
    ]

    onVisibleChanged: {
        if (visible) {
            DisplayService.refresh();
        }
    }

    // ================= HEADER =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

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
            text: "Monitors & Layout"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        // Save to outputs.kdl button
        Rectangle {
            implicitWidth: saveKdlLbl.implicitWidth + 10
            implicitHeight: 22
            radius: 6
            color: saveKdlMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: saveKdlMouse.containsMouse ? Theme.accent : Theme.border
            border.width: 1

            Text {
                id: saveKdlLbl
                anchors.centerIn: parent
                text: "󰆓 Save KDL"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: saveKdlMouse.containsMouse ? Theme.accent : Theme.textSecondary
            }

            MouseArea {
                id: saveKdlMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DisplayService.saveToNiriConfig()
            }
        }

        // Refresh outputs button
        Rectangle {
            implicitWidth: 22
            implicitHeight: 22
            radius: 6
            color: refreshMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: refreshMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "󰑐"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: refreshMouse.containsMouse ? Theme.accent : Theme.textSecondary
            }

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DisplayService.refresh()
            }
        }

        // Close button (󰅖)
        Text {
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: closeDispMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

            MouseArea {
                id: closeDispMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    // ================= VISUAL MONITOR MAP / PREVIEW =================
    Rectangle {
        id: mapCanvas
        Layout.fillWidth: true
        implicitHeight: 92
        radius: 10
        color: Theme.surface
        border.color: DisplayService.statusFeedback !== "" ? Theme.accent : Theme.border
        border.width: 1
        clip: true

        // Compute bounding box of enabled outputs for proportional rendering
        readonly property var bounds: {
            var outs = DisplayService.outputs;
            if (!outs || outs.length === 0) return { minX: 0, minY: 0, totalW: 1920, totalH: 1080 };
            var minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
            var anyEnabled = false;
            for (var i = 0; i < outs.length; i++) {
                var o = outs[i];
                if (!o.enabled) continue;
                anyEnabled = true;
                if (o.x < minX) minX = o.x;
                if (o.y < minY) minY = o.y;
                if (o.x + o.width > maxX) maxX = o.x + o.width;
                if (o.y + o.height > maxY) maxY = o.y + o.height;
            }
            if (!anyEnabled) return { minX: 0, minY: 0, totalW: 1920, totalH: 1080 };
            return {
                minX: minX,
                minY: minY,
                totalW: Math.max(640, maxX - minX),
                totalH: Math.max(480, maxY - minY)
            };
        }

        readonly property real availW: Math.max(120, width - 24)
        readonly property real availH: Math.max(48, height - 26)
        readonly property real mapScale: Math.min(availW / bounds.totalW, availH / bounds.totalH) * 0.88

        // Top-left label
        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 7
            text: DisplayService.statusFeedback !== ""
                ? ("✔ " + DisplayService.statusFeedback)
                : ("Layout: " + DisplayService.modeLabel)
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            color: DisplayService.statusFeedback !== "" ? Theme.accent : Theme.textMuted
        }

        // Swap primary/secondary button when 2+ monitors exist
        Rectangle {
            visible: DisplayService.hasMultipleMonitors
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 5
            implicitWidth: swapRow.implicitWidth + 10
            implicitHeight: 18
            radius: 5
            color: swapMouse.containsMouse ? Theme.surfaceHover : Theme.background
            border.color: swapMouse.containsMouse ? Theme.accent : Theme.border
            border.width: 1
            z: 5

            RowLayout {
                id: swapRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "󰓡 Swap Primary"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    color: swapMouse.containsMouse ? Theme.accent : Theme.textSecondary
                }
            }

            MouseArea {
                id: swapMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DisplayService.swapPrimarySecondary()
            }
        }

        // Proportional monitor rectangles
        Item {
            id: stageArea
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 6

            Repeater {
                model: DisplayService.outputs

                delegate: Rectangle {
                    id: monBox
                    readonly property var out: modelData
                    readonly property bool isPrimary: out.name === DisplayService.primaryOutputName
                    readonly property real drawW: Math.max(54, out.width * mapCanvas.mapScale)
                    readonly property real drawH: Math.max(32, out.height * mapCanvas.mapScale)
                    readonly property real groupW: mapCanvas.bounds.totalW * mapCanvas.mapScale
                    readonly property real groupH: mapCanvas.bounds.totalH * mapCanvas.mapScale
                    readonly property real originX: (stageArea.width - groupW) / 2
                    readonly property real originY: (stageArea.height - groupH) / 2

                    width: drawW
                    height: drawH
                    x: {
                        if (DisplayService.isMirroring) {
                            return (stageArea.width - drawW) / 2 + (isPrimary ? -6 : 6);
                        }
                        if (!out.enabled) {
                            return stageArea.width - drawW - 10;
                        }
                        return originX + (out.x - mapCanvas.bounds.minX) * mapCanvas.mapScale;
                    }
                    y: {
                        if (DisplayService.isMirroring) {
                            return (stageArea.height - drawH) / 2 + (isPrimary ? -4 : 4);
                        }
                        if (!out.enabled) {
                            return (stageArea.height - drawH) / 2;
                        }
                        return originY + (out.y - mapCanvas.bounds.minY) * mapCanvas.mapScale;
                    }

                    radius: 6
                    color: !out.enabled
                        ? Theme.background
                        : (isPrimary ? Theme.surfaceActive : Theme.background)
                    border.color: !out.enabled
                        ? Theme.border
                        : (isPrimary ? Theme.accent : (Theme.success || "#10B981"))
                    border.width: isPrimary ? 2 : 1
                    opacity: out.enabled ? 1.0 : 0.45

                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (monBox.isPrimary ? "★ " : "") + monBox.out.name
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: monBox.out.enabled ? Theme.textPrimary : Theme.textMuted
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: monBox.out.enabled
                                ? (monBox.out.width + "×" + monBox.out.height)
                                : "OFF"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            color: monBox.out.enabled ? Theme.textSecondary : Theme.danger
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DisplayService.setPrimaryOutput(monBox.out.name)
                    }
                }
            }
        }
    }

    // ================= MULTI-MONITOR QUICK ACTIONS =================
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        visible: DisplayService.hasMultipleMonitors

        // Row 1: Join / Extend Position (Left, Right, Above, Below)
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: root.layoutModesTop

                delegate: Rectangle {
                    id: extBtn
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 7

                    readonly property bool isCurrent: DisplayService.currentLayoutMode === modelData.id

                    color: isCurrent
                        ? Theme.surfaceActive
                        : (extMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                    border.color: isCurrent
                        ? Theme.accent
                        : (extMouse.containsMouse ? Theme.borderHover : Theme.border)
                    border.width: isCurrent ? 2 : 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: modelData.icon
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 12
                            color: extBtn.isCurrent ? Theme.accent : Theme.textSecondary
                        }

                        Text {
                            text: modelData.label
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 9
                            font.weight: extBtn.isCurrent ? Font.Bold : Font.DemiBold
                            color: extBtn.isCurrent ? Theme.textPrimary : Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: extMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DisplayService.applyLayout(modelData.id)
                    }
                }
            }
        }

        // Row 2: Clone / Mirror & Single Monitor modes
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: root.layoutModesBottom

                delegate: Rectangle {
                    id: modeBtn
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 7

                    readonly property bool isCurrent: DisplayService.currentLayoutMode === modelData.id

                    color: isCurrent
                        ? Theme.surfaceActive
                        : (modeMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                    border.color: isCurrent
                        ? (modelData.id === "mirror" ? (Theme.warning || "#F59E0B") : Theme.accent)
                        : (modeMouse.containsMouse ? Theme.borderHover : Theme.border)
                    border.width: isCurrent ? 2 : 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: modelData.icon
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 11
                            color: modeBtn.isCurrent
                                ? (modelData.id === "mirror" ? (Theme.warning || "#F59E0B") : Theme.accent)
                                : Theme.textSecondary
                        }

                        Text {
                            text: modelData.label
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 9
                            font.weight: modeBtn.isCurrent ? Font.Bold : Font.DemiBold
                            color: modeBtn.isCurrent ? Theme.textPrimary : Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DisplayService.applyLayout(modelData.id)
                    }
                }
            }
        }
    }

    // Single-monitor informational banner when only 1 output is connected
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 8
        visible: !DisplayService.hasMultipleMonitors
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
                text: "󰍹"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 13
                color: Theme.accent
            }

            Text {
                text: "Single monitor connected · Connect another display to extend or clone"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                color: Theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // ================= PER-MONITOR CONFIGURATION LIST =================
    ListView {
        id: outputsList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 7
        model: DisplayService.outputs
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: outScroll
            active: true
            policy: ScrollBar.AsNeeded
            width: 5

            contentItem: Rectangle {
                implicitWidth: 5
                radius: 2.5
                color: outScroll.pressed ? Theme.accent : Theme.border
                opacity: 0.7
            }
        }

        delegate: Rectangle {
            id: outCard
            width: outputsList.width - (outScroll.visible ? 7 : 0)
            implicitHeight: cardCol.implicitHeight + 16
            radius: 9
            color: Theme.surface
            border.color: isPrimary ? Theme.accent : Theme.border
            border.width: isPrimary ? 1.5 : 1

            readonly property var output: modelData
            readonly property bool isPrimary: output.name === DisplayService.primaryOutputName

            ColumnLayout {
                id: cardCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Top row: Icon + Name + Make/Model + Primary button + On/Off toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        text: outCard.output.isInternal ? "󰌢" : "󰍹"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 15
                        color: outCard.output.enabled ? Theme.accent : Theme.textMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            spacing: 6

                            Text {
                                text: outCard.output.name
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: outCard.output.makeModel
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 9
                                color: Theme.textMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: outCard.output.enabled
                                ? ("Logical: " + outCard.output.width + "×" + outCard.output.height +
                                   " · Pos: (" + outCard.output.x + ", " + outCard.output.y + ") · " + outCard.output.refreshRate)
                                : "Output disabled (off)"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            color: outCard.output.enabled ? Theme.textSecondary : Theme.danger
                        }
                    }

                    // Set as Primary badge/button
                    Rectangle {
                        visible: DisplayService.hasMultipleMonitors
                        implicitWidth: primLbl.implicitWidth + 10
                        implicitHeight: 20
                        radius: 5
                        color: outCard.isPrimary
                            ? Theme.accent
                            : (primMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                        border.color: outCard.isPrimary ? Theme.accent : Theme.border
                        border.width: 1

                        Text {
                            id: primLbl
                            anchors.centerIn: parent
                            text: outCard.isPrimary ? "★ Primary" : "Set Primary"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: outCard.isPrimary ? (Theme.badgeFocusedText || "#11111B") : Theme.textSecondary
                        }

                        MouseArea {
                            id: primMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DisplayService.setPrimaryOutput(outCard.output.name)
                        }
                    }

                    // Enable / Disable output toggle
                    Rectangle {
                        visible: DisplayService.hasMultipleMonitors
                        implicitWidth: enLbl.implicitWidth + 12
                        implicitHeight: 20
                        radius: 5
                        color: outCard.output.enabled
                            ? (enMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                            : (Theme.success || Theme.accent)
                        border.color: outCard.output.enabled ? Theme.border : (Theme.success || Theme.accent)
                        border.width: 1
                        opacity: (outCard.output.enabled && DisplayService.activeOutputCount <= 1) ? 0.4 : 1.0

                        Text {
                            id: enLbl
                            anchors.centerIn: parent
                            text: outCard.output.enabled ? "Turn Off" : "Turn On"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: outCard.output.enabled ? Theme.textSecondary : "#11111B"
                        }

                        MouseArea {
                            id: enMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DisplayService.setOutputEnabled(outCard.output.name, !outCard.output.enabled)
                        }
                    }
                }

                // Scale & Rotation Row (visible when output is enabled)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: outCard.output.enabled

                    Text {
                        text: "Scale:"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        color: Theme.textMuted
                    }

                    Repeater {
                        model: root.scalePresets

                        delegate: Rectangle {
                            implicitWidth: scLbl.implicitWidth + 8
                            implicitHeight: 18
                            radius: 4

                            readonly property bool selected: Math.abs(outCard.output.scale - modelData.value) < 0.05

                            color: selected ? Theme.accent : (scMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                            border.color: selected ? Theme.accent : Theme.border
                            border.width: 1

                            Text {
                                id: scLbl
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 8
                                font.weight: selected ? Font.Bold : Font.Normal
                                color: selected ? (Theme.badgeFocusedText || "#11111B") : Theme.textSecondary
                            }

                            MouseArea {
                                id: scMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DisplayService.setOutputScale(outCard.output.name, modelData.value)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Rot:"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        color: Theme.textMuted
                    }

                    Repeater {
                        model: root.transformPresets

                        delegate: Rectangle {
                            implicitWidth: trLbl.implicitWidth + 7
                            implicitHeight: 18
                            radius: 4

                            readonly property bool selected: outCard.output.transform === modelData.value

                            color: selected ? Theme.accent : (trMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                            border.color: selected ? Theme.accent : Theme.border
                            border.width: 1

                            Text {
                                id: trLbl
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 8
                                font.weight: selected ? Font.Bold : Font.Normal
                                color: selected ? (Theme.badgeFocusedText || "#11111B") : Theme.textSecondary
                            }

                            MouseArea {
                                id: trMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DisplayService.setOutputTransform(outCard.output.name, modelData.value)
                            }
                        }
                    }
                }

                // Resolution & Refresh Rate pills (top 4 modes)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: outCard.output.enabled && outCard.output.modes && outCard.output.modes.length > 1

                    Text {
                        text: "Mode:"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        color: Theme.textMuted
                    }

                    Repeater {
                        model: outCard.output.modes ? outCard.output.modes.slice(0, 4) : []

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 18
                            radius: 4

                            readonly property bool selected: !!modelData.isCurrent

                            color: selected ? Theme.surfaceActive : (mdMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                            border.color: selected ? Theme.accent : Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.width + "×" + modelData.height + "@" + modelData.refreshHz
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 7
                                font.weight: selected ? Font.Bold : Font.Normal
                                color: selected ? Theme.accent : Theme.textSecondary
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: mdMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DisplayService.setOutputMode(outCard.output.name, modelData.cmd)
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= FOOTER: HOTPLUG PROMPT SETTING =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 8
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 6

            Text {
                text: "🔌"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                color: DisplayService.autoPromptOnHotplug ? Theme.accent : Theme.textMuted
            }

            Text {
                text: "Open this panel automatically when plugging in a monitor"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                color: Theme.textSecondary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                implicitWidth: hpToggleLbl.implicitWidth + 10
                implicitHeight: 18
                radius: 5
                color: DisplayService.autoPromptOnHotplug ? Theme.accent : Theme.background
                border.color: DisplayService.autoPromptOnHotplug ? Theme.accent : Theme.border
                border.width: 1

                Text {
                    id: hpToggleLbl
                    anchors.centerIn: parent
                    text: DisplayService.autoPromptOnHotplug ? "ON" : "OFF"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    color: DisplayService.autoPromptOnHotplug ? (Theme.badgeFocusedText || "#11111B") : Theme.textMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DisplayService.setAutoPromptOnHotplug(!DisplayService.autoPromptOnHotplug)
                }
            }
        }
    }
}
