import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"
import ".."

FocusScope {
    id: root

    implicitWidth: rowButtons.implicitWidth
    implicitHeight: rowButtons.implicitHeight
    width: implicitWidth
    height: implicitHeight
    focus: true

    signal closeRequested()
    signal actionExecuted()

    property int focusedIndex: 0

    // Power actions and corresponding system actions
    readonly property var actions: [
        {
            id: "lock",
            name: "Lock",
            icon: "󰌾",
            isDanger: false
        },
        {
            id: "suspend",
            name: "Suspend",
            icon: "󰤄",
            isDanger: false
        },
        {
            id: "logout",
            name: "Log Out",
            icon: "󰍃",
            isDanger: false
        },
        {
            id: "reboot",
            name: "Reboot",
            icon: "󰑐",
            isDanger: false
        },
        {
            id: "poweroff",
            name: "Power Off",
            icon: "󰐥",
            isDanger: true
        }
    ]

    function runAction(index) {
        if (index < 0 || index >= actions.length) return;
        var item = actions[index];
        root.actionExecuted();
        root.closeRequested();
        switch (item.id) {
            case "lock":
                IdleService.lockNow();
                break;
            case "suspend":
                IdleService.suspendNow();
                break;
            case "logout":
                Quickshell.execDetached(["sh", "-c", "niri msg action quit --skip-confirmation || loginctl terminate-user \"$USER\""]);
                break;
            case "reboot":
                Quickshell.execDetached(["systemctl", "reboot"]);
                break;
            case "poweroff":
                Quickshell.execDetached(["systemctl", "poweroff"]);
                break;
        }
    }

    // Grab keyboard focus when widget becomes visible
    onVisibleChanged: {
        if (visible) {
            root.focusedIndex = 0;
            root.forceActiveFocus();
        }
    }

    // Keyboard navigation and execution
    Keys.onPressed: function(event) {
        var count = root.actions.length;
        if (count === 0) return;

        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.focusedIndex = (root.focusedIndex - 1 + count) % count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            root.focusedIndex = (root.focusedIndex + 1) % count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Backtab) {
            root.focusedIndex = (root.focusedIndex - 1 + count) % count;
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.runAction(root.focusedIndex);
            event.accepted = true;
        }
    }

    // Action buttons container
    Row {
        id: rowButtons
        spacing: 10
        anchors.centerIn: parent

        Repeater {
            model: root.actions

            delegate: Item {
                id: itemWrapper

                readonly property bool isFocused: index === root.focusedIndex
                readonly property bool isDanger: modelData.isDanger

                implicitWidth: 72
                implicitHeight: 64
                width: implicitWidth
                height: implicitHeight

                Rectangle {
                    id: btnRect
                    anchors.fill: parent
                    radius: 12

                    // Dynamic theme styling
                    color: {
                        if (itemWrapper.isFocused || btnMouse.containsMouse) {
                            return itemWrapper.isDanger ? Theme.danger : Theme.surfaceActive;
                        }
                        return Theme.surface;
                    }

                    border.color: {
                        if (itemWrapper.isFocused) {
                            return itemWrapper.isDanger ? Theme.danger : Theme.accent;
                        }
                        if (btnMouse.containsMouse) {
                            return Theme.borderHover;
                        }
                        return Theme.border;
                    }
                    border.width: itemWrapper.isFocused ? 2 : 1

                    // Scale feedback on hover/focus/press
                    scale: btnMouse.pressed ? 0.95 : (itemWrapper.isFocused ? 1.04 : 1.0)

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        // Action icon
                        Text {
                            text: modelData.icon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            color: {
                                if (itemWrapper.isFocused || btnMouse.containsMouse) {
                                    return itemWrapper.isDanger ? "#FFFFFF" : Theme.accent;
                                }
                                return Theme.textPrimary;
                            }
                            anchors.horizontalCenter: parent.horizontalCenter

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Action label
                        Text {
                            text: modelData.name
                            font.pixelSize: 10
                            font.weight: itemWrapper.isFocused ? Font.Bold : Font.Medium
                            color: {
                                if (itemWrapper.isFocused || btnMouse.containsMouse) {
                                    return itemWrapper.isDanger ? "#FFFFFF" : Theme.textPrimary;
                                }
                                return Theme.textSecondary;
                            }
                            anchors.horizontalCenter: parent.horizontalCenter

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    // Mouse interaction synced with focus index
                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            root.focusedIndex = index;
                        }

                        onClicked: {
                            root.focusedIndex = index;
                            root.runAction(index);
                        }
                    }
                }
            }
        }
    }
}
