import QtQuick
import QtQuick.Layouts
import Quickshell
import '../components/'
import "../services"
import ".."

IconButtonBar {
    id: root

    signal openRequested()

    // Bindings with IconButtonBar via AudioService (Quickshell.Services.Pipewire)
    available: true
    active: !AudioService.isMuted
    icon: AudioService.sinkIcon

    tooltip: {
        var outType = AudioService.isHeadphones ? "󰋋 " : "󰕾 ";
        var muteStr = AudioService.isMuted ? " [Muted]" : "";
        var lines = [`${outType}${AudioService.sinkName} (${AudioService.volume}%)${muteStr}`];
        if (AudioService.hasSource) {
            var micMuteStr = AudioService.isMicMuted ? " [Muted]" : ` (${AudioService.micVolume}%)`;
            lines.push(`${AudioService.micIcon} ${AudioService.sourceName}${micMuteStr}`);
        }
        return lines.join("\n");
    }

    // Left click: Open native Audio selector and app mixer in Control Center
    onClicked: {
        NetworkService.wifiPanelOpen = false;
        BluetoothService.btPanelOpen = false;
        AudioService.audioPanelOpen = true;
        root.openRequested();
    }

    // Right click: Toggle Mute natively via PipeWire
    onRightClicked: {
        AudioService.toggleMute();
    }
}
