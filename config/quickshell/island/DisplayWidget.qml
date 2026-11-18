import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components/"
import "../services"
import ".."

StatusIndicatorButton {
    id: root

    signal openRequested()

    // Visible automatically when 2+ monitors are detected or mirroring is active
    available: DisplayService.hasMultipleMonitors || DisplayService.isMirroring
    active: DisplayService.activeOutputCount > 1 || DisplayService.isMirroring
    icon: DisplayService.icon

    dotOnly: true
    showBadge: DisplayService.isMirroring
    badgeColor: "#E5A50A"

    tooltip: {
        var lines = [DisplayService.icon + " " + DisplayService.summaryText];
        var outs = DisplayService.outputs;
        for (var i = 0; i < outs.length; i++) {
            var o = outs[i];
            var st = o.enabled
                ? (o.width + "×" + o.height + " @ (" + o.x + "," + o.y + ") · " + Math.round(o.scale * 100) + "%")
                : "off";
            lines.push((o.name === DisplayService.primaryOutputName ? "★ " : "• ") + o.name + ": " + st);
        }
        lines.push("Left click: Display layout · Right click: Cycle mode");
        return lines.join("\n");
    }

    onClicked: {
        NetworkService.wifiPanelOpen = false;
        BluetoothService.btPanelOpen = false;
        AudioService.audioPanelOpen = false;
        IdleService.idlePanelOpen = false;
        DisplayService.displayPanelOpen = true;
        root.openRequested();
    }

    onRightClicked: {
        DisplayService.cycleLayoutMode();
    }
}
