import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Item {
  id: root

  signal clicked()
  signal doubleClicked()

  property string dateText: ""
  property string timeText: ""

  readonly property var days: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  implicitWidth: dateTimeLayout.implicitWidth
  implicitHeight: dateTimeLayout.implicitHeight

  Timer {
      interval: 1000
      running: true
      repeat: true
      triggeredOnStart: true
      onTriggered: {
          var now = new Date();

          var dayName = root.days[now.getDay()];
          var dayNum = now.getDate();
          var monthName = root.months[now.getMonth()];

          root.dateText = dayName + " " + dayNum + " " + monthName;

          var hrs = String(now.getHours()).padStart(2, '0');
          var mins = String(now.getMinutes()).padStart(2, '0');
          root.timeText = hrs + ":" + mins;
      }
  }

  RowLayout {
    id: dateTimeLayout
    anchors.centerIn: parent
    spacing: 6

    Label {
      text: root.dateText
      color: Theme.textSecondary
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 12
      Layout.alignment: Qt.AlignVCenter
      topPadding: 2
      bottomPadding: 2
    }
    
    Label {
      text: "│"
      color: Theme.border
      font.pixelSize: 11
      Layout.alignment: Qt.AlignVCenter
      topPadding: 2
      bottomPadding: 2
    }

    Label {
      text: root.timeText
      color: Theme.textPrimary
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 13
      Layout.alignment: Qt.AlignVCenter
      topPadding: 2
      bottomPadding: 2
      rightPadding: 0
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
    onDoubleClicked: root.doubleClicked()
  }
}
