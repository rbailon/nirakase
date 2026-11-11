//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."
import "island"
import "services"

ShellRoot {

    IpcHandler {
        id: ipcHandler
        target: "island"

        function toggleBar() {
            islandPill.currentMode === 0 ? rowBar.longBar ? rowBar.longBar = false : rowBar.longBar = true : islandPill.currentMode = 0
            Config.set("bar.longbar", rowBar.longBar)
        }

        function themes() {
            if (islandPill.currentMode === 2) {
                panelBase.closeThemes();
            } else {
                islandPill.currentMode = 2;
            }
        }

        function notifications() {
            controlCenter();
        }

        function controlCenter() {
            islandPill.currentMode === 3 ? islandPill.currentMode = 0 : islandPill.currentMode = 3;
        }

        function power() {
            if (islandPill.currentMode === 4) {
                panelBase.closePowerMenu();
            } else {
                islandPill.currentMode = 4;
            }
        }

        function powerMenu() {
            power();
        }

        function launcher() {
            islandPill.currentMode === 5 ? panelBase.closeLauncher() : islandPill.currentMode = 5;
        }

        function auth() {
            if (islandPill.currentMode === 6) {
                panelBase.closeAuth();
            } else {
                islandPill.previousMode = islandPill.currentMode;
                islandPill.currentMode = 6;
            }
        }

        // OSD Controls
        function volumeRaise()          { OsdService.volumeRaise(); }
        function volumeLower()          { OsdService.volumeLower(); }
        function volumeMute()           { OsdService.volumeMuteToggle(); }
        function micRaise()             { OsdService.micRaise(); }
        function micLower()             { OsdService.micLower(); }
        function micMute()              { OsdService.micMuteToggle(); }
        function brightnessUp()         { OsdService.brightnessRaise(); }
        function brightnessDown()       { OsdService.brightnessLower(); }
        function kbdBrightnessUp()      { OsdService.kbdBrightnessRaise(); }
        function kbdBrightnessDown()    { OsdService.kbdBrightnessLower(); }
        function capsLock()             { OsdService.checkCapsLock(); }
        function numLock()              { OsdService.checkNumLock(); }
        function powerProfileCycle()    { OsdService.powerProfileCycle(); }
        function powerProfileSet(p: string) { OsdService.powerProfileSet(p); }
        function idleToggle()           { IdleService.toggleInhibit(); }
        function mediaToggle()          { MediaService.togglePlaying(); }
        function mediaToggleExpanded()  { mediaIslandPill.expanded = !mediaIslandPill.expanded; }
        function mediaNext()            { MediaService.next(); }
        function mediaPrevious()        { MediaService.previous(); }
        function refreshUpdates()       { updatesWidget.refresh(); }
    }

    Timer {
        id: osdTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (islandPill.currentMode === 1) {
                islandPill.currentMode = islandPill.previousMode;
            }
        }
    }

    Connections {
        target: OsdService
        function onOsdTriggered() {
            if (islandPill.currentMode !== 1) {
                islandPill.previousMode = islandPill.currentMode;
                islandPill.currentMode = 1;
            }
            osdTimer.restart();
        }
    }

    Connections {
        target: PolkitService
        function onAuthRequested() {
            if (islandPill.currentMode !== 6) {
                islandPill.previousMode = islandPill.currentMode;
                islandPill.currentMode = 6;
            }
        }
        function onAuthCompleted(success) {
            if (islandPill.currentMode === 6) {
                islandPill.currentMode = (islandPill.previousMode === 6) ? 0 : islandPill.previousMode;
            }
        }
    }

    PanelWindow {
        id: panelBase
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (panelBase.modalWindowActive || panelBase.isTrayMenuOpen || islandPill.currentMode === 1) ? WlrLayershell.Overlay : WlrLayershell.Top

        readonly property bool isModal: (islandPill.currentMode === 2 || islandPill.currentMode === 3 || islandPill.currentMode === 4 || islandPill.currentMode === 5 || islandPill.currentMode === 6)
        readonly property bool isTrayMenuOpen: systemTrayWidget.menuOpen
        property bool modalWindowActive: isModal

        // Floating window overlap state per pill
        property var focusedWorkspaceId: null
        property var niriWindows: ({})
        property bool overlapLeft: false
        property bool overlapCenter: false
        property bool overlapRight: false

        readonly property bool hideLeft: overlapLeft && !isTrayMenuOpen && !isModal
        readonly property bool hideCenter: overlapCenter && !isModal && islandPill.currentMode === 0 && !(mediaIslandPill && mediaIslandPill.expanded)
        readonly property bool hideRight: overlapRight && !isModal

        function recalculateFloatingOverlaps() {
            var oLeft = false;
            var oCenter = false;
            var oRight = false;

            var topZoneHeight = islandPill.baseHeight + 8;
            var screenW = panelBase.width > 0 ? panelBase.width : 1920;

            var leftVisW = (pillLeft.width - pillLeft.radius) + 6;
            var rightVisW = (pillRight.width - pillRight.radius) + 6;
            var centerHalfW = (islandPill.width / 2) + 6;
            var centerLeftX = (screenW / 2) - centerHalfW;
            var centerRightX = (screenW / 2) + centerHalfW + ((mediaIslandPill && mediaIslandPill.active) ? (mediaIslandPill.width + 8) : 0);

            for (var idKey in panelBase.niriWindows) {
                var win = panelBase.niriWindows[idKey];
                if (!win || !win.is_floating) continue;
                if (panelBase.focusedWorkspaceId !== null && win.workspace_id !== panelBase.focusedWorkspaceId) continue;
                if (!win.layout || !win.layout.tile_pos_in_workspace_view) continue;

                var pos = win.layout.tile_pos_in_workspace_view;
                var sz = win.layout.tile_size || win.layout.window_size;
                if (!pos || !sz) continue;

                var off = win.layout.window_offset_in_tile || [0, 0];
                var wx = pos[0] + (off[0] || 0);
                var wy = pos[1] + (off[1] || 0);
                var ww = sz[0] || 0;
                var wh = sz[1] || 0;

                if (wy < topZoneHeight && (wy + wh) > 0) {
                    if (wx < leftVisW && (wx + ww) > 0) {
                        oLeft = true;
                    }
                    if (wx < centerRightX && (wx + ww) > centerLeftX) {
                        oCenter = true;
                    }
                    if (wBattery.hasBattery && wx < screenW && (wx + ww) > (screenW - rightVisW)) {
                        oRight = true;
                    }
                }
            }

            panelBase.overlapLeft = oLeft;
            panelBase.overlapCenter = oCenter;
            panelBase.overlapRight = oRight;
        }

        Process {
            id: niriFloatStream
            command: ["niri", "msg", "-j", "event-stream"]
            running: true
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    if (!data || data.trim() === "") return;
                    try {
                        var ev = JSON.parse(data);
                        if (ev.WorkspacesChanged && Array.isArray(ev.WorkspacesChanged.workspaces)) {
                            var wss = ev.WorkspacesChanged.workspaces;
                            for (var i = 0; i < wss.length; i++) {
                                if (wss[i].is_focused) {
                                    panelBase.focusedWorkspaceId = wss[i].id;
                                    break;
                                }
                            }
                            panelBase.recalculateFloatingOverlaps();
                        } else if (ev.WorkspaceActivated) {
                            if (ev.WorkspaceActivated.focused) {
                                panelBase.focusedWorkspaceId = ev.WorkspaceActivated.id;
                                panelBase.recalculateFloatingOverlaps();
                            }
                        } else if (ev.WindowsChanged && Array.isArray(ev.WindowsChanged.windows)) {
                            var map = {};
                            var wins = ev.WindowsChanged.windows;
                            for (var j = 0; j < wins.length; j++) {
                                map[wins[j].id] = wins[j];
                            }
                            panelBase.niriWindows = map;
                            panelBase.recalculateFloatingOverlaps();
                        } else if (ev.WindowOpenedOrChanged && ev.WindowOpenedOrChanged.window) {
                            var w = ev.WindowOpenedOrChanged.window;
                            panelBase.niriWindows[w.id] = w;
                            panelBase.recalculateFloatingOverlaps();
                        } else if (ev.WindowClosed) {
                            delete panelBase.niriWindows[ev.WindowClosed.id];
                            panelBase.recalculateFloatingOverlaps();
                        } else if (ev.WindowLayoutsChanged && Array.isArray(ev.WindowLayoutsChanged.changes)) {
                            var changes = ev.WindowLayoutsChanged.changes;
                            for (var k = 0; k < changes.length; k++) {
                                var winId = changes[k][0];
                                var newLayout = changes[k][1];
                                if (panelBase.niriWindows[winId]) {
                                    panelBase.niriWindows[winId].layout = newLayout;
                                }
                            }
                            panelBase.recalculateFloatingOverlaps();
                        }
                    } catch (e) {}
                }
            }
        }

        onIsModalChanged: {
            if (isModal) {
                if (systemTrayWidget.menuOpen) {
                    systemTrayWidget.closeMenu();
                }
                modalCloseTimer.stop();
                modalWindowActive = true;
            } else {
                modalCloseTimer.restart();
            }
        }

        Timer {
            id: modalCloseTimer
            interval: 220
            repeat: false
            onTriggered: {
                if (!panelBase.isModal) {
                    panelBase.modalWindowActive = false;
                }
            }
        }

        WlrLayershell.keyboardFocus: (isModal || isTrayMenuOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors { 
            top: true 
            left: true
            right: true
            bottom: panelBase.modalWindowActive || panelBase.isTrayMenuOpen
        }

        implicitHeight: Math.max(islandPill.height, mediaIslandPill ? mediaIslandPill.height : 0, pillLeft.height, pillRight.height) + 10
        color: "transparent"
        onWidthChanged: recalculateFloatingOverlaps()

        // Native Wayland zwp_idle_inhibit_manager_v1 protocol bound to the main window
        IdleInhibitor {
            enabled: IdleService.inhibited
            window: panelBase
        }

        mask: (panelBase.isModal || panelBase.isTrayMenuOpen) ? null : mainMaskRegion

        Region {
            id: mainMaskRegion
            Region {
                item: !panelBase.hideLeft ? pillLeft : null
            }
            Region {
                item: !panelBase.hideCenter ? islandPill : null
            }
            Region {
                item: (!panelBase.hideCenter && mediaIslandPill && mediaIslandPill.active) ? mediaIslandPill : null
                shape: (mediaIslandPill && mediaIslandPill.expanded) ? RegionShape.Rect : RegionShape.Ellipse
            }
            Region {
                item: (!panelBase.hideRight && wBattery.hasBattery) ? pillRight : null
            }
        }

        function closeThemes() {  
            islandPill.currentMode = 0;
        }

        function closeControlCenter() {
            islandPill.currentMode = 0;
        }

        function closePowerMenu() {
            islandPill.currentMode = 0;
        }

        function closeLauncher() {
            if (launcherWidget) {
                launcherWidget.prepareClose();
            }
            islandPill.currentMode = 0;
        }

        function closeAuth() {
            if (PolkitService.isActive) {
                PolkitService.cancel();
            }
            islandPill.currentMode = (islandPill.previousMode === 6) ? 0 : islandPill.previousMode;
        }

        // Dismiss modal or SystemTray menu on background click
        MouseArea {
            anchors.fill: parent
            enabled: panelBase.isModal || panelBase.isTrayMenuOpen
            acceptedButtons: Qt.AllButtons
            onPressed: {
                if (systemTrayWidget.menuOpen) {
                    systemTrayWidget.closeMenu();
                }
                if (islandPill.currentMode === 2) themesWidget.cancel();
                else if (islandPill.currentMode === 3) panelBase.closeControlCenter();
                else if (islandPill.currentMode === 4) panelBase.closePowerMenu();
                else if (islandPill.currentMode === 5) panelBase.closeLauncher();
                else if (islandPill.currentMode === 6) panelBase.closeAuth();
            }
        }

        Rectangle {
            id: islandPill
            anchors.top: parent.top
            anchors.topMargin: panelBase.hideCenter ? -(islandPill.height + 6) : 4
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on anchors.topMargin {
                NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
            }

            // Display modes: 0 = Bar, 1 = OSD, 2 = Themes, 3 = ControlCenter, 4 = PowerMenu, 5 = Launcher, 6 = Auth
            property int currentMode: 0
            property int previousMode: 0

            // Internal padding
            property int horizontalPadding: 14
            property int verticalPadding: 6

            // Base collapsed bar height (stable across modal expansions)
            readonly property real baseHeight: 22 + (verticalPadding * 2)

            // Strict clipping to maintain island pill boundary
            clip: true

            onCurrentModeChanged: {
                if (currentMode === 2) themesWidget.forceActiveFocus();
                else if (currentMode === 3) controlCenterWidget.forceActiveFocus();
                else if (currentMode === 4) powerMenuWidget.forceActiveFocus();
                else if (currentMode === 5) launcherWidget.forceActiveFocus();
                else if (currentMode === 6) authWidget.forceActiveFocus();
            }

            readonly property real targetContentWidth: {
                var w = 0;
                switch (currentMode) {
                    case 0: w = rowBar.implicitWidth; break;
                    case 1: w = osdWidget.implicitWidth; break;
                    case 2: w = themesWidget.implicitWidth; break;
                    case 3: w = controlCenterWidget.implicitWidth; break;
                    case 4: w = powerMenuWidget.implicitWidth; break;
                    case 5: w = launcherWidget.implicitWidth; break;
                    case 6: w = authWidget.implicitWidth; break;
                    default: w = rowBar.implicitWidth; break;
                }
                return w > 0 ? w : 100;
            }

            readonly property real targetContentHeight: {
                var h = 0;
                switch (currentMode) {
                    case 0: h = Math.max(22, rowBar.implicitHeight); break;
                    case 1: h = Math.max(22, rowBar.implicitHeight); break;
                    case 2: h = themesWidget.implicitHeight; break;
                    case 3: h = controlCenterWidget.implicitHeight; break;
                    case 4: h = powerMenuWidget.implicitHeight; break;
                    case 5: h = launcherWidget.implicitHeight; break;
                    case 6: h = authWidget.implicitHeight; break;
                    default: h = Math.max(22, rowBar.implicitHeight); break;
                }
                return h > 0 ? h : 30;
            }

            width: targetContentWidth + (horizontalPadding * 2)
            height: targetContentHeight + (verticalPadding * 2)
            radius: 16
            onWidthChanged: panelBase.recalculateFloatingOverlaps()

            color: Theme.background
            border.color: Theme.border
            border.width: 1

            // Pill resize animations
            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Behavior on height {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // Double left-click toggles longBar; right-click opens Control Center
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton && islandPill.currentMode === 0) {
                        islandPill.currentMode = 3;
                    }
                }
                onDoubleClicked: mouse => {
                    if (mouse.button === Qt.LeftButton && islandPill.currentMode === 0) {
                        rowBar.longBar = !rowBar.longBar;
                        Config.set("bar.longbar", rowBar.longBar);
                    }
                }
            }

            // Clipped content container
            Item {
                id: contentContainer
                anchors.fill: parent
                clip: true

                // Mode 0: Main bar
                Item {
                    id: mode0Wrapper
                    anchors.centerIn: parent
                    implicitWidth: rowBar.implicitWidth
                    implicitHeight: Math.max(22, rowBar.implicitHeight)
                    width: implicitWidth
                    height: implicitHeight

                    visible: opacity > 0.01
                    opacity: islandPill.currentMode === 0 ? 1.0 : 0.0
                    scale: islandPill.currentMode === 0 ? 1.0 : 0.75
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

                    RowLayout {
                        id: rowBar
                        anchors.centerIn: parent
                        property bool longBar: Config.bar.longbar
                        spacing: 15

                        WorkspacesWidget {
                            id: workspacesCompact
                            Layout.alignment: Qt.AlignCenter
                            onDoubleClicked: {
                                rowBar.longBar = !rowBar.longBar;
                                Config.set("bar.longbar", rowBar.longBar);
                            }
                        }

                        CollapsibleItem {
                            expanded: rowBar.longBar

                            RowLayout {
                                id: statusRow
                                anchors.centerIn: parent
                                spacing: 1

                                IdleWidget {
                                    onOpenRequested: {
                                        if (islandPill.currentMode === 3 && !IdleService.idlePanelOpen) {
                                            panelBase.closeControlCenter();
                                        } else {
                                            islandPill.currentMode = 3;
                                        }
                                    }
                                }
                                UpdatesWidget { id: updatesWidget }
                                NotificationsWidget {
                                    onOpenRequested: islandPill.currentMode === 3 ? islandPill.currentMode = 0 : islandPill.currentMode = 3
                                }
                            }
                        }

                        CollapsibleItem {
                            expanded: rowBar.longBar

                            RowLayout {
                                spacing: 1

                                BluetoothWidget {
                                    Layout.alignment: Qt.AlignCenter
                                    onOpenRequested: {
                                        AudioService.audioPanelOpen = false;
                                        if (islandPill.currentMode === 3 && !BluetoothService.btPanelOpen) {
                                            panelBase.closeControlCenter();
                                        } else {
                                            islandPill.currentMode = 3;
                                        }
                                    }
                                }
                                NetworkWidget {
                                    Layout.alignment: Qt.AlignCenter
                                    onOpenRequested: {
                                        BluetoothService.btPanelOpen = false;
                                        AudioService.audioPanelOpen = false;
                                        if (islandPill.currentMode === 3 && !NetworkService.wifiPanelOpen) {
                                            panelBase.closeControlCenter();
                                        } else {
                                            islandPill.currentMode = 3;
                                        }
                                    }
                                }
                                AudioWidget {
                                    Layout.alignment: Qt.AlignCenter
                                    onOpenRequested: {
                                        NetworkService.wifiPanelOpen = false;
                                        BluetoothService.btPanelOpen = false;
                                        if (islandPill.currentMode === 3 && !AudioService.audioPanelOpen) {
                                            panelBase.closeControlCenter();
                                        } else {
                                            islandPill.currentMode = 3;
                                        }
                                    }
                                }
                                SystemWidget { Layout.alignment: Qt.AlignCenter }
                            }
                        }
                    }
                }

                // Mode 1: OSD
                OsdWidget {
                    id: osdWidget
                    anchors.centerIn: parent
                    visible: opacity > 0.01
                    opacity: islandPill.currentMode === 1 ? 1.0 : 0.0
                    scale: islandPill.currentMode === 1 ? 1.0 : 0.75
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                }

                // Mode 2: Themes
                ThemesWidget {
                    id: themesWidget
                    anchors.centerIn: parent
                    visible: opacity > 0.01
                    opacity: islandPill.currentMode === 2 ? 1.0 : 0.0
                    scale: islandPill.currentMode === 2 ? 1.0 : 0.3
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

                    onThemeSelected: panelBase.closeThemes()
                    onCloseRequested: panelBase.closeThemes()
                }

                // Mode 3: Control Center
                ControlCenterWidget {
                    id: controlCenterWidget
                    anchors.centerIn: parent
                    visible: opacity > 0.01
                    opacity: islandPill.currentMode === 3 ? 1.0 : 0.0
                    scale: islandPill.currentMode === 3 ? 1.0 : 0.3
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

                    onCloseRequested: panelBase.closeControlCenter()
                }

                // Mode 4: Power menu
                PowerMenuWidget {
                    id: powerMenuWidget
                    anchors.centerIn: parent
                    visible: opacity > 0.01
                    opacity: islandPill.currentMode === 4 ? 1.0 : 0.0
                    scale: islandPill.currentMode === 4 ? 1.0 : 0.3
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

                    onActionExecuted: panelBase.closePowerMenu()
                    onCloseRequested: panelBase.closePowerMenu()
                }

                // Mode 5: Launcher
                LauncherWidget {
                    id: launcherWidget
                    anchors.centerIn: parent
                    visible: opacity > 0.01
                    opacity: islandPill.currentMode === 5 ? 1.0 : 0.0
                    scale: islandPill.currentMode === 5 ? 1.0 : 0.3
                    transformOrigin: Item.Center

                    Behavior on opacity { 
                        NumberAnimation { 
                            duration: islandPill.currentMode === 5 ? 200 : 130
                            easing.type: Easing.OutCubic 
                        } 
                    }
                    Behavior on scale { 
                        NumberAnimation { 
                            duration: islandPill.currentMode === 5 ? 220 : 150
                            easing.type: Easing.OutCubic 
                        } 
                    }

                    onAppLaunched: panelBase.closeLauncher()
                    onCloseRequested: panelBase.closeLauncher()
                }

                // Mode 6: Authentication
                AuthWidget {
                    id: authWidget
                    anchors.centerIn: parent
                    visible: opacity > 0.01
                    opacity: islandPill.currentMode === 6 ? 1.0 : 0.0
                    scale: islandPill.currentMode === 6 ? 1.0 : 0.3
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

                    onCloseRequested: panelBase.closeAuth()
                    onAuthenticated: panelBase.closeAuth()
                }
            }
        }

        MediaIsland {
            id: mediaIslandPill
            anchors.top: islandPill.top
            anchors.left: islandPill.right
            anchors.leftMargin: 8
            targetHeight: islandPill.baseHeight
            onWidthChanged: panelBase.recalculateFloatingOverlaps()
            onActiveChanged: panelBase.recalculateFloatingOverlaps()
        }

        Rectangle {
            id: pillLeft
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.leftMargin: panelBase.hideLeft ? -(pillLeft.width + 2) : -radius

            property int horizontalPadding: 14
            property int verticalPadding: 6

            width: radius + leftPillRow.implicitWidth + (horizontalPadding * 2)
            height: islandPill.baseHeight
            radius: 16

            color: Theme.background
            border.color: Theme.border
            border.width: 1

            onWidthChanged: panelBase.recalculateFloatingOverlaps()

            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
            }

            HoverHandler {
                id: leftPillHover
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: {
                    if (systemTrayWidget.menuOpen) {
                        systemTrayWidget.closeMenu();
                    }
                }
                onDoubleClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        rowBar.longBar = !rowBar.longBar;
                        Config.set("bar.longbar", rowBar.longBar);
                    }
                }
            }

            RowLayout {
                id: leftPillRow
                anchors.left: parent.left
                anchors.leftMargin: pillLeft.radius + pillLeft.horizontalPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                DateTimeWidget {
                    id: dateTimeWidget
                    Layout.alignment: Qt.AlignVCenter

                    onClicked: {
                        if (systemTrayWidget.menuOpen) {
                            systemTrayWidget.closeMenu();
                        }
                    }

                    onDoubleClicked: {
                        rowBar.longBar = !rowBar.longBar;
                        Config.set("bar.longbar", rowBar.longBar);
                    }
                }

                SystemTrayWidget {
                    id: systemTrayWidget
                    pillHovered: leftPillHover.hovered
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        Rectangle {
            id: pillRight
            visible: wBattery.hasBattery
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.right: parent.right
            anchors.rightMargin: panelBase.hideRight ? -(pillRight.width + 2) : -radius

            property int horizontalPadding: 14
            property int verticalPadding: 6

            width: radius + wBattery.implicitWidth + (horizontalPadding * 2)
            height: islandPill.baseHeight
            radius: 16

            color: Theme.background
            border.color: Theme.border
            border.width: 1

            onWidthChanged: panelBase.recalculateFloatingOverlaps()

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Behavior on anchors.rightMargin {
                NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        islandPill.currentMode === 3 ? panelBase.closeControlCenter() : islandPill.currentMode = 3;
                    } else if (mouse.button === Qt.RightButton) {
                        OsdService.powerProfileCycle();
                    }
                }
            }

            BatteryWidget {
                id: wBattery
                anchors.right: parent.right
                anchors.rightMargin: pillRight.radius + pillRight.horizontalPadding
                anchors.verticalCenter: parent.verticalCenter

                onClicked: islandPill.currentMode === 3 ? panelBase.closeControlCenter() : islandPill.currentMode = 3
            }
        }
    }

    NotificationPopup {}
}
