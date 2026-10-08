import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

RowLayout {
  id: dateTimeLayout 

  spacing: 6

  property string dateText: ""
  property string timeText: ""

  readonly property var days: ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
  readonly property var months: ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]

  Timer {
      interval: 1000
      running: true
      repeat: true
      triggeredOnStart: true
      onTriggered: {
          var now = new Date();

          var dayName = dateTimeLayout.days[now.getDay()];
          var dayNum = now.getDate();
          var monthName = dateTimeLayout.months[now.getMonth()];

          dateTimeLayout.dateText = dayName + " " + dayNum + " " + monthName;

          var hrs = String(now.getHours()).padStart(2, '0');
          var mins = String(now.getMinutes()).padStart(2, '0');
          dateTimeLayout.timeText = hrs + ":" + mins;
      }
  }

  Label {
    text: dateTimeLayout.dateText
    color: Theme.textSecondary
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 12
    Layout.alignment: Qt.AlignVCenter
    topPadding: 3
    bottomPadding: 3
  }
  
  Label {
    text: "│"
    color: Theme.border
    font.pixelSize: 11
    Layout.alignment: Qt.AlignVCenter
    topPadding: 3
    bottomPadding: 3
   }

  Label {
    text: dateTimeLayout.timeText
    color: Theme.textPrimary
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 13
    Layout.alignment: Qt.AlignVCenter
    topPadding: 3
    bottomPadding: 3
    rightPadding: 0
   }
}
