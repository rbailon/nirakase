import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import '../components/'
import ".."

IconButtonBar {
    id: root

    icon: "󰍛" 

    Process {
      id: swLeftClick
    }

    // Mouse actions
    onClicked: {
        // Left click: Open system monitor in terminal (btop)
        swLeftClick.exec(["xdg-terminal-exec", "--app-id=org.nirakase.system", "-e", "btop"]);
    }
}
