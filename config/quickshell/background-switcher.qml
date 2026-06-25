import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

ShellRoot {
    id: root

    property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))) + "/nirakase-image-selector.sock"
    
    property bool opened: false
    property string selectionFile: ""
    property string doneFile: ""
    property string selectedImage: ""
    
    property int selectedIndex: 0
    property int expandedWidth: 640
    property int collapsedWidth: 100
    property int itemHeight: 400
    property int spacing: -15
    property int skewOffset: 25

    ListModel {
        id: imageModel
    }

    // Socket server for IPC
    SocketServer {
        active: true
        path: root.socketPath

        handler: Socket {
            id: clientSocket
            parser: SplitParser {
                onRead: function(message) {
                    root.handleRequest(message);
                    clientSocket.connected = false;
                }
            }
        }
    }

    // Process to write selection and touch done file
    Process {
        id: applyProcess
        command: []
        running: false
        onRunningChanged: {
            if (!running) {
                root.opened = false;
            }
        }
    }

    function handleRequest(message) {
        try {
            var data = JSON.parse(message);
            imageModel.clear();
            for (var i = 0; i < data.images.length; i++) {
                imageModel.append(data.images[i]);
            }
            root.selectionFile = data.selectionFile;
            root.doneFile = data.doneFile;
            root.selectedImage = data.selected;

            var foundIndex = 0;
            for (var j = 0; j < imageModel.count; j++) {
                if (imageModel.get(j).path === root.selectedImage) {
                    foundIndex = j;
                    break;
                }
            }
            root.selectedIndex = foundIndex;
            root.opened = true;
            mainContainer.forceActiveFocus();
        } catch (e) {
            console.log("JSON Parse Error: " + e);
        }
    }

    function applySelected() {
        if (selectedIndex >= 0 && selectedIndex < imageModel.count) {
            var chosen = imageModel.get(selectedIndex).path;
            applyProcess.command = ["bash", "-c", "printf '%s' '" + chosen + "' > '" + root.selectionFile + "' && touch '" + root.doneFile + "'"];
            applyProcess.running = true;
        }
    }

    function cancel() {
        applyProcess.command = ["bash", "-c", "touch '" + root.doneFile + "'"];
        applyProcess.running = true;
    }

    PanelWindow {
        id: panel
        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        
        WlrLayershell.namespace: "nirakase-image-selector"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        // Dark dim background
        Rectangle {
            anchors.fill: parent
            color: "#dd080808" // Nirakase dark dim overlay
        }

        // Catch mouse clicks outside to cancel
        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }

        // Central container for keyboard events and the slide deck
        Item {
            id: mainContainer
            width: parent.width
            height: root.itemHeight + 100
            anchors.centerIn: parent
            focus: true

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.cancel();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.selectedIndex = Math.min(imageModel.count - 1, root.selectedIndex + 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.applySelected();
                    event.accepted = true;
                }
            }

            // Slide deck item list
            Item {
                id: deckContainer
                width: root.expandedWidth + (imageModel.count - 1) * (root.collapsedWidth + root.spacing)
                height: root.itemHeight
                anchors.centerIn: parent

                Repeater {
                    model: imageModel

                    delegate: Item {
                        id: sliceItem
                        
                        width: index === root.selectedIndex ? root.expandedWidth : root.collapsedWidth
                        height: parent.height
                        
                        x: {
                            var cWidth = root.collapsedWidth + root.spacing;
                            var selX = (parent.width - root.expandedWidth) / 2;
                            if (index === root.selectedIndex) {
                                return selX;
                            } else if (index < root.selectedIndex) {
                                return selX - (root.selectedIndex - index) * cWidth;
                            } else {
                                return selX + root.expandedWidth + root.spacing + (index - root.selectedIndex - 1) * cWidth;
                            }
                        }

                        z: index === root.selectedIndex ? 100 : (50 - Math.abs(index - root.selectedIndex))

                        opacity: {
                            var dist = Math.abs(index - root.selectedIndex);
                            if (dist > 5) return 0.0;
                            return dist === 0 ? 1.0 : (1.0 - dist * 0.15);
                        }

                        visible: opacity > 0.01

                        Behavior on x {
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }
                        Behavior on width {
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }

                        // Parallelogram mask shape
                        Item {
                            id: maskShape
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true

                            Shape {
                                anchors.fill: parent
                                antialiasing: true
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    fillColor: "white"
                                    strokeColor: "transparent"
                                    startX: root.skewOffset
                                    startY: 0
                                    PathLine { x: parent.width; y: 0 }
                                    PathLine { x: parent.width - root.skewOffset; y: parent.height }
                                    PathLine { x: 0; y: parent.height }
                                    PathLine { x: root.skewOffset; y: 0 }
                                }
                            }
                        }

                        // Content (Image clipped by mask)
                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: maskShape
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 0.5
                            }

                            Image {
                                anchors.fill: parent
                                source: "file://" + model.thumb
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                            }

                            // Dark overlay on collapsed slices
                            Rectangle {
                                anchors.fill: parent
                                color: "#000000"
                                opacity: index === root.selectedIndex ? 0.0 : 0.45
                                Behavior on opacity {
                                    NumberAnimation { duration: 200 }
                                }
                            }
                        }

                        // Parallelogram white/grey border outline
                        Shape {
                            anchors.fill: parent
                            antialiasing: true
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: index === root.selectedIndex ? "#ffffff" : "#44ffffff"
                                strokeWidth: index === root.selectedIndex ? 3 : 1
                                Behavior on strokeColor { ColorAnimation { duration: 200 } }
                                Behavior on strokeWidth { NumberAnimation { duration: 200 } }

                                startX: root.skewOffset
                                startY: 0
                                PathLine { x: parent.width; y: 0 }
                                PathLine { x: parent.width - root.skewOffset; y: parent.height }
                                PathLine { x: 0; y: parent.height }
                                PathLine { x: root.skewOffset; y: 0 }
                            }
                        }

                        // Label overlay for selected item
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 15
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 80
                            height: 38
                            color: "#ee0c0c0c"
                            radius: 6
                            visible: index === root.selectedIndex
                            opacity: index === root.selectedIndex ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: model.name
                                color: "#ffffff"
                                font.family: "Outfit"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        // Clicking on collapsed items expands them, clicking on expanded applies them
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (index === root.selectedIndex) {
                                    root.applySelected();
                                } else {
                                    root.selectedIndex = index;
                                }
                            }
                        }
                    }
                }
            }

            // Keyboard navigation hint at the bottom
            Text {
                anchors.top: deckContainer.bottom
                anchors.topMargin: 25
                anchors.horizontalCenter: parent.horizontalCenter
                text: "← / → : Navigate   •   ENTER : Select   •   ESC : Cancel"
                color: "#88ffffff"
                font.family: "Outfit"
                font.pixelSize: 12
            }
        }
    }
}
