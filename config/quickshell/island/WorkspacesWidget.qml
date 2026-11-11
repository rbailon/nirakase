import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Item {
    id: root

    signal doubleClicked()

    implicitWidth: wsRow.implicitWidth
    implicitHeight: wsRow.implicitHeight
    width: implicitWidth
    height: implicitHeight
    property var workspaces: []
    property var focusedWorkspaceId: null

    function refreshWorkspaces() {
        if (!fetchProc.running) {
            fetchProc.running = true;
        }
    }

    Process {
        id: eventStreamProc
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root.refreshWorkspaces();
            }
        }
    }

    Process {
        id: fetchProc
        command: ["niri", "msg", "-j", "workspaces"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    var parsed = JSON.parse(data);
                    if (Array.isArray(parsed)) {
                        parsed.sort(function(a, b) { return a.idx - b.idx; });

                        // Identify focused workspace ID
                        var focusedId = null;
                        for (var i = 0; i < parsed.length; i++) {
                            if (parsed[i].is_focused) {
                                focusedId = parsed[i].id;
                                break;
                            }
                        }
                        root.focusedWorkspaceId = focusedId;

                        // Filter active or focused workspaces
                        var filtered = parsed.filter(function(ws) {
                            return ws.is_focused || (ws.active_window_id !== null && ws.active_window_id !== undefined);
                        });

                        // Only reassign root.workspaces if workspace membership changed
                        var idsChanged = false;
                        if (filtered.length !== root.workspaces.length) {
                            idsChanged = true;
                        } else {
                            for (var j = 0; j < filtered.length; j++) {
                                if (filtered[j].id !== root.workspaces[j].id) {
                                    idsChanged = true;
                                    break;
                                }
                            }
                        }

                        if (idsChanged) {
                            root.workspaces = filtered;
                        }
                    }
                } catch (e) {
                    console.warn("Failed to parse niri workspaces JSON:", e);
                }
            }
        }
    }

    Process {
        id: focusProc
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWorkspaces()
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.workspaces

            delegate: Rectangle {
                id: wsBadge
                property bool isFocused: modelData.id === root.focusedWorkspaceId

                width: isFocused ? 26 : 10
                height: 10
                radius: 5

                color: Theme.badgeFocusedBg

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.InOutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: mouse => {
                        mouse.accepted = true;
                        if (!wsBadge.isFocused) {
                            var targetRef = modelData.name ? String(modelData.name) : String(modelData.idx);
                            focusProc.running = false;
                            focusProc.exec(["niri", "msg", "action", "focus-workspace", targetRef]);
                        }
                    }
                    onDoubleClicked: mouse => {
                        mouse.accepted = true;
                        root.doubleClicked();
                    }
                }
            }
        }
    }
}



