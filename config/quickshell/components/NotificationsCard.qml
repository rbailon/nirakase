import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import ".."
import "../services"

Rectangle {
    id: root

    // Objeto notificación a representar
    property var notification: null

    readonly property bool isCritical: notification !== null && notification.urgency === NotificationUrgency.Critical
    readonly property alias hovered: hoverWatcher.hovered

    // Señales para eventos
    signal dismissed()
    signal actionInvoked(var action)

    // Helper para resolver ruta de iconos locales o del tema
    function resolveIcon(icon) {
        if (!icon || icon === "") return "";
        if (icon.startsWith("/") || icon.startsWith("file://")) return icon;
        return Quickshell.iconPath(icon, true);
    }

    // Lista de acciones visibles (excluyendo la acción "default")
    readonly property var visibleActions: {
        if (!root.notification || !root.notification.actions) return [];
        var list = [];
        for (var i = 0; i < root.notification.actions.length; i++) {
            var a = root.notification.actions[i];
            if (a && a.identifier !== "default") {
                list.push(a);
            }
        }
        return list;
    }

    implicitHeight: contentColumn.implicitHeight + 24
    height: implicitHeight
    radius: 12
    color: Theme.surface || "#18181B"
    border.color: root.isCritical ? (Theme.danger || "#EF4444") : (hoverWatcher.hovered ? (Theme.borderHover || "#52525B") : (Theme.border || "#3F3F46"))
    border.width: root.isCritical ? 2 : 1

    HoverHandler {
        id: hoverWatcher
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8

        // Fila Superior: Nombre de app, Badge crítico y Botón de cierre
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.notification ? (root.notification.appName || "Sistema") : "Sistema"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: root.isCritical ? (Theme.danger || "#EF4444") : (Theme.textSecondary || "#A1A1AA")
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // Badge para notificaciones críticas
            Rectangle {
                visible: root.isCritical
                color: Theme.danger || "#EF4444"
                radius: 4
                implicitWidth: criticalLabel.implicitWidth + 8
                implicitHeight: criticalLabel.implicitHeight + 4
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: criticalLabel
                    anchors.centerIn: parent
                    text: "CRÍTICO"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                }
            }

            // Botón de descarte (󰅖)
            Text {
                text: "󰅖"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 13
                color: closeArea.containsMouse ? (Theme.textPrimary || "#FFFFFF") : (Theme.textMuted || "#71717A")

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.notification) {
                            NotificationService.dismiss(root.notification);
                        }
                        root.dismissed();
                    }
                }
            }
        }

        // Fila Central: Icono o imagen junto al título y contenido
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Layout.alignment: Qt.AlignTop

            IconImage {
                id: notifIcon
                visible: source !== ""
                implicitWidth: 32
                implicitHeight: 32
                Layout.alignment: Qt.AlignTop
                source: {
                    if (!root.notification) return "";
                    var img = root.notification.image;
                    if (img && img !== "") return root.resolveIcon(img);
                    var icon = root.notification.appIcon;
                    if (icon && icon !== "") return root.resolveIcon(icon);
                    return "";
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.notification ? (root.notification.summary || "") : ""
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary || "#F4F4F5"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Text {
                    text: root.notification ? (root.notification.body || "") : ""
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 11
                    color: Theme.textSecondary || "#D4D4D8"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }

        // Fila Inferior: Botones de acciones interactivas de D-Bus
        RowLayout {
            visible: root.visibleActions.length > 0
            spacing: 8
            Layout.fillWidth: true
            Layout.topMargin: 4

            Repeater {
                model: root.visibleActions

                Rectangle {
                    id: actionBtn
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 26
                    radius: 6
                    color: actionMouse.containsMouse ? (Theme.surfaceActive || "#3A3A3C") : (Theme.surface || "#27272A")
                    border.color: actionMouse.containsMouse ? (Theme.borderHover || "#52525B") : (Theme.border || "#3F3F46")
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: actionBtn.modelData ? (actionBtn.modelData.text || "") : ""
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: actionMouse.containsMouse ? (Theme.accent || "#FFFFFF") : (Theme.textPrimary || "#E4E4E7")
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (actionBtn.modelData) {
                                actionBtn.modelData.invoke();
                                root.actionInvoked(actionBtn.modelData);
                            }
                        }
                    }
                }
            }
        }
    }

    // Clic en la tarjeta: invoca acción "default" y descarta si no es residente
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.notification) return;
            var notif = root.notification;
            var hasDefault = false;
            if (notif.actions) {
                for (var i = 0; i < notif.actions.length; i++) {
                    if (notif.actions[i] && notif.actions[i].identifier === "default") {
                        notif.actions[i].invoke();
                        hasDefault = true;
                        break;
                    }
                }
            }
            if (!hasDefault && !notif.resident) {
                NotificationService.dismiss(notif);
            }
            root.dismissed();
        }
    }
}
