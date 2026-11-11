pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    // Controls whether the native Audio selector/mixer panel is open in Control Center
    property bool audioPanelOpen: false

    // =============================================================
    // 1. Primary PipeWire Nodes (Default Output and Input)
    // =============================================================
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // List of all output devices (Speakers, Headphones, HDMI...)
    readonly property var sinks: {
        var raw = Pipewire.nodes.values;
        if (!raw) return [];
        var list = [];
        for (var i = 0; i < raw.length; i++) {
            var n = raw[i];
            if (n && !n.isStream && n.isSink && n.audio) {
                list.push(n);
            }
        }
        return list;
    }

    // List of all input devices (Microphones)
    readonly property var sources: {
        var raw = Pipewire.nodes.values;
        if (!raw) return [];
        var list = [];
        for (var i = 0; i < raw.length; i++) {
            var n = raw[i];
            if (n && !n.isStream && !n.isSink && n.audio) {
                var mediaClass = (n.properties && n.properties["media.class"]) ? String(n.properties["media.class"]) : "";
                if (mediaClass.indexOf("Audio/Source") !== -1 || mediaClass === "") {
                    list.push(n);
                }
            }
        }
        return list;
    }

    // Applications currently playing audio (Output streams)
    readonly property var appStreams: {
        var raw = Pipewire.nodes.values;
        if (!raw) return [];
        var list = [];
        for (var i = 0; i < raw.length; i++) {
            var n = raw[i];
            if (n && n.isStream && n.isSink && n.audio) {
                list.push(n);
            }
        }
        return list;
    }

    // Mandatory Quickshell.Services.Pipewire tracker to enable reading/writing volume and properties
    PwObjectTracker {
        objects: {
            var tracked = [];
            if (root.sink) tracked.push(root.sink);
            if (root.source) tracked.push(root.source);
            var raw = Pipewire.nodes.values;
            if (raw) {
                for (var i = 0; i < raw.length; i++) {
                    var n = raw[i];
                    if (n && n.audio && tracked.indexOf(n) === -1) {
                        tracked.push(n);
                    }
                }
            }
            return tracked;
        }
    }

    // =============================================================
    // 2. Reactive Output State (Speakers / Headphones)
    // =============================================================
    readonly property bool hasSink: sink !== null && sink.audio !== null
    readonly property bool isMuted: (sink && sink.audio) ? sink.audio.muted : false
    readonly property int volume: (sink && sink.audio && !isNaN(sink.audio.volume))
        ? Math.max(0, Math.min(100, Math.round(sink.audio.volume * 100)))
        : 0
    readonly property string sinkName: nodeDisplayName(sink, "Speakers")

    readonly property bool isHeadphones: isNodeHeadphones(sink)

    readonly property string sinkIcon: {
        if (isHeadphones) {
            return isMuted ? "󰟎" : "󰋋";
        }
        if (isMuted || volume === 0) return "󰝟";
        if (volume <= 33) return "󰕿";
        if (volume <= 66) return "󰖀";
        return "󰕾";
    }

    // =============================================================
    // 3. Reactive Input State (Microphone)
    // =============================================================
    readonly property bool hasSource: source !== null && source.audio !== null
    readonly property bool isMicMuted: (source && source.audio) ? source.audio.muted : false
    readonly property int micVolume: (source && source.audio && !isNaN(source.audio.volume))
        ? Math.max(0, Math.min(100, Math.round(source.audio.volume * 100)))
        : 0
    readonly property string sourceName: nodeDisplayName(source, "Microphone")
    readonly property string micIcon: (isMicMuted || micVolume === 0) ? "󰍭" : "󰍬"

    // =============================================================
    // 4. Node Name and Icon Helper Functions
    // =============================================================
    function nodeDisplayName(node, fallback) {
        if (!node) return fallback || "Audio";
        if (node.description && node.description.trim() !== "") return node.description;
        if (node.nickname && node.nickname.trim() !== "") return node.nickname;
        if (node.properties) {
            if (node.properties["node.description"]) return String(node.properties["node.description"]);
            if (node.properties["device.description"]) return String(node.properties["device.description"]);
            if (node.properties["application.name"]) return String(node.properties["application.name"]);
            if (node.properties["media.name"]) return String(node.properties["media.name"]);
        }
        if (node.name && node.name.trim() !== "") return node.name;
        return fallback || "Audio";
    }

    function streamSubLabel(node) {
        if (!node || !node.properties) return "";
        var mediaName = node.properties["media.name"] ? String(node.properties["media.name"]) : "";
        var appName = node.properties["application.name"] ? String(node.properties["application.name"]) : "";
        if (mediaName && appName && mediaName !== appName) return mediaName;
        return "";
    }

    function isNodeHeadphones(node) {
        if (!node) return false;
        var combined = (
            (node.name || "") + " " +
            (node.description || "") + " " +
            (node.nickname || "") + " " +
            ((node.properties && node.properties["device.icon-name"]) ? String(node.properties["device.icon-name"]) : "") + " " +
            ((node.properties && node.properties["device.form-factor"]) ? String(node.properties["device.form-factor"]) : "")
        ).toLowerCase();
        return combined.indexOf("headphone") !== -1 ||
               combined.indexOf("headset") !== -1 ||
               combined.indexOf("earphone") !== -1 ||
               combined.indexOf("bluez") !== -1 ||
               combined.indexOf("buds") !== -1 ||
               combined.indexOf("airpods") !== -1;
    }

    function nodeIcon(node) {
        if (!node) return "󰕾";
        if (node.isStream) return "󰎆";
        if (!node.isSink) {
            return (node.audio && node.audio.muted) ? "󰍭" : "󰍬";
        }
        if (isNodeHeadphones(node)) {
            return (node.audio && node.audio.muted) ? "󰟎" : "󰋋";
        }
        var desc = ((node.name || "") + " " + (node.description || "")).toLowerCase();
        if (desc.indexOf("hdmi") !== -1 || desc.indexOf("displayport") !== -1) {
            return "󰡁";
        }
        return (node.audio && node.audio.muted) ? "󰝟" : "󰕾";
    }

    // =============================================================
    // 5. Volume, Mute, and Device Control Actions
    // =============================================================
    function setVolume(pct) {
        if (!sink || !sink.audio) return;
        var clamped = Math.max(0, Math.min(100, Math.round(pct)));
        sink.audio.volume = clamped / 100.0;
    }

    function changeVolume(deltaPct) {
        if (!sink || !sink.audio) return;
        setVolume(volume + deltaPct);
    }

    function toggleMute() {
        if (!sink || !sink.audio) return;
        sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(pct) {
        if (!source || !source.audio) return;
        var clamped = Math.max(0, Math.min(100, Math.round(pct)));
        source.audio.volume = clamped / 100.0;
    }

    function changeMicVolume(deltaPct) {
        if (!source || !source.audio) return;
        setMicVolume(micVolume + deltaPct);
    }

    function toggleMicMute() {
        if (!source || !source.audio) return;
        source.audio.muted = !source.audio.muted;
    }

    function setDefaultSink(targetNode) {
        if (!targetNode) return;
        Pipewire.preferredDefaultAudioSink = targetNode;
    }

    function setDefaultSource(targetNode) {
        if (!targetNode) return;
        Pipewire.preferredDefaultAudioSource = targetNode;
    }

    function setNodeVolume(targetNode, pct) {
        if (!targetNode || !targetNode.audio) return;
        var clamped = Math.max(0, Math.min(100, Math.round(pct)));
        targetNode.audio.volume = clamped / 100.0;
    }

    function toggleNodeMute(targetNode) {
        if (!targetNode || !targetNode.audio) return;
        targetNode.audio.muted = !targetNode.audio.muted;
    }
}
