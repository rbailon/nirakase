import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"
import ".."

Item {
    id: root

    signal clicked()

    readonly property bool hasBattery: PowerService.hasBattery
    readonly property int percentage: PowerService.percentage
    readonly property bool isCharging: PowerService.isCharging
    readonly property string statusText: PowerService.statusText

    readonly property color fillColor: percentage < 20 ? Theme.danger : (percentage < 40 ? Theme.warning : Theme.textSecondary)

    readonly property color profileColor: {
        if (PowerService.currentProfileId === "power-saver") return Theme.success || "#10B981";
        if (PowerService.currentProfileId === "performance") return Theme.danger || "#EF4444";
        return Theme.accent || "#3B82F6";
    }

    readonly property string tooltipText: {
        if (!hasBattery) return "";
        var lines = [];
        var iconHdr = isCharging ? "⚡ " : "󰁹 ";
        lines.push(`${iconHdr}${statusText} (${percentage}%)`);

        if (PowerService.timeRemainingText !== "") {
            lines.push(`󰥔 ${PowerService.timeRemainingText}`);
        }

        var techParts = [];
        if (PowerService.changeRateText !== "") techParts.push(PowerService.changeRateText);
        if (PowerService.energyText !== "") techParts.push(PowerService.energyText);
        if (PowerService.healthPct > 0) techParts.push(`Health: ${PowerService.healthPct}%`);
        if (techParts.length > 0) {
            lines.push(techParts.join(" · "));
        }

        var pwrLine = `󰗑 Profile: ${PowerService.currentProfileName}`;
        if (PowerService.degradationText !== "") {
            pwrLine += ` (${PowerService.degradationText})`;
        }
        lines.push(pwrLine);

        // Wireless peripheral batteries reported by UPower (e.g. HID++ mouse/keyboard)
        var periphs = PowerService.peripheralDevices;
        if (periphs && periphs.length > 0) {
            for (var i = 0; i < periphs.length; i++) {
                var p = periphs[i];
                if (!p) continue;
                var pPct = PowerService.normalizePercentage(p.percentage);
                var pIcon = PowerService.peripheralIcon(p);
                var pName = p.model || "Peripheral";
                lines.push(`${pIcon} ${pName}: ${pPct}%`);
            }
        }

        return lines.join("\n");
    }

    implicitWidth: visible ? batRow.implicitWidth : 0
    implicitHeight: visible ? batRow.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight
    visible: hasBattery

    Timer {
        id: tooltipTimer
        interval: 350
        running: false
        repeat: false
        onTriggered: {
            if (batMouse.containsMouse && root.tooltipText !== "") {
                tooltipWindow.visible = true;
            }
        }
    }

    PopupWindow {
        id: tooltipWindow
        anchor.item: batRow
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        visible: false
        color: "transparent"

        implicitWidth: tooltipBubble.implicitWidth + 8
        implicitHeight: tooltipBubble.implicitHeight + 8

        Rectangle {
            id: tooltipBubble
            anchors.centerIn: parent
            implicitWidth: tooltipTxt.implicitWidth + 16
            implicitHeight: tooltipTxt.implicitHeight + 10
            color: Theme.surface ? Theme.surface : "#18181B"
            border.color: Theme.surfaceActive ? Theme.surfaceActive : "#3F3F46"
            border.width: 1
            radius: 6

            Text {
                id: tooltipTxt
                anchors.centerIn: parent
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: Theme.textPrimary ? Theme.textPrimary : "#F4F4F5"
                text: root.tooltipText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Row {
        id: batRow
        spacing: 5
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        // Active power profile icon (󰌪 Power Saver / 󰗑 Balanced / 󰓅 Performance)
        Text {
            id: profileIconText
            text: PowerService.currentProfileIcon
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 12
            color: root.profileColor
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color {
                ColorAnimation { duration: 180 }
            }
        }
        
        // Battery body icon (narrower)
        Item {
            id: batContainer
            width: batFrame.width + 2.5
            height: 11
            anchors.verticalCenter: parent.verticalCenter

            // Battery body (Gray)
            Rectangle {
                id: batFrame
                width: 20
                height: 11
                radius: 3
                color: "transparent"
                border.color: Theme.textSecondary
                border.width: 1

                // Inner level bar (Orange <40%, Red <20%, Blinking Red <15%)
                Rectangle {
                    x: 1.5
                    y: 1.5
                    width: Math.max(0, Math.min(batFrame.width - 3, (batFrame.width - 3) * (Math.min(100, Math.max(0, root.percentage)) / 100)))
                    height: batFrame.height - 3
                    radius: 1.5
                    color: root.fillColor

                    Behavior on width {
                        NumberAnimation { duration: 300 }
                    }
                }
                // Charging icon inside the battery frame
                Text {
                    anchors.centerIn: parent
                    text: "⚡"
                    color: Theme.success
                    font.pixelSize: 8
                    style: Text.Outline
                    styleColor: "#60000000"
                    visible: root.isCharging
                }
            }

            // Battery terminal tip
            Rectangle {
                anchors.left: batFrame.right
                anchors.leftMargin: 1
                anchors.verticalCenter: batFrame.verticalCenter
                width: 1.5
                height: 4
                radius: 0.5
                color: Theme.textSecondary
            }
        }

        // Percentage text placed to the right of battery body
        Text {
            id: percentageText
            text: root.percentage + "%"
            color: Theme.textSecondary
            font.pixelSize: 11
            font.weight: Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }

        // Blinking animation below 15% affecting both icon and percentage text
        SequentialAnimation {
            id: blinkAnim
            running: root.visible && root.percentage < 15 && !root.isCharging
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running) batRow.opacity = 1.0;
            }
            NumberAnimation { target: batRow; property: "opacity"; to: 0.15; duration: 350; easing.type: Easing.InOutQuad }
            NumberAnimation { target: batRow; property: "opacity"; to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
        }
    }

    MouseArea {
        id: batMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onContainsMouseChanged: {
            if (containsMouse && root.tooltipText !== "") {
                tooltipTimer.restart();
            } else {
                tooltipTimer.stop();
                tooltipWindow.visible = false;
            }
        }

        onClicked: mouse => {
            tooltipTimer.stop();
            tooltipWindow.visible = false;
            if (mouse.button === Qt.LeftButton) {
                root.clicked();
            } else if (mouse.button === Qt.RightButton) {
                OsdService.powerProfileCycle();
            }
        }
    }
}


