import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../components"
import ".."

Item {
    id: root
    focus: menuOpen

    // External hover state from parent pill (dateTimePill)
    property bool pillHovered: false

    // Allows user to pin the drawer open by clicking the chevron indicator
    property bool pinnedExpanded: false

    // Currently open context menu state
    property var activeDelegate: null
    readonly property var activeMenuItem: activeDelegate ? activeDelegate.modelData : null
    readonly property bool menuOpen: activeMenuItem !== null && activeMenuItem.hasMenu && rootMenuOpener.children.values.length > 0

    // Effective expanded state: open on hover, when pinned, when a menu is open, or when an app needs attention
    property bool hoveredState: false
    readonly property bool drawerExpanded: hoveredState || pinnedExpanded || menuOpen || hasNeedsAttention

    readonly property var trayItems: SystemTray.items ? SystemTray.items.values : []
    readonly property int trayCount: trayItems ? trayItems.length : 0

    readonly property bool hasNeedsAttention: {
        if (!trayItems) return false;
        for (var i = 0; i < trayItems.length; i++) {
            var it = trayItems[i];
            if (it && it.status === Status.NeedsAttention) {
                return true;
            }
        }
        return false;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.activeDelegate !== null) {
            root.closeMenu();
            event.accepted = true;
        }
    }

    onTrayCountChanged: {
        if (trayCount === 0) {
            root.pinnedExpanded = false;
            root.hoveredState = false;
            root.closeMenu();
        }
    }

    function updateHoverState() {
        if (root.pillHovered || trayHover.hovered || menuHover.hovered || root.menuOpen) {
            collapseTimer.stop();
            root.hoveredState = true;
        } else {
            collapseTimer.restart();
        }
    }

    onPillHoveredChanged: updateHoverState()
    onMenuOpenChanged: {
        updateHoverState();
        if (menuOpen) {
            root.forceActiveFocus();
        }
    }

    Timer {
        id: collapseTimer
        interval: 280
        repeat: false
        onTriggered: {
            if (!root.pillHovered && !trayHover.hovered && !menuHover.hovered && !root.menuOpen) {
                root.hoveredState = false;
            }
        }
    }

    function toggleMenu(delegateItem) {
        if (root.activeDelegate === delegateItem) {
            root.closeMenu();
        } else {
            root.activeDelegate = delegateItem;
            if (delegateItem && delegateItem.modelData && delegateItem.modelData.menu && delegateItem.modelData.menu.menu) {
                try {
                    delegateItem.modelData.menu.menu.opened();
                } catch (e) {}
            }
            root.forceActiveFocus();
        }
    }

    function closeMenu() {
        if (root.activeDelegate && root.activeDelegate.modelData && root.activeDelegate.modelData.menu && root.activeDelegate.modelData.menu.menu) {
            try {
                root.activeDelegate.modelData.menu.menu.closed();
            } catch (e) {}
        }
        root.activeDelegate = null;
    }

    function cleanMenuText(rawText) {
        if (!rawText) return "";
        return String(rawText)
            .replace(/(^|[^_])_([^_])/g, "$1$2")
            .replace(/__/g, "_")
            .replace(/(^|[^&])&([^&])/g, "$1$2")
            .replace(/&&/g, "&");
    }

    HoverHandler {
        id: trayHover
        onHoveredChanged: root.updateHoverState()
    }

    visible: trayCount > 0
    implicitWidth: visible ? mainRow.implicitWidth : 0
    implicitHeight: visible ? mainRow.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.alignment: Qt.AlignVCenter

    // Themed DBusMenu using QsMenuOpener
    QsMenuOpener {
        id: rootMenuOpener
        menu: (root.activeMenuItem && root.activeMenuItem.hasMenu) ? root.activeMenuItem.menu : null
    }

    // Context menu card rendered directly inside the layer window for reliable Escape & click-outside handling
    Rectangle {
        id: menuCard
        visible: opacity > 0.01
        opacity: root.menuOpen ? 1.0 : 0.0
        scale: root.menuOpen ? 1.0 : 0.92
        transformOrigin: Item.Top
        z: 200

        x: {
            if (!root.activeDelegate) return 0;
            var pos = root.activeDelegate.mapToItem(root, root.activeDelegate.width / 2, 0);
            var targetX = pos.x - (width / 2);
            var minX = -root.x + 6;
            return Math.max(minX, targetX);
        }
        y: root.height + 10

        implicitWidth: Math.max(170, Math.min(280, menuColumn.implicitWidth + 16))
        implicitHeight: menuColumn.implicitHeight + 14
        width: implicitWidth
        height: implicitHeight
        radius: 12
        color: Theme.background
        border.color: Theme.border
        border.width: 1

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: menuHover
            onHoveredChanged: root.updateHoverState()
        }

        // Prevent clicks inside menuCard background from propagating to the outside-click catcher
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => { mouse.accepted = true; }
        }

        ColumnLayout {
            id: menuColumn
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 2

            Repeater {
                model: rootMenuOpener.children

                delegate: ColumnLayout {
                    id: entryWrapper
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2

                    property bool submenuExpanded: false

                    Connections {
                        target: root
                        function onMenuOpenChanged() {
                            if (!root.menuOpen) {
                                entryWrapper.submenuExpanded = false;
                            }
                        }
                    }

                    // Separator item
                    Rectangle {
                        visible: entryWrapper.modelData && entryWrapper.modelData.isSeparator
                        Layout.fillWidth: true
                        Layout.topMargin: 3
                        Layout.bottomMargin: 3
                        height: 1
                        color: Theme.border
                    }

                    // Standard or submenu action item
                    Rectangle {
                        id: entryBtn
                        visible: entryWrapper.modelData && !entryWrapper.modelData.isSeparator && entryWrapper.modelData.text !== ""
                        Layout.fillWidth: true
                        implicitWidth: entryRow.implicitWidth + 16
                        implicitHeight: 26
                        radius: 6
                        color: {
                            if (!entryWrapper.modelData || !entryWrapper.modelData.enabled) return "transparent";
                            if (entryMouse.pressed) return Theme.surfaceActive;
                            if (entryMouse.containsMouse) return Theme.surfaceHover;
                            return "transparent";
                        }

                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            id: entryRow
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // Optional Checkbox / Radio indicator
                            Text {
                                visible: entryWrapper.modelData && entryWrapper.modelData.buttonType !== QsMenuButtonType.None
                                text: {
                                    if (!entryWrapper.modelData) return "";
                                    if (entryWrapper.modelData.buttonType === QsMenuButtonType.RadioButton) {
                                        return entryWrapper.modelData.checkState === Qt.Checked ? "󰄯" : "󰄰";
                                    }
                                    return entryWrapper.modelData.checkState === Qt.Checked ? "󰄲" : "󰄱";
                                }
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 12
                                color: Theme.accent
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Optional item icon
                            IconImage {
                                visible: entryWrapper.modelData && entryWrapper.modelData.icon !== ""
                                implicitSize: 13
                                width: 13
                                height: 13
                                source: (entryWrapper.modelData && entryWrapper.modelData.icon) ? entryWrapper.modelData.icon : ""
                                mipmap: true
                                opacity: (entryWrapper.modelData && entryWrapper.modelData.enabled) ? 1.0 : 0.45
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Item label
                            Text {
                                Layout.fillWidth: true
                                text: entryWrapper.modelData ? root.cleanMenuText(entryWrapper.modelData.text) : ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: (entryWrapper.modelData && entryWrapper.modelData.enabled) ? Theme.textPrimary : Theme.textMuted
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Submenu arrow if hasChildren
                            Text {
                                visible: entryWrapper.modelData && entryWrapper.modelData.hasChildren
                                text: entryWrapper.submenuExpanded ? "󰅀" : "󰅂"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entryWrapper.modelData ? entryWrapper.modelData.enabled : false
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                var entry = entryWrapper.modelData;
                                if (!entry || !entry.enabled) return;
                                if (entry.hasChildren) {
                                    entryWrapper.submenuExpanded = !entryWrapper.submenuExpanded;
                                    if (entryWrapper.submenuExpanded) {
                                        entry.opened();
                                    } else {
                                        entry.closed();
                                    }
                                } else {
                                    entry.triggered();
                                    root.closeMenu();
                                }
                            }
                        }
                    }

                    // Inline collapsible submenu
                    QsMenuOpener {
                        id: subMenuOpener
                        menu: (entryWrapper.modelData && entryWrapper.modelData.hasChildren && entryWrapper.submenuExpanded)
                            ? entryWrapper.modelData
                            : null
                    }

                    Rectangle {
                        visible: entryWrapper.submenuExpanded && subMenuOpener.children.values.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        implicitHeight: subCol.implicitHeight + 8
                        radius: 6
                        color: Theme.surface
                        border.color: Theme.border
                        border.width: 1

                        ColumnLayout {
                            id: subCol
                            anchors.centerIn: parent
                            width: parent.width - 8
                            spacing: 2

                            Repeater {
                                model: subMenuOpener.children

                                delegate: Rectangle {
                                    id: subItem
                                    required property var modelData
                                    visible: !modelData.isSeparator && modelData.text !== ""
                                    Layout.fillWidth: true
                                    implicitWidth: subItemText.implicitWidth + 14
                                    implicitHeight: 24
                                    radius: 5
                                    color: subMouse.containsMouse && modelData.enabled ? Theme.surfaceHover : "transparent"

                                    Text {
                                        id: subItemText
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        text: root.cleanMenuText(subItem.modelData.text)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        color: subItem.modelData.enabled ? Theme.textPrimary : Theme.textMuted
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: subMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: subItem.modelData.enabled
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (!subItem.modelData.enabled) return;
                                            subItem.modelData.triggered();
                                            root.closeMenu();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: mainRow
        anchors.centerIn: parent
        spacing: 5

        // Vertical separator matching DateTimeWidget's '│'
        Text {
            text: "│"
            color: Theme.border
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            Layout.alignment: Qt.AlignVCenter
            topPadding: 2
            bottomPadding: 2
        }

        // Auto-expanding drawer on hover
        CollapsibleItem {
            id: trayDrawer
            expanded: root.drawerExpanded && root.trayCount > 0
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: iconsRow
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        id: trayDelegate

                        required property SystemTrayItem modelData

                        implicitWidth: 20
                        implicitHeight: 20

                        readonly property bool needsAttention: modelData && modelData.status === Status.NeedsAttention
                        readonly property bool isMenuActive: root.activeDelegate === trayDelegate
                        readonly property string itemTooltip: {
                            if (!modelData) return "";
                            var t = modelData.tooltipTitle || modelData.title || modelData.id || "";
                            var d = modelData.tooltipDescription || "";
                            if (t && d && d !== t) return t + "\n" + d;
                            return t || d;
                        }

                        Timer {
                            id: tipTimer
                            interval: 350
                            repeat: false
                            onTriggered: {
                                if (itemMouse.containsMouse && trayDelegate.itemTooltip !== "" && !root.menuOpen) {
                                    tipPopup.visible = true;
                                }
                            }
                        }

                        PopupWindow {
                            id: tipPopup
                            anchor.item: trayBtnFrame
                            anchor.edges: Edges.Bottom
                            anchor.gravity: Edges.Bottom
                            anchor.margins.top: 6
                            visible: false
                            color: "transparent"

                            implicitWidth: tipBubble.implicitWidth + 8
                            implicitHeight: tipBubble.implicitHeight + 8

                            Rectangle {
                                id: tipBubble
                                anchors.centerIn: parent
                                implicitWidth: tipText.implicitWidth + 14
                                implicitHeight: tipText.implicitHeight + 8
                                color: Theme.surface ? Theme.surface : "#18181B"
                                border.color: Theme.surfaceActive ? Theme.surfaceActive : "#3F3F46"
                                border.width: 1
                                radius: 6

                                Text {
                                    id: tipText
                                    anchors.centerIn: parent
                                    font.family: "JetBrainsMono Nerd Font Propo"
                                    font.pixelSize: 10
                                    color: Theme.textPrimary ? Theme.textPrimary : "#F4F4F5"
                                    text: trayDelegate.itemTooltip
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        Rectangle {
                            id: trayBtnFrame
                            anchors.fill: parent
                            radius: 5
                            color: itemMouse.pressed
                                ? "#35ffffff"
                                : ((itemMouse.containsMouse || trayDelegate.isMenuActive) ? "#1affffff" : "transparent")
                            border.color: trayDelegate.isMenuActive ? Theme.accent : "transparent"
                            border.width: 1
                            scale: itemMouse.pressed ? 0.88 : 1.0

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 14
                                width: 14
                                height: 14
                                source: trayDelegate.modelData ? (trayDelegate.modelData.icon || "") : ""
                                mipmap: true
                                opacity: (trayDelegate.modelData && trayDelegate.modelData.status === Status.Passive) ? 0.65 : 1.0
                            }

                            // Warning dot if the icon requires attention
                            Rectangle {
                                visible: trayDelegate.needsAttention
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 1
                                anchors.rightMargin: 1
                                width: 5
                                height: 5
                                radius: 2.5
                                color: Theme.warning || "#F59E0B"
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                                onContainsMouseChanged: {
                                    if (containsMouse && trayDelegate.itemTooltip !== "" && !root.menuOpen) {
                                        tipTimer.restart();
                                    } else {
                                        tipTimer.stop();
                                        tipPopup.visible = false;
                                    }
                                }

                                onClicked: mouse => {
                                    tipTimer.stop();
                                    tipPopup.visible = false;
                                    var item = trayDelegate.modelData;
                                    if (!item) return;

                                    if (mouse.button === Qt.LeftButton) {
                                        if (item.onlyMenu && item.hasMenu) {
                                            root.toggleMenu(trayDelegate);
                                        } else {
                                            root.closeMenu();
                                            item.activate();
                                        }
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (item.hasMenu) {
                                            root.toggleMenu(trayDelegate);
                                        } else {
                                            item.secondaryActivate();
                                        }
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        root.closeMenu();
                                        item.secondaryActivate();
                                    }
                                }

                                onWheel: wheel => {
                                    var item = trayDelegate.modelData;
                                    if (!item) return;
                                    if (wheel.angleDelta.y !== 0) {
                                        item.scroll(wheel.angleDelta.y, false);
                                    } else if (wheel.angleDelta.x !== 0) {
                                        item.scroll(wheel.angleDelta.x, true);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Discrete chevron indicator (󰅂 collapsed / 󰅁 expanded)
        Item {
            id: chevronIndicator
            implicitWidth: 14
            implicitHeight: 20
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.drawerExpanded ? "󰅁" : "󰅂"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 13
                color: {
                    if (root.hasNeedsAttention) return Theme.warning || "#F59E0B";
                    if (root.pinnedExpanded || root.menuOpen) return Theme.accent;
                    return root.drawerExpanded ? Theme.textPrimary : Theme.textSecondary;
                }

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Attention dot when collapsed
            Rectangle {
                visible: !root.drawerExpanded && root.hasNeedsAttention
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 2
                width: 5
                height: 5
                radius: 2.5
                color: Theme.warning || "#F59E0B"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: {
                    if (root.menuOpen) {
                        root.closeMenu();
                    } else {
                        root.pinnedExpanded = !root.pinnedExpanded;
                    }
                }
            }
        }
    }
}
