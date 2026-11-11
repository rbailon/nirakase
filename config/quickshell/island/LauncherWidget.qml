import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."
import "../services"

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
    property bool active: false

    // Multi-purpose mode state ("r:" activates Remmina, "v:" activates Clipboard history)
    readonly property string trimmedQuery: searchInput.text.trim().toLowerCase()
    readonly property bool isRemminaMode: trimmedQuery.startsWith("r:")
    readonly property bool isClipboardMode: trimmedQuery.startsWith("v:")
    readonly property bool isSpecialMode: isRemminaMode || isClipboardMode

    // Internal cache of applications and Remmina connections
    property var cachedApps: []
    property var cachedRemmina: []
    property var filteredApps: []
    property var _pendingRemmina: []

    readonly property var _rawApps: DesktopEntries.applications ? DesktopEntries.applications.values : []
    on_RawAppsChanged: reloadApps()

    // Reactively update list if clipboard history changes while in "v:" mode
    Connections {
        target: ClipboardService
        function onHistoryChanged() {
            if (root.active && root.isClipboardMode) {
                root.filterApps();
            }
        }
    }

    // Pre-resolved icon for Remmina profiles
    readonly property string remminaIconSource: {
        var icons = ["org.remmina.Remmina", "remmina", "preferences-desktop-remote-desktop", "network-server", "application-x-executable"];
        for (var i = 0; i < icons.length; i++) {
            var p = Quickshell.iconPath(icons[i], true);
            if (p !== "") return p;
        }
        return "";
    }

    // Ultra-lightweight asynchronous process to read ~/.local/share/remmina/*.remmina profiles
    Process {
        id: remminaLoaderProc
        command: [
            "sh", "-c",
            "set -- \"$HOME/.local/share/remmina\"/*.remmina; [ -e \"$1\" ] || exit 0; awk '\n" +
            "FNR == 1 {\n" +
            "    if (file != \"\") print file \"\\t\" name \"\\t\" proto \"\\t\" server \"\\t\" grp \"\\t\" usr;\n" +
            "    file = FILENAME; name = \"\"; proto = \"\"; server = \"\"; grp = \"\"; usr = \"\";\n" +
            "}\n" +
            "/^name=/     { sub(/\\r$/, \"\"); name = substr($0, 6) }\n" +
            "/^protocol=/ { sub(/\\r$/, \"\"); proto = substr($0, 10) }\n" +
            "/^server=/   { sub(/\\r$/, \"\"); server = substr($0, 8) }\n" +
            "/^group=/    { sub(/\\r$/, \"\"); grp = substr($0, 7) }\n" +
            "/^username=/ { sub(/\\r$/, \"\"); usr = substr($0, 10) }\n" +
            "END {\n" +
            "    if (file != \"\") print file \"\\t\" name \"\\t\" proto \"\\t\" server \"\\t\" grp \"\\t\" usr;\n" +
            "}' \"$@\""
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = data.split("\t");
                var filePath = (parts[0] || "").trim();
                if (filePath === "") return;

                var rawName = (parts[1] || "").trim();
                var proto = (parts[2] || "REMOTE").trim().toUpperCase();
                var server = (parts[3] || "").trim();
                var grp = (parts[4] || "").trim();
                var usr = (parts[5] || "").trim();

                // Fallback to filename if profile has no name= field
                if (rawName === "") {
                    var base = filePath.split("/").pop();
                    rawName = base.replace(/\.remmina$/i, "");
                }

                // Build clear description: [PROTOCOL] Group • user@server
                var descParts = [];
                if (proto !== "") descParts.push("[" + proto + "]");
                if (grp !== "") descParts.push(grp);
                var hostPart = (usr !== "" && server !== "") ? (usr + "@" + server) : (server !== "" ? server : usr);
                if (hostPart !== "") descParts.push(hostPart);

                var desc = descParts.join(" • ");
                var nameLower = rawName.toLowerCase();

                root._pendingRemmina.push({
                    isRemmina: true,
                    isClipboard: false,
                    filePath: filePath,
                    protocol: proto,
                    name: rawName,
                    nameLower: nameLower,
                    description: desc,
                    searchKey: (nameLower + " " + proto.toLowerCase() + " " + grp.toLowerCase() + " " + server.toLowerCase() + " " + usr.toLowerCase()),
                    icon: root.remminaIconSource
                });
            }
        }

        onExited: {
            var list = root._pendingRemmina.slice();
            list.sort(function(a, b) {
                if (a.nameLower < b.nameLower) return -1;
                if (a.nameLower > b.nameLower) return 1;
                return 0;
            });
            root.cachedRemmina = list;
            if (root.isRemminaMode) {
                root.filterApps();
            }
        }
    }

    // Decoupled launcher process for Remmina connections
    Process {
        id: remminaLaunchProc
    }

    function reloadRemmina() {
        if (remminaLoaderProc.running) return;
        root._pendingRemmina = [];
        remminaLoaderProc.running = true;
    }

    Component.onCompleted: {
        reloadApps();
        reloadRemmina();
    }

    function reloadApps() {
        var raw = _rawApps;
        if (!raw || raw.length === 0) {
            cachedApps = [];
            if (!isSpecialMode) filteredApps = [];
            return;
        }

        var list = [];
        for (var i = 0; i < raw.length; i++) {
            var app = raw[i];
            if (!app || !app.name || app.noDisplay) continue;

            var name = app.name;
            var comment = app.comment || "";
            var genericName = app.genericName || "";
            var desc = (comment !== "") ? comment : genericName;
            var nameLower = name.toLowerCase();

            // Pre-resolve icon path once
            var iconSource = "";
            if (app.icon) {
                if (app.icon.startsWith("/") || app.icon.startsWith("file://")) {
                    iconSource = app.icon.startsWith("/") ? ("file://" + app.icon) : app.icon;
                } else {
                    var p = Quickshell.iconPath(app.icon, true);
                    iconSource = (p !== "") ? p : Quickshell.iconPath("application-x-executable", true);
                }
            } else {
                iconSource = Quickshell.iconPath("application-x-executable", true);
            }

            list.push({
                isRemmina: false,
                isClipboard: false,
                entry: app,
                name: name,
                nameLower: nameLower,
                description: desc,
                searchKey: (nameLower + " " + desc.toLowerCase() + " " + (app.execString || "").toLowerCase()),
                icon: iconSource
            });
        }

        // Fast native alphabetical sorting without localeCompare
        list.sort(function(a, b) {
            if (a.nameLower < b.nameLower) return -1;
            if (a.nameLower > b.nameLower) return 1;
            return 0;
        });

        cachedApps = list;
        if (!isSpecialMode) {
            filterApps();
        }
    }

    function filterApps() {
        var rawText = searchInput.text.trim();
        var lower = rawText.toLowerCase();
        var remminaActive = lower.startsWith("r:");
        var clipboardActive = lower.startsWith("v:");

        var sourceList = clipboardActive ? ClipboardService.history : (remminaActive ? cachedRemmina : cachedApps);
        var q = (remminaActive || clipboardActive) ? rawText.slice(2).trim().toLowerCase() : lower;

        if (q === "") {
            filteredApps = sourceList;
        } else {
            var startsWithList = [];
            var containsList = [];

            for (var i = 0; i < sourceList.length; i++) {
                var item = sourceList[i];
                if (item.nameLower.startsWith(q)) {
                    startsWithList.push(item);
                } else if (item.searchKey.indexOf(q) !== -1) {
                    containsList.push(item);
                }
            }
            filteredApps = startsWithList.concat(containsList);
        }

        if (selectedIndex >= filteredApps.length) {
            selectedIndex = Math.max(0, filteredApps.length - 1);
        } else {
            selectedIndex = 0;
        }

        if (appList.count > 0 && selectedIndex === 0) {
            appList.positionViewAtIndex(0, ListView.Beginning);
        }
    }

    function prepareClose() {
        active = false;
        searchInput.focus = false;
        root.focus = false;
    }

    function closeLauncher() {
        prepareClose();
        root.closeRequested();
    }

    function deleteSelectedClipboardItem() {
        if (!isClipboardMode) return;
        if (selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            var item = filteredApps[selectedIndex];
            if (item && item.isClipboard) {
                var prevIdx = selectedIndex;
                ClipboardService.removeEntry(item.id);
                if (filteredApps.length > 0) {
                    selectedIndex = Math.min(prevIdx, filteredApps.length - 1);
                }
            }
        }
    }

    function launchSelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            var item = filteredApps[selectedIndex];
            if (!item) return;

            prepareClose();
            root.appLaunched();

            if (item.isClipboard) {
                Qt.callLater(function() {
                    ClipboardService.copyItem(item);
                });
            } else if (item.isRemmina && item.filePath) {
                var targetFile = item.filePath;
                Qt.callLater(function() {
                    remminaLaunchProc.exec(["sh", "-c", "nohup remmina -c \"$1\" >/dev/null 2>&1 &", "sh", targetFile]);
                });
            } else if (item.entry) {
                var appEntry = item.entry;
                Qt.callLater(function() {
                    try {
                        appEntry.execute();
                    } catch (e) {
                        console.warn("Execution error:", e);
                    }
                });
            }
        }
    }

    function handleKeyNavigation(event) {
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
        } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier) && root.isClipboardMode) {
            if (event.modifiers & Qt.ControlModifier) {
                ClipboardService.clearAll();
            } else {
                root.deleteSelectedClipboardItem();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.launchSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.closeLauncher();
            event.accepted = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            active = true;
            reloadRemmina();
            searchInput.text = "";
            root.filterApps();
            searchInput.forceActiveFocus();
        } else {
            prepareClose();
        }
    }

    Keys.onPressed: event => root.handleKeyNavigation(event)

    Column {
        anchors.fill: parent
        spacing: 10

        // ================= SEARCH BOX =================
        Rectangle {
            width: parent.width
            height: 42
            radius: 10
            color: Theme.surface
            border.color: searchInput.activeFocus ? Theme.accent : Theme.border
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 120 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // Dynamic icon: magnifying glass in normal mode, remote server in "r:", clipboard in "v:"
                Text {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isClipboardMode ? "󰅌" : (root.isRemminaMode ? "󰢹" : "󰍉")
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 16
                    color: (root.isSpecialMode || searchInput.activeFocus) ? Theme.accent : Theme.textMuted

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Text input field
                TextInput {
                    id: searchInput
                    width: parent.width - searchIcon.width - (modeBadge.visible ? (modeBadge.width + 20) : 10)
                    anchors.verticalCenter: parent.verticalCenter
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
                        text: "Search apps ('r:' Remmina, 'v:' Clipboard)..."
                        font: parent.font
                        color: Theme.textMuted
                        opacity: 0.6
                        visible: !parent.text && !parent.inputMethodComposing
                    }

                    onTextChanged: {
                        if (root.active) {
                            root.filterApps();
                        }
                    }

                    Keys.onPressed: event => root.handleKeyNavigation(event)
                }

                // Visual indicator when Remmina or Clipboard module is active
                Rectangle {
                    id: modeBadge
                    visible: root.isSpecialMode
                    anchors.verticalCenter: parent.verticalCenter
                    width: badgeLabel.implicitWidth + 12
                    height: 20
                    radius: 6
                    color: Theme.surfaceActive
                    border.color: Theme.accent
                    border.width: 1

                    Text {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: root.isClipboardMode
                            ? ("CLIPBOARD" + (ClipboardService.count > 0 ? " • " + ClipboardService.count : ""))
                            : "REMMINA"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.accent
                    }
                }
            }
        }

        // ================= EMPTY STATE =================
        Item {
            width: parent.width
            height: parent.height - 52
            visible: root.filteredApps.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isClipboardMode ? "󰅌" : (root.isRemminaMode ? "󰢹" : "󰍉")
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 32
                    color: Theme.textMuted
                    opacity: 0.4
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isClipboardMode
                        ? "No clipboard items found"
                        : (root.isRemminaMode ? "No Remmina connections found" : "No applications found")
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 12
                    color: Theme.textMuted
                }
            }
        }

        // ================= ITEM LIST =================
        ListView {
            id: appList
            width: parent.width
            height: parent.height - 52
            clip: true
            spacing: 4
            model: root.filteredApps
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            interactive: root.active
            reuseItems: true
            cacheBuffer: 150
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

            // Smooth mouse wheel scrolling
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
                readonly property bool hasDesc: modelData && modelData.description !== ""

                width: appList.width - (vbar.visible ? 6 : 0)
                height: hasDesc ? 48 : 42
                radius: 8

                // Full row highlight
                color: isFocused ? Theme.surfaceActive : (rowMouse.containsMouse ? Theme.surfaceHover : "transparent")
                border.color: isFocused ? Theme.borderHover : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: 80 } }

                // Thin, centered vertical line (not reaching top and bottom edges)
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
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14 // Space for the vertical focus line
                    anchors.rightMargin: 10
                    spacing: 12

                    // Application, Remmina, or Clipboard icon
                    IconImage {
                        id: appIcon
                        width: 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        source: modelData ? modelData.icon : ""
                    }

                    // Title on the right and description right below
                    Column {
                        width: parent.width - appIcon.width - parent.spacing - 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: modelData ? modelData.name : ""
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: rowItem.isFocused ? Theme.textPrimary : Theme.textSecondary
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: modelData ? modelData.description : ""
                            visible: text !== ""
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 11
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: root.active
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (root.active) {
                            root.selectedIndex = index;
                        }
                    }
                    onClicked: {
                        root.selectedIndex = index;
                        root.launchSelected();
                    }
                }
            }
        }
    }
}
