import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Item {
    id: root

    property bool hasBattery: false
    property int percentage: 0
    property bool isCharging: false
    property string statusText: ""

    readonly property color fillColor: percentage < 20 ? Theme.danger : (percentage < 40 ? Theme.warning : Theme.textSecondary)

    implicitWidth: visible ? batRow.implicitWidth : 0
    implicitHeight: visible ? batRow.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight
    visible: hasBattery

    Process {
        id: batProc
        command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1>/dev/null 2>&1; then cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); stat=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); echo \"YES:$cap:$stat\"; else echo \"NO\"; fi"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var str = data.trim();
                if (str.startsWith("YES:")) {
                    var parts = str.split(":");
                    root.hasBattery = true;
                    root.percentage = parseInt(parts[1]) || 0;
                    var st = parts[2] ? parts[2].toLowerCase() : "";
                    root.isCharging = (st === "charging");
                    root.statusText = parts[2] || "";
                } else {
                    root.hasBattery = false;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batProc.running = true;
        }
    }

    Row {
        id: batRow
        spacing: 5
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        
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
            running: root.visible && root.percentage < 15
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running) batRow.opacity = 1.0;
            }
            NumberAnimation { target: batRow; property: "opacity"; to: 0.15; duration: 350; easing.type: Easing.InOutQuad }
            NumberAnimation { target: batRow; property: "opacity"; to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
        }
    }
}


