import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."
import "../components"
import "../services"

FocusScope {
    id: root

    implicitWidth: 380
    implicitHeight: 440
    width: implicitWidth
    height: implicitHeight
    focus: true

    signal closeRequested()

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ================= HEADER =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰂚 Notificaciones"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Theme.textPrimary
            }

            Rectangle {
                visible: NotificationService.unreadCount > 0
                implicitWidth: countText.implicitWidth + 10
                implicitHeight: 18
                radius: 9
                color: Theme.accent

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: String(NotificationService.unreadCount)
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Theme.badgeFocusedText || "#FFFFFF"
                }
            }

            Item { Layout.fillWidth: true }

            // Botón No Molestar (DND)
            Rectangle {
                implicitWidth: dndRow.implicitWidth + 12
                implicitHeight: 24
                radius: 6
                color: NotificationService.dnd ? Theme.surfaceActive : (dndMouse.containsMouse ? Theme.surfaceHover : "transparent")
                border.color: NotificationService.dnd ? Theme.danger : Theme.border
                border.width: 1

                RowLayout {
                    id: dndRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: NotificationService.dnd ? "󰂛" : "󰂚"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 11
                        color: NotificationService.dnd ? Theme.danger : Theme.textSecondary
                    }

                    Text {
                        text: NotificationService.dnd ? "DND" : "Silenciar"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: NotificationService.dnd ? Theme.danger : Theme.textSecondary
                    }
                }

                MouseArea {
                    id: dndMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.toggleDnd()
                }
            }

            // Botón Limpiar Todo
            Rectangle {
                visible: NotificationService.unreadCount > 0
                implicitWidth: clearRow.implicitWidth + 12
                implicitHeight: 24
                radius: 6
                color: clearMouse.containsMouse ? Theme.surfaceHover : "transparent"
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰆴"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 11
                        color: Theme.danger
                    }

                    Text {
                        text: "Limpiar"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.danger
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearAll()
                }
            }

            // Botón Cerrar Panel
            Text {
                text: "󰅖"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 14
                color: closeMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Línea divisoria
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
            opacity: 0.5
        }

        // ================= EMPTY STATE =================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.unreadCount === 0
            spacing: 6

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰂜"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 36
                color: Theme.textMuted
                opacity: 0.4
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Sin notificaciones pendientes"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                color: Theme.textMuted
            }

            Item { Layout.fillHeight: true }
        }

        // ================= LISTVIEW REUTILIZANDO NotificationsCard =================
        ListView {
            id: notifList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: NotificationService.history
            boundsBehavior: Flickable.StopAtBounds
            visible: NotificationService.unreadCount > 0

            // Desplazamiento fluido con rueda de ratón
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    var delta = wheel.angleDelta.y;
                    if (delta !== 0) {
                        var step = delta * 0.8;
                        var maxScroll = Math.max(0, notifList.contentHeight - notifList.height);
                        notifList.contentY = Math.max(0, Math.min(maxScroll, notifList.contentY - step));
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: vbar
                active: true
                policy: ScrollBar.AsNeeded
                width: 6

                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: vbar.pressed ? Theme.accent : (vbar.hovered ? Theme.borderHover : Theme.border)
                    opacity: vbar.active ? 0.8 : 0.4
                }
            }

            // Delegado directo reutilizando la tarjeta compartida
            delegate: NotificationsCard {
                required property var modelData
                width: notifList.width - (vbar.visible ? 8 : 0)
                notification: modelData
            }
        }
    }
}
