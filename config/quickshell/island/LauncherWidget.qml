import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import ".."

FocusScope {
    id: root

    implicitWidth: 440
    implicitHeight: 430
    width: implicitWidth
    height: implicitHeight
    focus: true

    signal appLaunched()
    signal closeRequested()

    property int selectedIndex: 0

    // Listado filtrado y ordenado alfabéticamente
    readonly property var filteredApps: {
        var all = DesktopEntries.applications.values;
        if (!all) return [];

        var q = searchInput.text.trim().toLowerCase();

        // Descartar entradas vacías o marcadas como no visibles
        var list = all.filter(function(app) {
            return app && app.name && !app.noDisplay;
        });

        if (q === "") {
            return list.sort(function(a, b) {
                return a.name.localeCompare(b.name);
            });
        }

        var filtered = list.filter(function(app) {
            var nameMatch = app.name.toLowerCase().indexOf(q) !== -1;
            var commentMatch = app.comment && app.comment.toLowerCase().indexOf(q) !== -1;
            var genericMatch = app.genericName && app.genericName.toLowerCase().indexOf(q) !== -1;
            var execMatch = app.execString && app.execString.toLowerCase().indexOf(q) !== -1;
            return nameMatch || commentMatch || genericMatch || execMatch;
        });

        return filtered.sort(function(a, b) {
            var aName = a.name.toLowerCase();
            var bName = b.name.toLowerCase();
            var aStarts = aName.startsWith(q);
            var bStarts = bName.startsWith(q);
            if (aStarts && !bStarts) return -1;
            if (!aStarts && bStarts) return 1;
            return a.name.localeCompare(b.name);
        });
    }

    function launchSelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            var app = filteredApps[selectedIndex];
            if (app) {
                root.appLaunched();
                app.execute();
            }
        }
    }

    // Reinicializar estado y foco al abrirse el widget
    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            root.selectedIndex = 0;
            searchInput.forceActiveFocus();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ================= CUADRO DE BÚSQUEDA =================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: 10
            color: Theme.surface
            border.color: searchInput.activeFocus ? Theme.accent : Theme.border
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // Icono de lupa
                Text {
                    text: "󰍉"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 16
                    color: searchInput.activeFocus ? Theme.accent : Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // Cuadro de texto
                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 13
                    color: Theme.textPrimary
                    clip: true
                    selectByMouse: true
                    focus: true

                    // Placeholder
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Buscar aplicación..."
                        font: parent.font
                        color: Theme.textMuted
                        opacity: 0.6
                        visible: !parent.text && !parent.inputMethodComposing
                    }

                    // Resetear la selección al escribir
                    onTextChanged: {
                        root.selectedIndex = 0;
                        if (appList.count > 0) {
                            appList.positionViewAtIndex(0, ListView.Beginning);
                        }
                    }

                    // Navegación por teclado
                    Keys.onPressed: function(event) {
                        var count = root.filteredApps.length;
                        if (event.key === Qt.Key_Down) {
                            if (count > 0) {
                                root.selectedIndex = (root.selectedIndex + 1) % count;
                                appList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (count > 0) {
                                root.selectedIndex = (root.selectedIndex - 1 + count) % count;
                                appList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.launchSelected();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.closeRequested();
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        // ================= ESTADO VACÍO =================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.filteredApps.length === 0
            spacing: 8

            Item { Layout.fillHeight: true }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰍉"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 32
                color: Theme.textMuted
                opacity: 0.4
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No se encontraron aplicaciones"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 12
                color: Theme.textMuted
            }

            Item { Layout.fillHeight: true }
        }

        // ================= LISTADO DE APLICACIONES =================
        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.filteredApps
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            visible: root.filteredApps.length > 0

            ScrollBar.vertical: ScrollBar {
                id: vbar
                active: true
                policy: ScrollBar.AsNeeded
                width: 4

                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: vbar.pressed ? Theme.accent : (vbar.hovered ? Theme.borderHover : Theme.border)
                    opacity: vbar.active ? 0.8 : 0.4
                }
            }

            // Desplazamiento fluido con rueda de ratón
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    var delta = wheel.angleDelta.y;
                    if (delta !== 0) {
                        var step = delta * 0.8;
                        var maxScroll = Math.max(0, appList.contentHeight - appList.height);
                        appList.contentY = Math.max(0, Math.min(maxScroll, appList.contentY - step));
                    }
                }
            }

            delegate: Rectangle {
                id: rowItem
                required property var modelData
                required property int index

                readonly property bool isFocused: index === root.selectedIndex
                readonly property string appDescription: {
                    if (!modelData) return "";
                    if (modelData.comment && modelData.comment !== "") return modelData.comment;
                    if (modelData.genericName && modelData.genericName !== "") return modelData.genericName;
                    return "";
                }

                width: appList.width - (vbar.visible ? 6 : 0)
                height: appDescription !== "" ? 48 : 42
                radius: 8

                // Resaltado de la fila entera
                color: isFocused ? Theme.surfaceActive : (rowMouse.containsMouse ? Theme.surfaceHover : "transparent")
                border.color: isFocused ? Theme.borderHover : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                // Línea vertical fina y centrada (sin llegar a los bordes superior e inferior)
                Rectangle {
                    id: focusLine
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: parent.height - 14
                    radius: 1.5
                    color: Theme.accent
                    visible: rowItem.isFocused
                    opacity: rowItem.isFocused ? 1.0 : 0.0

                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14 // Espacio para la línea vertical de foco
                    anchors.rightMargin: 10
                    spacing: 12

                    // Icono de la aplicación
                    IconImage {
                        id: appIcon
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        source: {
                            if (modelData && modelData.icon) {
                                if (modelData.icon.startsWith("/") || modelData.icon.startsWith("file://")) {
                                    return modelData.icon;
                                }
                                var p = Quickshell.iconPath(modelData.icon, true);
                                if (p !== "") return p;
                            }
                            return Quickshell.iconPath("application-x-executable", true);
                        }
                    }

                    // Título a la derecha y descripción justo debajo
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            text: modelData ? (modelData.name || "") : ""
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: rowItem.isFocused ? Theme.textPrimary : Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: rowItem.appDescription
                            visible: text !== ""
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 11
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            maximumLineCount: 1
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: {
                        root.selectedIndex = index;
                        root.launchSelected();
                    }
                }
            }
        }
    }
}
