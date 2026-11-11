import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "."

ShellRoot {
    id: root

    property string indexFile: Quickshell.env("HOME") + "/.cache/nirakase/image-selector/index.json"
    property string currentWallpaper: Quickshell.env("NIRAKASE_CURRENT_WALLPAPER") || ""
    
    property int selectedIndex: 0
    property int expandedWidth: 540
    property int collapsedWidth: 90
    property int itemHeight: 340
    property int itemSpacing: 10
    property bool ready: false

    ListModel {
        id: imageModel
    }

    // Load cached index and match active wallpaper
    FileView {
        path: root.indexFile
        onLoaded: {
            try {
                var list = JSON.parse(text());
                imageModel.clear();
                var targetIdx = 0;
                for (var i = 0; i < list.length; i++) {
                    imageModel.append(list[i]);
                    if (root.currentWallpaper !== "" && list[i].path === root.currentWallpaper) {
                        targetIdx = i;
                    }
                }
                root.selectedIndex = targetIdx;
                // Enable layout animations once initial position is resolved
                Qt.callLater(() => {
                    root.ready = true;
                });
            } catch (e) {
                console.error("Failed to load wallpaper index:", e);
                root.ready = true;
            }
        }
    }

    function applySelection() {
        if (selectedIndex >= 0 && selectedIndex < imageModel.count) {
            var chosen = imageModel.get(selectedIndex).path;
            Quickshell.execDetached(["nirakase-wallpaper", chosen]);
        }
        Qt.quit();
    }

    function closeSelector() {
        Qt.quit();
    }

    PanelWindow {
        id: panel
        visible: true
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        WlrLayershell.namespace: "nirakase-image-selector"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        // Dimmed backdrop
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.82)

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeSelector()
            }
        }

        // Main interactive container with smooth entrance fade
        Item {
            id: mainContainer
            anchors.fill: parent
            focus: true
            opacity: root.ready ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Component.onCompleted: mainContainer.forceActiveFocus()

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.closeSelector();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    root.selectedIndex = (root.selectedIndex - 1 + imageModel.count) % imageModel.count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.selectedIndex = (root.selectedIndex + 1) % imageModel.count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.applySelection();
                    event.accepted = true;
                }
            }

            Item {
                id: carouselContainer
                anchors.centerIn: parent
                height: root.itemHeight
                width: parent.width

                Repeater {
                    model: imageModel

                    delegate: Rectangle {
                        id: card
                        required property var model
                        required property int index

                        readonly property bool isSelected: index === root.selectedIndex
                        readonly property int distance: index - root.selectedIndex

                        height: root.itemHeight
                        width: isSelected ? root.expandedWidth : root.collapsedWidth
                        radius: 14
                        clip: true

                        // Symmetrical carousel positioning relative to center
                        x: {
                            var step = root.collapsedWidth + root.itemSpacing;
                            var selX = (carouselContainer.width - root.expandedWidth) / 2;

                            if (index === root.selectedIndex) {
                                return selX;
                            } else if (index < root.selectedIndex) {
                                var distLeft = root.selectedIndex - index;
                                return selX - (distLeft * step);
                            } else {
                                var distRight = index - root.selectedIndex;
                                return selX + root.expandedWidth + root.itemSpacing + ((distRight - 1) * step);
                            }
                        }

                        z: isSelected ? 100 : (50 - Math.abs(distance))
                        opacity: Math.abs(distance) > 5 ? 0.0 : (isSelected ? 1.0 : (0.9 - Math.abs(distance) * 0.15))
                        visible: opacity > 0.01

                        color: Theme.surface
                        border.color: isSelected ? Theme.accent : Theme.border
                        border.width: isSelected ? 2 : 1

                        // Animate transitions only after initial layout is set
                        Behavior on x {
                            enabled: root.ready
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on width {
                            enabled: root.ready
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Image {
                            anchors.fill: parent
                            source: "file://" + model.thumb
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                        }

                        // Dim unselected cards
                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: isSelected ? 0.0 : 0.45
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        // Active wallpaper label
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width - 32, labelText.implicitWidth + 24)
                            height: 32
                            radius: 8
                            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.85)
                            border.color: Theme.border
                            border.width: 1
                            visible: isSelected

                            Text {
                                id: labelText
                                anchors.centerIn: parent
                                text: model.name
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (isSelected) {
                                    root.applySelection();
                                } else {
                                    root.selectedIndex = index;
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.top: carouselContainer.bottom
                anchors.topMargin: 28
                anchors.horizontalCenter: parent.horizontalCenter
                text: "← / → : Navigate   •   ENTER : Apply   •   ESC : Cancel"
                color: Theme.textSecondary
                font.pixelSize: 12
            }
        }
    }
}
