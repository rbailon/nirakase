pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    readonly property string _scriptPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/display-manager.py"

    // Controls whether the Display & Monitors subpanel is open in Control Center
    property bool displayPanelOpen: false

    // Screen where the Quickshell panel is currently displayed (set by shell.qml)
    property string activeScreenName: ""

    // Raw and structured outputs list from display-manager.py query
    property var outputs: []
    property int outputCount: outputs.length
    property int activeOutputCount: {
        var count = 0;
        for (var i = 0; i < outputs.length; i++) {
            if (outputs[i].enabled) count++;
        }
        return count;
    }
    readonly property bool hasMultipleMonitors: outputCount > 1

    // Mirror state (`wl-mirror`)
    property bool wlMirrorInstalled: false
    property bool isMirroring: false
    property string mirrorSource: ""
    property string mirrorTarget: ""

    // Selected Primary and Secondary outputs
    property string primaryOutputName: ""
    property string secondaryOutputName: ""

    // Detected or active layout mode:
    // "single", "extend-right", "extend-left", "extend-above", "extend-below",
    // "mirror", "primary-only", "secondary-only", "custom"
    property string currentLayoutMode: "single"

    // Saved profile & apply state
    property bool hasSavedProfile: false
    property string topologyKey: ""
    property bool isApplying: false

    // Risky-change confirmation (auto-revert safety timer) and quick Undo
    property bool pendingConfirmation: false
    property int confirmationSecondsLeft: 0
    property bool canUndo: false

    // Feedback message when saving or applying changes
    property string statusFeedback: ""

    // Auto-open display selector when an unconfigured monitor setup is hotplugged
    readonly property bool autoPromptOnHotplug: (Config.display && Config.display.autoPromptOnHotplug !== undefined)
        ? (Config.display.autoPromptOnHotplug === true)
        : true

    signal monitorHotplugged(var addedOutputs)
    signal outputsUpdated()
    signal applyFinished(bool success)

    property bool _initialReadDone: false
    property bool _initialRestoreTriggered: false
    property string _knownTopologyKey: ""
    property var _knownConnectorNames: []
    property var _pendingAddedConnectors: []
    property var _previousSnapshot: null
    property var _pendingCommitPayload: null
    property bool _lastApplyWasRisky: false
    property bool _lastApplyWasRevert: false

    readonly property var primaryOutput: {
        for (var i = 0; i < outputs.length; i++) {
            if (outputs[i].name === primaryOutputName) return outputs[i];
        }
        return outputs.length > 0 ? outputs[0] : null;
    }

    readonly property var secondaryOutput: {
        for (var i = 0; i < outputs.length; i++) {
            if (outputs[i].name === secondaryOutputName) return outputs[i];
        }
        for (var j = 0; j < outputs.length; j++) {
            if (outputs[j].name !== primaryOutputName) return outputs[j];
        }
        return null;
    }

    readonly property string icon: {
        if (isMirroring) return "󰍸";
        if (hasMultipleMonitors && activeOutputCount > 1) return "󰍺";
        return "󰍹";
    }

    readonly property string modeLabel: {
        if (!hasMultipleMonitors) return "Single Display";
        if (isMirroring) return "Mirror / Clone";
        switch (currentLayoutMode) {
            case "extend-right":   return "Extend Right";
            case "extend-left":    return "Extend Left";
            case "extend-above":   return "Extend Above";
            case "extend-below":   return "Extend Below";
            case "primary-only":   return "Primary Only";
            case "secondary-only": return "External Only";
            default:               return "Custom Layout";
        }
    }

    readonly property string summaryText: {
        if (outputs.length === 0) return "Detecting outputs...";
        if (outputs.length === 1) {
            var o = outputs[0];
            return o.name + " · " + o.width + "×" + o.height + (o.scale !== 1.0 ? (" @ " + Math.round(o.scale * 100) + "%") : "");
        }
        if (isMirroring) {
            return "Cloning " + (mirrorSource || primaryOutputName) + " ➔ " + (mirrorTarget || secondaryOutputName);
        }
        return outputCount + " monitors · " + modeLabel;
    }

    function setAutoPromptOnHotplug(val) {
        Config.set("display.autoPromptOnHotplug", !!val);
    }

    function showFeedback(msg) {
        root.statusFeedback = msg;
        feedbackTimer.restart();
    }

    Timer {
        id: feedbackTimer
        interval: 3500
        repeat: false
        onTriggered: root.statusFeedback = ""
    }

    Timer {
        id: undoExpireTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (!root.pendingConfirmation) {
                root.canUndo = false;
                root._previousSnapshot = null;
            }
        }
    }

    Timer {
        id: confirmCountdownTimer
        interval: 1000
        repeat: true
        running: root.pendingConfirmation
        onTriggered: {
            if (root.confirmationSecondsLeft > 1) {
                root.confirmationSecondsLeft -= 1;
            } else {
                confirmCountdownTimer.stop();
                root.revertChanges();
            }
        }
    }

    // ── Query live state from display-manager.py ────────────────────
    function refresh() {
        if (root.isApplying) return;
        if (!queryProc.running) {
            queryProc.running = true;
        }
    }

    Timer {
        id: delayedRefreshTimer
        interval: 220
        repeat: false
        onTriggered: root.refresh()
    }

    function scheduleRefresh(delayMs) {
        delayedRefreshTimer.interval = delayMs || 220;
        delayedRefreshTimer.restart();
    }

    Process {
        id: queryProc
        command: ["python3", root._scriptPath, "query"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    var payload = JSON.parse(data);
                    if (payload && payload.ok) {
                        root._parseQueryPayload(payload);
                    }
                } catch (e) {
                    console.warn("[DisplayService] Failed to parse query JSON:", e);
                }
            }
        }
    }

    function _parseQueryPayload(payload) {
        root.wlMirrorInstalled = !!payload.has_wlm;
        var mir = payload.mirror || {};
        root.isMirroring = !!mir.active;
        root.mirrorSource = mir.source || "";
        root.mirrorTarget = mir.target || "";
        root.hasSavedProfile = !!payload.has_saved_profile;
        root.topologyKey = payload.topology_key || "";

        var list = Array.isArray(payload.outputs) ? payload.outputs : [];
        root.outputs = list;

        var keys = [];
        for (var k = 0; k < list.length; k++) {
            keys.push(list[k].name);
        }

        // Resolve primary: saved profile primary > config primary > current primary > first enabled
        var savedPrimary = payload.saved_primary || "";
        var cfgPrimary = (Config.display && Config.display.primaryOutput) ? String(Config.display.primaryOutput) : "";
        var foundPrimary = "";

        var hasOutput = function(name) {
            if (!name) return false;
            for (var i = 0; i < list.length; i++) {
                if (list[i].name === name) return true;
            }
            return false;
        };

        if (hasOutput(savedPrimary)) foundPrimary = savedPrimary;
        else if (hasOutput(cfgPrimary)) foundPrimary = cfgPrimary;
        else if (hasOutput(root.primaryOutputName)) foundPrimary = root.primaryOutputName;
        else if (list.length > 0) {
            for (var e = 0; e < list.length; e++) {
                if (list[e].enabled) {
                    foundPrimary = list[e].name;
                    break;
                }
            }
            if (!foundPrimary) foundPrimary = list[0].name;
        }
        root.primaryOutputName = foundPrimary;

        var foundSecondary = "";
        if (root.secondaryOutputName !== "" && root.secondaryOutputName !== foundPrimary && hasOutput(root.secondaryOutputName)) {
            foundSecondary = root.secondaryOutputName;
        } else {
            for (var sj = 0; sj < list.length; sj++) {
                if (list[sj].name !== foundPrimary) {
                    foundSecondary = list[sj].name;
                    break;
                }
            }
        }
        root.secondaryOutputName = foundSecondary;
        root.currentLayoutMode = root.inferLayoutMode(list, foundPrimary, foundSecondary);
        root.outputsUpdated();

        // Detect initial startup restore & physical topology changes (hotplug / unplug)
        if (!root._initialReadDone) {
            root._initialReadDone = true;
            root._knownTopologyKey = root.topologyKey;
            root._knownConnectorNames = keys;
            if (!root._initialRestoreTriggered && list.length > 0) {
                root._initialRestoreTriggered = true;
                root._pendingAddedConnectors = [];
                root._triggerRestore();
            }
        } else if (root.topologyKey !== "" && root.topologyKey !== root._knownTopologyKey) {
            var added = [];
            for (var ki = 0; ki < keys.length; ki++) {
                if (root._knownConnectorNames.indexOf(keys[ki]) === -1) {
                    added.push(keys[ki]);
                }
            }
            root._knownTopologyKey = root.topologyKey;
            root._knownConnectorNames = keys;
            root._pendingAddedConnectors = (added.length > 0 && keys.length > 1) ? added : [];
            root._triggerRestore();
        }
    }

    function inferLayoutMode(list, primName, secName) {
        if (!list || list.length <= 1) return "single";
        if (root.isMirroring) return "mirror";

        var prim = null;
        var sec = null;
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === primName) prim = list[i];
            else if (list[i].name === secName) sec = list[i];
        }
        if (!prim || !sec) return "custom";

        if (prim.enabled && !sec.enabled) return "primary-only";
        if (!prim.enabled && sec.enabled) return "secondary-only";
        if (!prim.enabled && !sec.enabled) return "custom";

        var dx = sec.x - prim.x;
        var dy = sec.y - prim.y;

        if (Math.abs(dx - prim.width) <= 2 && Math.abs(dy) < Math.max(prim.height, sec.height)) {
            return "extend-right";
        }
        if (Math.abs(prim.x - (sec.x + sec.width)) <= 2 && Math.abs(dy) < Math.max(prim.height, sec.height)) {
            return "extend-left";
        }
        if (Math.abs(prim.y - (sec.y + sec.height)) <= 2 && Math.abs(dx) < Math.max(prim.width, sec.width)) {
            return "extend-above";
        }
        if (Math.abs(dy - prim.height) <= 2 && Math.abs(dx) < Math.max(prim.width, sec.width)) {
            return "extend-below";
        }
        return "custom";
    }

    // ── Automatic Profile Restore on Startup / Hotplug ──────────────
    Process {
        id: restoreProc
        property string _buf: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.trim() !== "") restoreProc._buf = data.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isApplying = false;
            var res = null;
            try {
                if (restoreProc._buf !== "") res = JSON.parse(restoreProc._buf);
            } catch (e) {}
            restoreProc._buf = "";

            var added = root._pendingAddedConnectors;
            root._pendingAddedConnectors = [];

            if (res && res.matched) {
                if (res.applied) {
                    root.showFeedback("Restored saved display profile");
                }
                root.scheduleRefresh(180);
            } else {
                root.scheduleRefresh(180);
                if (added && added.length > 0) {
                    root.monitorHotplugged(added);
                }
            }
        }
    }

    function _triggerRestore() {
        if (restoreProc.running || root.isApplying) return;
        root.isApplying = true;
        restoreProc._buf = "";
        restoreProc.exec(["python3", root._scriptPath, "restore"]);
    }

    // ── Snapshot Helper for Undo / Revert ───────────────────────────
    function _captureSnapshot() {
        var snapOutputs = [];
        for (var i = 0; i < root.outputs.length; i++) {
            var o = root.outputs[i];
            snapOutputs.push({
                name: o.name,
                enabled: !!o.enabled,
                mode: o.modeCmd || "",
                scale: Number(o.scale || 1.0),
                transform: o.transform || "normal",
                x: Math.round(Number(o.x || 0)),
                y: Math.round(Number(o.y || 0))
            });
        }
        return {
            outputs: snapOutputs,
            primary: root.primaryOutputName,
            mirror: {
                enabled: root.isMirroring,
                source: root.mirrorSource,
                target: root.mirrorTarget
            }
        };
    }

    // ── Apply Full Display Configuration (from Interactive Panel) ───
    Process {
        id: applyProc
        property string _buf: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.trim() !== "") applyProc._buf = data.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isApplying = false;
            var res = null;
            try {
                if (applyProc._buf !== "") res = JSON.parse(applyProc._buf);
            } catch (e) {}
            applyProc._buf = "";

            var ok = (exitCode === 0 && (!res || res.ok !== false));
            if (ok) {
                if (root._lastApplyWasRevert) {
                    root.pendingConfirmation = false;
                    root.confirmationSecondsLeft = 0;
                    root._pendingCommitPayload = null;
                    root.canUndo = false;
                    root._previousSnapshot = null;
                    root.showFeedback("Restored previous display settings");
                } else if (root._lastApplyWasRisky) {
                    root.pendingConfirmation = true;
                    root.confirmationSecondsLeft = 15;
                    root.canUndo = false;
                    root.showFeedback("Confirm new display settings");
                } else {
                    root.pendingConfirmation = false;
                    root.confirmationSecondsLeft = 0;
                    root._pendingCommitPayload = null;
                    root.canUndo = (root._previousSnapshot !== null);
                    if (root.canUndo) undoExpireTimer.restart();
                    root.showFeedback("Display layout applied & saved");
                }
            } else {
                root.pendingConfirmation = false;
                root.showFeedback("Failed to apply display layout");
            }
            root._lastApplyWasRisky = false;
            root._lastApplyWasRevert = false;
            root.applyFinished(ok);
            root.scheduleRefresh(160);
        }
    }

    function applyConfiguration(outputsList, primaryName, mirrorCfg, riskyChange) {
        if (root.isApplying || !outputsList || outputsList.length === 0) return;

        root._previousSnapshot = root._captureSnapshot();
        root._lastApplyWasRisky = !!riskyChange;
        root._lastApplyWasRevert = false;

        var cleanOutputs = [];
        for (var i = 0; i < outputsList.length; i++) {
            var o = outputsList[i];
            cleanOutputs.push({
                name: o.name,
                enabled: !!o.enabled,
                mode: o.modeCmd || o.mode || "",
                scale: Number(o.scale || 1.0),
                transform: o.transform || "normal",
                x: Math.round(Number(o.x || 0)),
                y: Math.round(Number(o.y || 0))
            });
        }

        var effPrimary = primaryName || root.primaryOutputName || cleanOutputs[0].name;
        var mirObj = {
            enabled: !!(mirrorCfg && mirrorCfg.enabled),
            source: (mirrorCfg && mirrorCfg.source) ? mirrorCfg.source : effPrimary,
            target: (mirrorCfg && mirrorCfg.target) ? mirrorCfg.target : ""
        };

        var payload = {
            outputs: cleanOutputs,
            primary: effPrimary,
            mirror: mirObj,
            persist: !riskyChange,
            keep_focus: root.activeScreenName || ""
        };

        if (riskyChange) {
            root._pendingCommitPayload = Object.assign({}, payload, { persist: true });
        } else {
            root._pendingCommitPayload = null;
            Config.set("display.primaryOutput", effPrimary);
        }

        root.isApplying = true;
        applyProc._buf = "";
        applyProc.exec(["python3", root._scriptPath, "apply", "--payload", JSON.stringify(payload)]);
    }

    function keepPendingChanges() {
        if (!root.pendingConfirmation) return;
        confirmCountdownTimer.stop();
        root.pendingConfirmation = false;
        root.confirmationSecondsLeft = 0;

        var commitPayload = root._pendingCommitPayload;
        root._pendingCommitPayload = null;
        if (commitPayload && commitPayload.primary) {
            Config.set("display.primaryOutput", commitPayload.primary);
        }

        saveProc._buf = "";
        saveProc.exec([
            "python3", root._scriptPath, "save-current",
            "--primary", (commitPayload && commitPayload.primary) ? commitPayload.primary : root.primaryOutputName
        ]);
        root.canUndo = (root._previousSnapshot !== null);
        if (root.canUndo) undoExpireTimer.restart();
    }

    function revertChanges() {
        confirmCountdownTimer.stop();
        undoExpireTimer.stop();
        if (!root._previousSnapshot || root.isApplying) {
            root.pendingConfirmation = false;
            root.canUndo = false;
            return;
        }
        var snap = root._previousSnapshot;
        var payload = {
            outputs: snap.outputs,
            primary: snap.primary || "",
            mirror: snap.mirror || { enabled: false, source: "", target: "" },
            persist: !root.pendingConfirmation,
            keep_focus: root.activeScreenName || ""
        };
        root._lastApplyWasRevert = true;
        root._lastApplyWasRisky = false;
        root.isApplying = true;
        applyProc._buf = "";
        applyProc.exec(["python3", root._scriptPath, "apply", "--payload", JSON.stringify(payload)]);
    }

    // ── Quick Presets (IPC, DisplayWidget right-click, ControlCenter Clone/Extend) ──
    function applyLayout(mode) {
        if (root.isApplying) return;
        root._previousSnapshot = root._captureSnapshot();
        root._lastApplyWasRisky = false;
        root._lastApplyWasRevert = false;

        var prim = root.primaryOutputName || (root.outputs.length > 0 ? root.outputs[0].name : "");
        var sec = root.secondaryOutputName || (root.outputs.length > 1 ? root.outputs[1].name : "");
        Config.set("display.lastLayoutMode", mode);

        var cmd = [
            "python3", root._scriptPath, "apply-preset", mode,
            "--primary", prim,
            "--secondary", sec
        ];
        if (root.activeScreenName !== "") {
            cmd.push("--keep-focus", root.activeScreenName);
        }

        root.isApplying = true;
        applyProc._buf = "";
        applyProc.exec(cmd);
    }

    function cycleLayoutMode() {
        if (!root.hasMultipleMonitors) return "single";
        var order = ["extend-right", "extend-left", "mirror", "primary-only", "secondary-only"];
        var idx = order.indexOf(root.currentLayoutMode);
        var next = order[(idx + 1) % order.length];
        root.applyLayout(next);
        return next;
    }

    function setPrimaryOutput(name) {
        if (!name || name === root.primaryOutputName) return;
        var prevPrimary = root.primaryOutputName;
        root.primaryOutputName = name;
        if (root.secondaryOutputName === name) {
            root.secondaryOutputName = prevPrimary;
        }
        Config.set("display.primaryOutput", name);
        root.currentLayoutMode = root.inferLayoutMode(root.outputs, root.primaryOutputName, root.secondaryOutputName);
    }

    function swapPrimarySecondary() {
        if (!root.hasMultipleMonitors || !root.secondaryOutputName) return;
        var p = root.primaryOutputName;
        var s = root.secondaryOutputName;
        root.primaryOutputName = s;
        root.secondaryOutputName = p;
        Config.set("display.primaryOutput", s);
        if (root.currentLayoutMode !== "single" && root.currentLayoutMode !== "custom") {
            root.applyLayout(root.currentLayoutMode);
        } else {
            root.saveToNiriConfig();
        }
    }

    // ── Explicit Save Current State ─────────────────────────────────
    Process {
        id: saveProc
        property string _buf: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.trim() !== "") saveProc._buf = data.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.hasSavedProfile = true;
                root.showFeedback("Display profile saved");
                root.scheduleRefresh(140);
            } else {
                root.showFeedback("Failed to save display profile");
            }
            saveProc._buf = "";
        }
    }

    function saveToNiriConfig() {
        if (saveProc.running) return;
        saveProc._buf = "";
        saveProc.exec([
            "python3", root._scriptPath, "save-current",
            "--primary", root.primaryOutputName || ""
        ]);
    }
}
