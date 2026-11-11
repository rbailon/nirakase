import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import ".."
import "../services"

FocusScope {
    id: root

    implicitWidth: 420
    implicitHeight: mainLayout.implicitHeight + 24
    width: implicitWidth
    height: implicitHeight
    focus: true

    signal closeRequested()
    signal authenticated()

    property bool showPassword: false
    property string localError: ""

    function submitPassword() {
        if (PolkitService.isSubmitting) return;
        localError = "";
        PolkitService.submit(passwordInput.text);
    }

    function cancel() {
        localError = "";
        passwordInput.text = "";
        root.closeRequested();
    }

    function resetAndFocus() {
        passwordInput.text = "";
        localError = "";
        showPassword = false;
        passwordInput.forceActiveFocus();
        root.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) {
            root.resetAndFocus();
        }
    }

    Connections {
        target: PolkitService
        function onAuthRequested() {
            root.resetAndFocus();
        }

        function onAuthFailed(err) {
            localError = err;
            passwordInput.text = "";
            shakeAnim.restart();
            passwordInput.forceActiveFocus();
        }

        function onAuthCompleted(success) {
            if (success) {
                root.authenticated();
            }
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.cancel();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submitPassword();
            event.accepted = true;
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        // ================= HEADER =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 10
                color: Theme.surfaceActive
                border.color: Theme.border
                border.width: 1

                IconImage {
                    id: headerAppIcon
                    anchors.centerIn: parent
                    implicitWidth: 20
                    implicitHeight: 20
                    source: {
                        if (PolkitService.iconName !== "") {
                            var p = Quickshell.iconPath(PolkitService.iconName, true);
                            if (p !== "") return p;
                        }
                        return "";
                    }
                    visible: source !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰌾"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 16
                    color: Theme.accent
                    visible: !headerAppIcon.visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Authentication Required"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: PolkitService.actionId !== "" ? PolkitService.actionId : "Polkit Security Agent"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Close button
            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 6
                color: closeMouse.containsMouse ? Theme.surfaceHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 13
                    color: closeMouse.containsMouse ? Theme.textPrimary : Theme.textMuted
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancel()
                }
            }
        }

        // ================= ACTION MESSAGE =================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: msgText.implicitHeight + 16
            radius: 8
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Text {
                id: msgText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                text: PolkitService.message !== "" ? PolkitService.message : "Administrator privileges are required to perform this action."
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: Theme.textSecondary
                wrapMode: Text.Wrap
            }
        }

        // ================= USER IDENTITY =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: PolkitService.identities.length > 0

            Text {
                text: "User:"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: Theme.textMuted
            }

            // Single user badge or multiple user chips
            RowLayout {
                spacing: 6

                Repeater {
                    model: PolkitService.identities

                    delegate: Rectangle {
                        readonly property bool isCurrent: PolkitService.selectedIdentity === modelData || (PolkitService.identities.length === 1)

                        implicitWidth: idRow.implicitWidth + 14
                        implicitHeight: 24
                        radius: 6
                        color: isCurrent ? Theme.surfaceActive : Theme.surface
                        border.color: isCurrent ? Theme.accent : Theme.border
                        border.width: 1

                        RowLayout {
                            id: idRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: "󰮯"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 11
                                color: isCurrent ? Theme.accent : Theme.textMuted
                            }

                            Text {
                                text: modelData ? (modelData.displayName || "admin") : "root"
                                font.family: "JetBrainsMono Nerd Font Propo"
                                font.pixelSize: 11
                                font.weight: isCurrent ? Font.Bold : Font.Normal
                                color: isCurrent ? Theme.textPrimary : Theme.textSecondary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: PolkitService.identities.length > 1
                            onClicked: PolkitService.selectIdentity(modelData)
                        }
                    }
                }
            }
        }

        // ================= ERROR / STATUS BANNER =================
        Rectangle {
            id: errorBanner
            Layout.fillWidth: true
            implicitHeight: hasError ? (errorRow.implicitHeight + 12) : 0
            radius: 6
            color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15)
            border.color: Theme.danger
            border.width: 1
            visible: hasError

            readonly property bool hasError: localError !== "" || (PolkitService.supplementaryMessage !== "" && PolkitService.supplementaryIsError)
            readonly property string currentErrorText: {
                if (localError !== "") return localError;
                if (PolkitService.supplementaryMessage !== "" && PolkitService.supplementaryIsError) {
                    return PolkitService.supplementaryMessage;
                }
                return "";
            }

            Behavior on implicitHeight { NumberAnimation { duration: 150 } }

            RowLayout {
                id: errorRow
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "󰅚"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 13
                    color: Theme.danger
                }

                Text {
                    Layout.fillWidth: true
                    text: errorBanner.currentErrorText
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Theme.danger
                    wrapMode: Text.Wrap
                }
            }
        }

        // ================= PASSWORD INPUT BOX =================
        Item {
            id: inputContainer
            Layout.fillWidth: true
            implicitHeight: 42
            transform: Translate { id: shakeTranslate }

            Rectangle {
                id: inputBg
                anchors.fill: parent
                radius: 10
                color: Theme.surface
                border.color: errorBanner.hasError ? Theme.danger : (passwordInput.activeFocus ? Theme.accent : Theme.border)
                border.width: passwordInput.activeFocus ? 2 : 1

                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    // Lock Icon
                    Text {
                        text: "󰌾"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 15
                        color: passwordInput.activeFocus ? Theme.accent : Theme.textMuted
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Input Field
                    TextInput {
                        id: passwordInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 13
                        color: Theme.textPrimary
                        clip: true
                        selectByMouse: true
                        focus: true
                        echoMode: (PolkitService.responseVisible || root.showPassword) ? TextInput.Normal : TextInput.Password
                        enabled: !PolkitService.isSubmitting

                        // Placeholder Text
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: {
                                if (PolkitService.inputPrompt !== "") {
                                    return PolkitService.inputPrompt.replace(/:$/, "").trim() + "...";
                                }
                                return "Enter password...";
                            }
                            font: parent.font
                            color: Theme.textMuted
                            opacity: 0.6
                            visible: !parent.text && !parent.inputMethodComposing
                        }
                    }

                    // Show / Hide Password Button
                    Rectangle {
                        visible: !PolkitService.responseVisible
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 6
                        color: eyeMouse.containsMouse ? Theme.surfaceHover : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.showPassword ? "󰈈" : "󰈉"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 14
                            color: root.showPassword ? Theme.accent : (eyeMouse.containsMouse ? Theme.textPrimary : Theme.textMuted)
                        }

                        MouseArea {
                            id: eyeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showPassword = !root.showPassword
                        }
                    }
                }
            }

            // Subtle Shake Animation on Authentication Error
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -10; duration: 40; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: -7; duration: 40; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeTranslate; property: "x"; from: -7; to: 7; duration: 40; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeTranslate; property: "x"; from: 7; to: -3; duration: 30; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeTranslate; property: "x"; from: -3; to: 0; duration: 30; easing.type: Easing.InOutQuad }
            }
        }

        // ================= BOTTOM BUTTONS =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item { Layout.fillWidth: true }

            // Cancel Button
            Rectangle {
                implicitWidth: cancelRow.implicitWidth + 24
                implicitHeight: 34
                radius: 8
                color: cancelMouse.pressed ? Theme.surfaceActive : (cancelMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                border.color: Theme.border
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: cancelRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 11
                        color: Theme.textSecondary
                    }

                    Text {
                        text: "Cancel"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancel()
                }
            }

            // Authenticate Button
            Rectangle {
                implicitWidth: authRow.implicitWidth + 24
                implicitHeight: 34
                radius: 8
                color: {
                    if (PolkitService.isSubmitting) return Theme.surfaceActive;
                    if (authMouse.pressed) return Qt.darker(Theme.accent, 1.15);
                    if (authMouse.containsMouse) return Qt.lighter(Theme.accent, 1.1);
                    return Theme.accent;
                }
                scale: authMouse.pressed ? 0.96 : 1.0

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 100 } }

                RowLayout {
                    id: authRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: PolkitService.isSubmitting ? "󰑐" : "󰌾"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.badgeFocusedText || "#FFFFFF"

                        RotationAnimation on rotation {
                            running: PolkitService.isSubmitting
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }

                    Text {
                        text: PolkitService.isSubmitting ? "Verifying..." : "Authenticate"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.badgeFocusedText || "#FFFFFF"
                    }
                }

                MouseArea {
                    id: authMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: PolkitService.isSubmitting ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !PolkitService.isSubmitting
                    onClicked: root.submitPassword()
                }
            }
        }
    }
}
