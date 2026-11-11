import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

FocusScope {
    id: themeScope

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    width: implicitWidth
    height: implicitHeight
    focus: true

    signal themeSelected()
    signal closeRequested()

    property int focusedIndex: 0
    property string initialTheme: ""

    function syncIndex() {
        var count = Theme.themesList ? Theme.themesList.length : 0;
        for (var i = 0; i < count; i++) {
            if (Theme.themesList[i].id === Theme.currentThemeName) {
                themeScope.focusedIndex = i;
                break;
            }
        }
    }

    function cancel() {
        if (themeScope.initialTheme !== "" && Theme.currentThemeName !== themeScope.initialTheme) {
            Theme.setTheme(themeScope.initialTheme);
        }
        themeScope.closeRequested();
    }

    Component.onCompleted: themeScope.syncIndex()

    onVisibleChanged: {
        if (visible) {
            themeScope.initialTheme = Theme.currentThemeName;
            themeScope.syncIndex();
            themeScope.forceActiveFocus();
        }
    }

    Keys.onPressed: function(event) {
        var count = Theme.themesList ? Theme.themesList.length : 0;
        if (count === 0) return;

        if (event.key === Qt.Key_Left) {
            themeScope.focusedIndex = (themeScope.focusedIndex - 1 + count) % count;
            Theme.setTheme(Theme.themesList[themeScope.focusedIndex].id, false);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            themeScope.focusedIndex = (themeScope.focusedIndex + 1) % count;
            Theme.setTheme(Theme.themesList[themeScope.focusedIndex].id, false);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            if (themeScope.focusedIndex - 3 >= 0) {
                themeScope.focusedIndex -= 3;
            } else {
                var bottomIdx = themeScope.focusedIndex + 3 * Math.floor((count - 1 - themeScope.focusedIndex) / 3);
                themeScope.focusedIndex = Math.min(count - 1, bottomIdx);
            }
            Theme.setTheme(Theme.themesList[themeScope.focusedIndex].id, false);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            if (themeScope.focusedIndex + 3 < count) {
                themeScope.focusedIndex += 3;
            } else {
                themeScope.focusedIndex = themeScope.focusedIndex % 3;
            }
            Theme.setTheme(Theme.themesList[themeScope.focusedIndex].id, false);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            themeScope.cancel();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            themeScope.initialTheme = Theme.themesList[themeScope.focusedIndex].id;
            Theme.setTheme(Theme.themesList[themeScope.focusedIndex].id, true);
            themeScope.themeSelected();
            event.accepted = true;
        }
    }

    Column {
        id: col
        spacing: 10
        anchors.centerIn: parent

        // Header Title (14px Bold)
        Text {
            id: headerText
            text: "Themes"
            font.pixelSize: 14
            font.weight: Font.Bold
            color: Theme.textPrimary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Themes Cards Grid (Max 3 items per row)
        Grid {
            id: cardsGrid
            columns: 3
            spacing: 14
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: Theme.themesList

                delegate: Item {
                    id: cardWrapper

                    readonly property bool isFocused: index === themeScope.focusedIndex
                    // readonly property bool isSelected: Theme.currentThemeName === modelData.id

                    implicitWidth: 92
                    implicitHeight: 86
                    width: 92
                    height: 86

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: 12
                        color: cardWrapper.isFocused ? Theme.surfaceActive : Theme.surface
                        border.color: cardWrapper.isFocused ? Theme.accent : (cardMouse.containsMouse ? Theme.borderHover : Theme.border)
                        border.width: cardWrapper.isFocused ? 2 : 1
                        scale: cardWrapper.isFocused ? 1.05 : 1.0
                        clip: true

                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            // Miniature clean window preview
                            Rectangle {
                                id: minWindow
                                width: 76
                                height: 48
                                radius: 8
                                color: modelData.obj.background
                                border.color: cardWrapper.isFocused ? Theme.accent : modelData.obj.border
                                border.width: 1
                                anchors.horizontalCenter: parent.horizontalCenter

                                // Top subtle window bar line
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.topMargin: 4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 20
                                    height: 2
                                    radius: 1
                                    color: modelData.obj.textMuted
                                    opacity: 0.6
                                }

                                // Dummy button figure inside preview window
                                Rectangle {
                                    width: 36
                                    height: 14
                                    radius: 5
                                    color: modelData.obj.accent
                                    anchors.centerIn: parent

                                    Rectangle {
                                        width: 12
                                        height: 3
                                        radius: 1.5
                                        color: modelData.obj.badgeFocusedText
                                        anchors.centerIn: parent
                                    }
                                }

                                // Dummy text line at bottom of window
                                Rectangle {
                                    width: 28
                                    height: 3
                                    radius: 1.5
                                    color: modelData.obj.textSecondary
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            // Theme Name Label
                            Text {
                                text: modelData.name
                                font.pixelSize: 11
                                font.weight: cardWrapper.isFocused ? Font.Bold : Font.Medium
                                color: cardWrapper.isFocused ? Theme.accent : Theme.textPrimary
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                themeScope.focusedIndex = index;
                                themeScope.initialTheme = modelData.id;
                                Theme.setTheme(modelData.id);
                                themeScope.themeSelected();
                            }
                        }
                    }
                }
            }
        }
    }
}
