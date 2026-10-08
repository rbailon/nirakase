import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool expanded: true
    property int animationDuration: 300
    default property Item contentItem

    // Assign child item to match this container's size
    onContentItemChanged: {
        if (contentItem) {
            contentItem.parent = root;
            contentItem.anchors.centerIn = root;
        }
    }

    implicitWidth: contentItem ? contentItem.implicitWidth : 0
    implicitHeight: contentItem ? contentItem.implicitHeight : 0

    // Size inside RowLayout
    Layout.alignment: Qt.AlignCenter
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: expanded ? implicitWidth : 0

    // Animations
    clip: true
    opacity: expanded ? 1.0 : 0.0
    scale: expanded ? 1.0 : 0.0
    transformOrigin: Item.Center

    // Hide when animation finishes so it takes no space
    visible: opacity > 0.0

    Behavior on Layout.preferredWidth {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.InOutCubic
        }
    }
}
