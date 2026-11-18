pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    // Controls whether the Display & Monitors subpanel is open in Control Center
    property bool displayPanelOpen: false

    // Raw and structured outputs list from `niri msg -j outputs`
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

    // Feedback message when saving to outputs.kdl or applying changes
    property string statusFeedback: ""

    // Auto-open display selector when a new monitor is hotplugged
    readonly property bool autoPromptOnHotplug: (Config.display && Config.display.autoPromptOnHotplug !== undefined)
        ? (Config.display.autoPromptOnHotplug === true)
        : true

    signal monitorHotplugged(var addedOutputs)

    property bool _initialReadDone: false
    property var _knownConnectorNames: []
    property var _cachedScales: ({})

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
            default:               return "Extended";
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

    function normalizeTransform(raw) {
        if (!raw) return "normal";
        var s = String(raw).toLowerCase().replace(/^_/, "");
        if (s === "flipped90") return "flipped-90";
        if (s === "flipped180") return "flipped-180";
        if (s === "flipped270") return "flipped-270";
        if (s === "90" || s === "180" || s === "270" || s === "normal" || s === "flipped") return s;
        return "normal";
    }

    function isInternalConnector(name) {
        if (!name) return false;
        return name.indexOf("eDP-") === 0 || name.indexOf("LVDS-") === 0 || name.indexOf("DSI-") === 0;
    }

    function showFeedback(msg) {
        root.statusFeedback = msg;
        feedbackTimer.restart();
    }

    Timer {
        id: feedbackTimer
        interval: 3000
        repeat: false
        onTriggered: root.statusFeedback = ""
    }

    // Refresh outputs from Niri & check wl-mirror state
    function refresh() {
        if (!queryProc.running) {
            queryProc.running = true;
        }
    }

    Timer {
        id: delayedRefreshTimer
        interval: 280
        repeat: false
        onTriggered: root.refresh()
    }

    function scheduleRefresh(delayMs) {
        delayedRefreshTimer.interval = delayMs || 280;
        delayedRefreshTimer.restart();
    }

    Process {
        id: queryProc
        command: [
            "bash", "-c",
            "command -v wl-mirror >/dev/null 2>&1 && has_wlm=1 || has_wlm=0; " +
            "wlm_cmd=$(ps -C wl-mirror -o args= 2>/dev/null | head -n 1); " +
            "niri_json=$(niri msg -j outputs 2>/dev/null || echo '{}'); " +
            "python3 -c 'import json, sys; " +
            "has_wlm = sys.argv[1] == \"1\"; " +
            "wlm_cmd = sys.argv[2].strip(); " +
            "outputs = json.loads(sys.argv[3]); " +
            "print(json.dumps({\"has_wlm\": has_wlm, \"wlm_cmd\": wlm_cmd, \"outputs\": outputs}))' " +
            "\"$has_wlm\" \"$wlm_cmd\" \"$niri_json\""
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    var payload = JSON.parse(data);
                    root.parsePayload(payload);
                } catch (e) {
                    console.warn("[DisplayService] Failed to parse outputs JSON:", e);
                }
            }
        }
    }

    function parsePayload(payload) {
        root.wlMirrorInstalled = !!payload.has_wlm;
        var wlmCmd = payload.wlm_cmd || "";
        var rawOutputs = payload.outputs || {};

        // Parse wl-mirror command if active: e.g. "wl-mirror --fullscreen-output HDMI-A-1 eDP-1"
        if (wlmCmd !== "") {
            root.isMirroring = true;
            var parts = wlmCmd.split(/\s+/);
            var tgt = "";
            var src = "";
            for (var p = 0; p < parts.length; p++) {
                if ((parts[p] === "--fullscreen-output" || parts[p] === "-F") && p + 1 < parts.length) {
                    tgt = parts[p + 1];
                    p++;
                } else if (parts[p].indexOf("-") !== 0 && parts[p].indexOf("wl-mirror") === -1) {
                    src = parts[p];
                }
            }
            root.mirrorTarget = tgt;
            root.mirrorSource = src;
        } else {
            root.isMirroring = false;
            root.mirrorTarget = "";
            root.mirrorSource = "";
        }

        var list = [];
        var keys = Object.keys(rawOutputs);

        // Sort: internal (eDP-*) first, then alphabetical
        keys.sort(function(a, b) {
            var aInt = root.isInternalConnector(a);
            var bInt = root.isInternalConnector(b);
            if (aInt && !bInt) return -1;
            if (!aInt && bInt) return 1;
            return a.localeCompare(b);
        });

        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            var o = rawOutputs[k];
            if (!o) continue;

            var logical = o.logical || null;
            var enabled = (logical !== null);
            var modes = Array.isArray(o.modes) ? o.modes : [];
            var curIdx = (o.current_mode !== null && o.current_mode !== undefined) ? Number(o.current_mode) : -1;

            // Pick active mode or preferred mode for physical resolution
            var activeMode = (curIdx >= 0 && curIdx < modes.length) ? modes[curIdx] : null;
            if (!activeMode && modes.length > 0) {
                for (var m = 0; m < modes.length; m++) {
                    if (modes[m].is_preferred) {
                        activeMode = modes[m];
                        break;
                    }
                }
                if (!activeMode) activeMode = modes[0];
            }

            var physW = activeMode ? Number(activeMode.width) : 1920;
            var physH = activeMode ? Number(activeMode.height) : 1080;
            var refreshMhz = activeMode ? Number(activeMode.refresh_rate) : 60000;
            var refreshHzStr = (refreshMhz / 1000.0).toFixed(3);
            var refreshShort = Math.round(refreshMhz / 1000.0) + "Hz";

            var scale = 1.0;
            if (logical && logical.scale) {
                scale = Number(logical.scale);
                root._cachedScales[k] = scale;
            } else if (root._cachedScales[k]) {
                scale = root._cachedScales[k];
            }

            var transform = logical ? root.normalizeTransform(logical.transform) : "normal";
            var rotated = (transform === "90" || transform === "270" || transform === "flipped-90" || transform === "flipped-270");

            var logW = logical ? Number(logical.width) : Math.round((rotated ? physH : physW) / scale);
            var logH = logical ? Number(logical.height) : Math.round((rotated ? physW : physH) / scale);
            var logX = logical ? Number(logical.x) : 0;
            var logY = logical ? Number(logical.y) : 0;

            // Build deduplicated top modes list (up to 6 most useful modes)
            var formattedModes = [];
            var seenRes = {};
            for (var mi = 0; mi < modes.length; mi++) {
                var md = modes[mi];
                var hz = (Number(md.refresh_rate) / 1000.0).toFixed(3);
                var hzRound = Math.round(Number(md.refresh_rate) / 1000.0);
                var modeCmd = md.width + "x" + md.height + "@" + hz;
                var label = md.width + "×" + md.height + " @ " + hzRound + "Hz";
                var keySig = md.width + "x" + md.height + "@" + hzRound;
                if (!seenRes[keySig] && formattedModes.length < 8) {
                    seenRes[keySig] = true;
                    formattedModes.push({
                        cmd: modeCmd,
                        label: label,
                        width: md.width,
                        height: md.height,
                        refreshHz: hzRound,
                        isCurrent: (mi === curIdx),
                        isPreferred: !!md.is_preferred
                    });
                }
            }

            var makeModel = [o.make || "", o.model || ""].join(" ").trim();
            if (!makeModel) makeModel = root.isInternalConnector(k) ? "Built-in Display" : "External Monitor";

            list.push({
                name: k,
                makeModel: makeModel,
                isInternal: root.isInternalConnector(k),
                enabled: enabled,
                width: logW,
                height: logH,
                physicalWidth: physW,
                physicalHeight: physH,
                x: logX,
                y: logY,
                scale: scale,
                transform: transform,
                refreshRate: refreshShort,
                modeCmd: physW + "x" + physH + "@" + refreshHzStr,
                modes: formattedModes
            });
        }

        root.outputs = list;

        // Resolve primary and secondary output names
        var cfgPrimary = (Config.display && Config.display.primaryOutput) ? String(Config.display.primaryOutput) : "";
        var foundPrimary = "";
        if (cfgPrimary !== "") {
            for (var pi = 0; pi < list.length; pi++) {
                if (list[pi].name === cfgPrimary) {
                    foundPrimary = cfgPrimary;
                    break;
                }
            }
        }
        if (foundPrimary === "" && root.primaryOutputName !== "") {
            for (var pj = 0; pj < list.length; pj++) {
                if (list[pj].name === root.primaryOutputName) {
                    foundPrimary = root.primaryOutputName;
                    break;
                }
            }
        }
        if (foundPrimary === "" && list.length > 0) {
            foundPrimary = list[0].name;
        }
        root.primaryOutputName = foundPrimary;

        var foundSecondary = "";
        if (root.secondaryOutputName !== "" && root.secondaryOutputName !== foundPrimary) {
            for (var si = 0; si < list.length; si++) {
                if (list[si].name === root.secondaryOutputName) {
                    foundSecondary = root.secondaryOutputName;
                    break;
                }
            }
        }
        if (foundSecondary === "") {
            for (var sj = 0; sj < list.length; sj++) {
                if (list[sj].name !== foundPrimary) {
                    foundSecondary = list[sj].name;
                    break;
                }
            }
        }
        root.secondaryOutputName = foundSecondary;

        // Infer current layout mode
        root.currentLayoutMode = root.inferLayoutMode(list, foundPrimary, foundSecondary);

        // Check for hotplugged new physical connectors
        if (!root._initialReadDone) {
            root._initialReadDone = true;
            root._knownConnectorNames = keys;
        } else {
            var added = [];
            for (var ki = 0; ki < keys.length; ki++) {
                if (root._knownConnectorNames.indexOf(keys[ki]) === -1) {
                    added.push(keys[ki]);
                }
            }
            root._knownConnectorNames = keys;
            if (added.length > 0 && keys.length > 1) {
                root.monitorHotplugged(added);
            }
        }
    }

    function inferLayoutMode(list, primName, secName) {
        if (list.length <= 1) return "single";
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

    // ── Primary / Secondary selection ──────────────────────────────
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
            root.refresh();
        }
    }

    // ── Apply multi-monitor layout mode ────────────────────────────
    Process {
        id: applyProc
        onExited: (exitCode, exitStatus) => {
            root.scheduleRefresh(180);
        }
    }

    function applyLayout(mode) {
        if (root.outputs.length < 2) {
            if (root.outputs.length === 1) {
                applyProc.exec(["niri", "msg", "output", root.outputs[0].name, "on"]);
            }
            return;
        }

        var prim = root.primaryOutputName || root.outputs[0].name;
        var sec = root.secondaryOutputName || root.outputs[1].name;

        Config.set("display.lastLayoutMode", mode);

        // Python helper executes atomically:
        // 1. Stops wl-mirror if running
        // 2. Powers on/off outputs as requested
        // 3. Queries fresh `niri msg -j outputs` so logical sizes are exact even if an output was off
        // 4. Sets exact logical positions for primary, secondary, and any extra monitors
        // 5. Starts wl-mirror if mode == "mirror"
        var script = [
            "import json, subprocess, time, sys",
            "mode, prim, sec = sys.argv[1], sys.argv[2], sys.argv[3]",
            "subprocess.run(['pkill', '-x', 'wl-mirror'], stderr=subprocess.DEVNULL)",
            "def niri_out(*args):",
            "    subprocess.run(['niri', 'msg', 'output', *args], stderr=subprocess.DEVNULL)",
            "if mode == 'primary-only':",
            "    niri_out(prim, 'on')",
            "    niri_out(prim, 'position', 'set', '0', '0')",
            "    niri_out(sec, 'off')",
            "    sys.exit(0)",
            "if mode == 'secondary-only':",
            "    niri_out(sec, 'on')",
            "    niri_out(sec, 'position', 'set', '0', '0')",
            "    niri_out(prim, 'off')",
            "    sys.exit(0)",
            "niri_out(prim, 'on')",
            "niri_out(sec, 'on')",
            "time.sleep(0.12)",
            "raw = subprocess.check_output(['niri', 'msg', '-j', 'outputs'], text=True)",
            "data = json.loads(raw)",
            "def get_size(name):",
            "    o = data.get(name, {})",
            "    log = o.get('logical')",
            "    if log:",
            "        return int(log.get('width', 1920)), int(log.get('height', 1080))",
            "    modes = o.get('modes') or []",
            "    if modes:",
            "        return int(modes[0].get('width', 1920)), int(modes[0].get('height', 1080))",
            "    return 1920, 1080",
            "pw, ph = get_size(prim)",
            "sw, sh = get_size(sec)",
            "if mode == 'extend-right':",
            "    niri_out(prim, 'position', 'set', '0', '0')",
            "    niri_out(sec, 'position', 'set', str(pw), '0')",
            "    cur_x = pw + sw",
            "elif mode == 'extend-left':",
            "    niri_out(sec, 'position', 'set', '0', '0')",
            "    niri_out(prim, 'position', 'set', str(sw), '0')",
            "    cur_x = sw + pw",
            "elif mode == 'extend-above':",
            "    niri_out(sec, 'position', 'set', '0', '0')",
            "    niri_out(prim, 'position', 'set', '0', str(sh))",
            "    cur_x = max(pw, sw)",
            "elif mode == 'extend-below':",
            "    niri_out(prim, 'position', 'set', '0', '0')",
            "    niri_out(sec, 'position', 'set', '0', str(ph))",
            "    cur_x = max(pw, sw)",
            "elif mode == 'mirror':",
            "    niri_out(prim, 'position', 'set', '0', '0')",
            "    niri_out(sec, 'position', 'set', str(pw), str(ph))",
            "    cur_x = pw + sw",
            "    subprocess.Popen(['wl-mirror', '--fullscreen-output', sec, prim], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)",
            "else:",
            "    niri_out(prim, 'position', 'auto')",
            "    niri_out(sec, 'position', 'auto')",
            "    cur_x = pw + sw",
            "for k in data.keys():",
            "    if k not in (prim, sec):",
            "        niri_out(k, 'on')",
            "        kw, _ = get_size(k)",
            "        niri_out(k, 'position', 'set', str(cur_x), '0')",
            "        cur_x += kw",
            "subprocess.Popen(['nirakase-wallpaper', '--sync-current'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)"
        ].join("\n");

        applyProc.exec(["python3", "-c", script, mode, prim, sec]);

        var modeNames = {
            "extend-right": "Extend Right applied",
            "extend-left": "Extend Left applied",
            "extend-above": "Extend Above applied",
            "extend-below": "Extend Below applied",
            "mirror": root.wlMirrorInstalled ? ("Mirroring " + prim + " ➔ " + sec) : "Install wl-mirror for screen cloning",
            "primary-only": "Primary monitor only (" + prim + ")",
            "secondary-only": "External monitor only (" + sec + ")"
        };
        root.showFeedback(modeNames[mode] || "Display layout updated");
    }

    function cycleLayoutMode() {
        if (!root.hasMultipleMonitors) return "single";
        var order = ["extend-right", "extend-left", "mirror", "primary-only", "secondary-only"];
        var idx = order.indexOf(root.currentLayoutMode);
        var next = order[(idx + 1) % order.length];
        root.applyLayout(next);
        return next;
    }

    // ── Per-monitor settings ───────────────────────────────────────
    function setOutputEnabled(name, enable) {
        if (!enable && root.activeOutputCount <= 1) {
            root.showFeedback("Cannot disable the last active monitor");
            return;
        }
        if (!enable && root.isMirroring && (name === root.mirrorSource || name === root.mirrorTarget)) {
            Quickshell.execDetached(["pkill", "-x", "wl-mirror"]);
        }
        applyProc.exec(["niri", "msg", "output", name, enable ? "on" : "off"]);
        root.showFeedback(name + (enable ? " enabled" : " disabled"));
    }

    function setOutputScale(name, scaleVal) {
        var s = String(scaleVal);
        root._cachedScales[name] = Number(scaleVal);
        // Apply scale and re-align layout if extending
        applyProc.exec(["niri", "msg", "output", name, "scale", s]);
        root.showFeedback(name + " scale set to " + Math.round(Number(scaleVal) * 100) + "%");
    }

    function setOutputTransform(name, transformStr) {
        applyProc.exec(["niri", "msg", "output", name, "transform", transformStr]);
        root.showFeedback(name + " rotation: " + transformStr);
    }

    function setOutputMode(name, modeCmd) {
        applyProc.exec(["niri", "msg", "output", name, "mode", modeCmd]);
        root.showFeedback(name + " mode: " + modeCmd);
    }

    // ── Persist current output configuration into ~/.config/niri/config.d/outputs.kdl ──
    Process {
        id: saveKdlProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.showFeedback("Saved permanently to outputs.kdl");
            } else {
                root.showFeedback("Failed to write outputs.kdl");
            }
        }
    }

    function saveToNiriConfig() {
        var kdlLines = [
            "// --- Nirakase: Monitor & Output Configuration ---",
            "// Generated by Nirakase Display Manager (Quickshell).",
            "// Run `niri msg outputs` to inspect connector names and modes.",
            ""
        ];

        for (var i = 0; i < root.outputs.length; i++) {
            var o = root.outputs[i];
            kdlLines.push('output "' + o.name + '" {');
            if (!o.enabled) {
                kdlLines.push('    off');
            } else {
                if (o.modeCmd) {
                    kdlLines.push('    mode "' + o.modeCmd + '"');
                }
                kdlLines.push('    scale ' + o.scale);
                kdlLines.push('    transform "' + (o.transform || "normal") + '"');
                kdlLines.push('    position x=' + o.x + ' y=' + o.y);
            }
            kdlLines.push('}');
            kdlLines.push('');
        }

        var content = kdlLines.join("\n");
        var targetPath = Quickshell.env("HOME") + "/.config/niri/config.d/outputs.kdl";

        saveKdlProc.exec([
            "python3", "-c",
            "import sys, pathlib; p = pathlib.Path(sys.argv[1]).resolve(); p.write_text(sys.argv[2], encoding='utf-8')",
            targetPath, content
        ]);
    }
}
