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

    PanelWindow {
        id: panelBase
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayershell.Top
        // WlrLayershell.keyboardFocus: (islandPill.currentMode === 2 || islandPill.currentMode === 3 || islandPill.currentMode === 4) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.keyboardFocus: (islandPill.currentMode === 2 || islandPill.currentMode === 3 || islandPill.currentMode === 4 || islandPill.currentMode === 5) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors { 
            top: true 
            left: true
            right: true
            // bottom: islandPill.currentMode === 2 || islandPill.currentMode === 3 || islandPill.currentMode === 4
            bottom: islandPill.currentMode === 2 || islandPill.currentMode === 3 || islandPill.currentMode === 4 || islandPill.currentMode === 5
        }

        implicitHeight: islandPill.height + 10
        color: "transparent"

        mask: (islandPill.currentMode === 2 || islandPill.currentMode === 3 || islandPill.currentMode === 4) ? null : pillRegion

        Region {
            id: pillRegion
            item: islandPill
        }

        function closeThemes() {  
            islandPill.currentMode = 0;
        }

        function closeNotifications() {
            islandPill.currentMode = 0;
        }

        function closePowerMenu() {
            islandPill.currentMode = 0;
        }

        function closeLauncher() {
            islandPill.currentMode = 0;
        }

        // Dismiss modal on background click
        MouseArea {
            anchors.fill: parent
            enabled: islandPill.currentMode === 2 || islandPill.currentMode === 3 || islandPill.currentMode === 4
            onClicked: {
                if (islandPill.currentMode === 2) themesWidget.cancel();
                else if (islandPill.currentMode === 3) panelBase.closeNotifications();
                else if (islandPill.currentMode === 4) panelBase.closePowerMenu();
                else if (islandPill.currentMode === 5) panelBase.closeLauncher();
            }
        }

        Rectangle {
            id: islandPill
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter

            // Display modes: 0 = Bar, 1 = OSD, 2 = Themes, 3 = Notifications, 4 = PowerMenu, 5 = Launcher
            property int currentMode: 0
            property int previousMode: 0

            // Internal padding
            property int horizontalPadding: 14
            property int verticalPadding: 6

            // Strict clipping to maintain island pill boundary
            clip: true

            onCurrentModeChanged: {
                if (currentMode === 2) themesWidget.forceActiveFocus();
                else if (currentMode === 4) powerMenuWidget.forceActiveFocus();
            }

            readonly property real targetContentWidth: {
                var w = 0;
                switch (currentMode) {
                    case 0: w = rowBar.implicitWidth; break;
                    case 1: w = osdWidget.implicitWidth; break;
                    case 2: w = themesWidget.implicitWidth; break;
                    case 3: w = notificationCenterWidget.implicitWidth; break;
                    case 4: w = powerMenuWidget.implicitWidth; break;
                    case 5: w = launcherWidget.implicitWidth; break;
                    default: w = rowBar.implicitWidth; break;
                }
                return w > 0 ? w : 100;
            }

            readonly property real targetContentHeight: {
                var h = 0;
                switch (currentMode) {
                    case 0: h = rowBar.implicitHeight; break;
                    case 1: h = osdWidget.implicitHeight; break;
                    case 2: h = themesWidget.implicitHeight; break;
                    case 3: h = notificationCenterWidget.implicitHeight; break;
                    case 4: h = powerMenuWidget.implicitHeight; break;
                    case 5: h = launcherWidget.implicitHeight; break;
                    default: h = rowBar.implicitHeight; break;
                }
                return h > 0 ? h : 30;
            }

            width: targetContentWidth + (horizontalPadding * 2)
            height: targetContentHeight + (verticalPadding * 2)
            radius: 16

            color: Theme.background
            border.color: Theme.border
            border.width: 1

            // Pill resize animations
            Behavior on width {
                NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
            }

            Behavior on height {
                NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
            }

            // Prevent click propagation through pill body
            MouseArea {
                anchors.fill: parent
                onClicked: {}
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
                    implicitHeight: rowBar.implicitHeight
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

                        CollapsibleItem {
                            expanded: rowBar.longBar

                            WorkspacesWidget {
                                id: workspacesCompact
                                embedMode: true
                                Layout.alignment: Qt.AlignCenter
                            }
                        }

                        CollapsibleItem {
                            expanded: true

                            DateTimeWidget {
                                id: dateTimeWidget
                                Layout.alignment: Qt.AlignCenter
                            }
                        }

                        CollapsibleItem {
                            expanded: rowBar.longBar

                            RowLayout {
                                id: statusRow
                                anchors.centerIn: parent
                                spacing: 1

                                IdleWidget {}
                                UpdatesWidget {}
                                NotificationsWidget {
                                    onOpenRequested: islandPill.currentMode === 3 ? islandPill.currentMode = 0 : islandPill.currentMode = 3
                                }
                            }
                        }

                        CollapsibleItem {
                            expanded: rowBar.longBar

                            RowLayout {
                                spacing: 1

                                BluetoothWidget { Layout.alignment: Qt.AlignCenter }
                                WifiWidget { Layout.alignment: Qt.AlignCenter }
                                AudioWidget { Layout.alignment: Qt.AlignCenter }
                                SystemWidget { Layout.alignment: Qt.AlignCenter }
                            }
                        }

                        CollapsibleItem {
                            expanded: rowBar.longBar || wBattery.percentage < 40

                            RowLayout {
                                spacing: 0
                                BatteryWidget { id: wBattery }
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

                // Mode 3: Notifications
                NotificationCenterWidget {
                    id: notificationCenterWidget
                    anchors.centerIn: parent
                    visible: opacity > 0.01
                    opacity: islandPill.currentMode === 3 ? 1.0 : 0.0
                    scale: islandPill.currentMode === 3 ? 1.0 : 0.3
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

                    onCloseRequested: panelBase.closeNotifications()
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

                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

                    onAppLaunched: panelBase.closeLauncher()
                    onCloseRequested: panelBase.closeLauncher()
                }
            }
        }
    }

    NotificationPopup {}
}
