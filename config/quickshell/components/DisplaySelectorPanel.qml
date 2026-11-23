import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."
import "../services"

ColumnLayout {
    id: root

    signal backRequested()
    signal closeRequested()

    spacing: 8

    // ── Draft state (staged edits applied atomically via "Apply & Save") ──
    property var draftOutputs: []
    property string draftPrimary: ""
    property bool draftMirroring: false
    property string draftMirrorSource: ""
    property string draftMirrorTarget: ""
    property string selectedOutputName: ""
    property bool hasPendingChanges: false
    property string _lastSyncedConnectors: ""

    // ── Interactive drag & snap state ──
    property bool isDragging: false
    property int draggingIndex: -1
    property real draggingLogicalX: 0
    property real draggingLogicalY: 0
    property real _dragViewScale: 0.1
    property real _dragOriginX: 0
    property real _dragOriginY: 0
    property real _dragMinX: 0
    property real _dragMinY: 0
    property bool snapGuideXActive: false
    property real snapGuideXLogical: 0
    property bool snapGuideYActive: false
    property real snapGuideYLogical: 0

    readonly property var layoutPresets: [
        { id: "extend-left",    label: "Left",     icon: "󰁍" },
        { id: "extend-right",   label: "Right",    icon: "󰁔" },
        { id: "extend-above",   label: "Above",    icon: "󰁝" },
        { id: "extend-below",   label: "Below",    icon: "󰁅" },
        { id: "mirror",         label: "Clone",    icon: "󰍸" },
        { id: "primary-only",   label: "Primary",  icon: "󰌢" },
        { id: "secondary-only", label: "External", icon: "󰍹" }
    ]

    readonly property var scalePresets: [
        { label: "100%", value: 1.0 },
        { label: "125%", value: 1.25 },
        { label: "150%", value: 1.5 },
        { label: "175%", value: 1.75 },
        { label: "200%", value: 2.0 }
    ]

    readonly property var transformPresets: [
        { label: "0°",   value: "normal" },
        { label: "90°",  value: "90" },
        { label: "180°", value: "180" },
        { label: "270°", value: "270" }
    ]

    readonly property int draftEnabledCount: {
        var c = 0;
        for (var i = 0; i < draftOutputs.length; i++) {
            if (draftOutputs[i].enabled) c++;
        }
        return c;
    }

    readonly property var selectedOutput: {
        for (var i = 0; i < draftOutputs.length; i++) {
            if (draftOutputs[i].name === selectedOutputName) return draftOutputs[i];
        }
        return draftOutputs.length > 0 ? draftOutputs[0] : null;
    }

    readonly property string draftLayoutMode: {
        if (draftOutputs.length <= 1) return "single";
        if (draftMirroring) return "mirror";
        var prim = _findOutput(draftOutputs, draftPrimary);
        var sec = _findSecondary(draftOutputs, draftPrimary);
        if (!prim || !sec) return "custom";
        if (prim.enabled && !sec.enabled) return "primary-only";
        if (!prim.enabled && sec.enabled) return "secondary-only";
        if (!prim.enabled && !sec.enabled) return "custom";
        var dx = sec.x - prim.x;
        var dy = sec.y - prim.y;
        if (Math.abs(dx - prim.width) <= 2 && Math.abs(dy) < Math.max(prim.height, sec.height)) return "extend-right";
        if (Math.abs(prim.x - (sec.x + sec.width)) <= 2 && Math.abs(dy) < Math.max(prim.height, sec.height)) return "extend-left";
        if (Math.abs(prim.y - (sec.y + sec.height)) <= 2 && Math.abs(dx) < Math.max(prim.width, sec.width)) return "extend-above";
        if (Math.abs(dy - prim.height) <= 2 && Math.abs(dx) < Math.max(prim.width, sec.width)) return "extend-below";
        return "custom";
    }

    readonly property bool isHorizontalArrangement: {
        var en = [];
        for (var i = 0; i < draftOutputs.length; i++) {
            if (draftOutputs[i].enabled) en.push(draftOutputs[i]);
        }
        if (en.length < 2) return true;
        var minX = 999999, maxX = -999999, minY = 999999, maxY = -999999;
        for (var j = 0; j < en.length; j++) {
            minX = Math.min(minX, en[j].x);
            maxX = Math.max(maxX, en[j].x + en[j].width);
            minY = Math.min(minY, en[j].y);
            maxY = Math.max(maxY, en[j].y + en[j].height);
        }
        return (maxX - minX) >= (maxY - minY);
    }

    Component.onCompleted: syncDraftFromService(true)

    onVisibleChanged: {
        if (visible) {
            syncDraftFromService(true);
            DisplayService.refresh();
        }
    }

    Connections {
        target: DisplayService
        function onOutputsUpdated() {
            var conns = [];
            for (var i = 0; i < DisplayService.outputs.length; i++) {
                conns.push(DisplayService.outputs[i].name);
            }
            var connSig = conns.join(",");
            var topologyChanged = (connSig !== root._lastSyncedConnectors);
            if (topologyChanged || (!root.hasPendingChanges && !root.isDragging)) {
                root.syncDraftFromService(topologyChanged);
            }
        }
        function onApplyFinished(success) {
            if (success) {
                root.hasPendingChanges = false;
            }
        }
    }

    // ── Draft & Geometry Helpers ────────────────────────────────────
    function _cloneOutputs(list) {
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var o = list[i];
            out.push({
                name: o.name,
                fingerprint: o.fingerprint || "",
                makeModel: o.makeModel || "",
                isInternal: !!o.isInternal,
                enabled: !!o.enabled,
                width: Math.round(Number(o.width || 1920)),
                height: Math.round(Number(o.height || 1080)),
                physicalWidth: Math.round(Number(o.physicalWidth || 1920)),
                physicalHeight: Math.round(Number(o.physicalHeight || 1080)),
                x: Math.round(Number(o.x || 0)),
                y: Math.round(Number(o.y || 0)),
                scale: Number(o.scale || 1.0),
                transform: o.transform || "normal",
                refreshRate: o.refreshRate || "60Hz",
                modeCmd: o.modeCmd || "",
                modes: o.modes ? o.modes.slice() : []
            });
        }
        return out;
    }

    function _findOutput(list, name) {
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === name) return list[i];
        }
        return null;
    }

    function _findSecondary(list, primName) {
        if (DisplayService.secondaryOutputName && DisplayService.secondaryOutputName !== primName) {
            var s = _findOutput(list, DisplayService.secondaryOutputName);
            if (s) return s;
        }
        for (var i = 0; i < list.length; i++) {
            if (list[i].name !== primName) return list[i];
        }
        return null;
    }

    function syncDraftFromService(forceSelect) {
        var cloned = _cloneOutputs(DisplayService.outputs || []);
        var conns = [];
        for (var i = 0; i < cloned.length; i++) conns.push(cloned[i].name);
        root._lastSyncedConnectors = conns.join(",");

        root.draftOutputs = cloned;
        root.draftPrimary = DisplayService.primaryOutputName || (cloned.length > 0 ? cloned[0].name : "");
        root.draftMirroring = DisplayService.isMirroring;
        root.draftMirrorSource = DisplayService.mirrorSource || root.draftPrimary;
        var sec = _findSecondary(cloned, root.draftPrimary);
        root.draftMirrorTarget = DisplayService.mirrorTarget || (sec ? sec.name : "");
        root.hasPendingChanges = false;

        if (forceSelect || !_findOutput(cloned, root.selectedOutputName)) {
            root.selectedOutputName = root.draftPrimary || (cloned.length > 0 ? cloned[0].name : "");
        }
    }

    function _isRotated(tr) {
        return tr === "90" || tr === "270" || tr === "flipped-90" || tr === "flipped-270";
    }

    function _computeLogicalSize(physW, physH, scale, transform) {
        var sc = Math.max(0.25, Number(scale || 1.0));
        var rot = _isRotated(transform);
        return {
            w: Math.max(1, Math.round((rot ? physH : physW) / sc)),
            h: Math.max(1, Math.round((rot ? physW : physH) / sc))
        };
    }

    function _rectsOverlap(a, b) {
        return a.x < (b.x + b.width) && (a.x + a.width) > b.x &&
               a.y < (b.y + b.height) && (a.y + a.height) > b.y;
    }

    function _rectsTouch(a, b, minShared) {
        var ms = minShared || 1;
        var hTouch = (a.x + a.width === b.x) || (b.x + b.width === a.x);
        var vOv = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
        if (hTouch && vOv >= ms) return true;
        var vTouch = (a.y + a.height === b.y) || (b.y + b.height === a.y);
        var hOv = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
        return vTouch && hOv >= ms;
    }

    function _clamp(val, lo, hi) {
        if (lo > hi) return Math.round((lo + hi) / 2);
        return Math.max(lo, Math.min(hi, val));
    }

    function _snapRectToPlaced(target, placed, alignThreshold) {
        var tx = Math.round(target.x);
        var ty = Math.round(target.y);
        var tw = Math.round(target.width);
        var th = Math.round(target.height);
        var thr = alignThreshold || 80;
        var best = null;
        var bestDistSq = 1e18;

        for (var i = 0; i < placed.length; i++) {
            var a = placed[i];
            var minOvY = Math.min(80, th, a.height);
            var minOvX = Math.min(80, tw, a.width);

            var cY = _clamp(ty, a.y - th + minOvY, a.y + a.height - minOvY);
            // Snap vertical alignment (top / center / bottom) when close
            if (Math.abs(cY - a.y) <= thr) cY = a.y;
            else if (Math.abs((cY + th) - (a.y + a.height)) <= thr) cY = a.y + a.height - th;
            else if (Math.abs((cY + th / 2) - (a.y + a.height / 2)) <= thr) cY = Math.round(a.y + (a.height - th) / 2);

            var cX = _clamp(tx, a.x - tw + minOvX, a.x + a.width - minOvX);
            // Snap horizontal alignment (left / center / right) when close
            if (Math.abs(cX - a.x) <= thr) cX = a.x;
            else if (Math.abs((cX + tw) - (a.x + a.width)) <= thr) cX = a.x + a.width - tw;
            else if (Math.abs((cX + tw / 2) - (a.x + a.width / 2)) <= thr) cX = Math.round(a.x + (a.width - tw) / 2);

            var candidates = [
                { x: a.x + a.width, y: cY },
                { x: a.x - tw,      y: cY },
                { x: cX,            y: a.y + a.height },
                { x: cX,            y: a.y - th }
            ];

            for (var c = 0; c < candidates.length; c++) {
                var probe = { x: candidates[c].x, y: candidates[c].y, width: tw, height: th };
                var blocked = false;
                for (var p = 0; p < placed.length; p++) {
                    if (_rectsOverlap(probe, placed[p])) {
                        blocked = true;
                        break;
                    }
                }
                if (blocked) continue;
                var dx = probe.x - tx;
                var dy = probe.y - ty;
                var d2 = dx * dx + dy * dy;
                if (d2 < bestDistSq) {
                    bestDistSq = d2;
                    best = { x: probe.x, y: probe.y };
                }
            }
        }

        if (best) return best;

        var maxRight = 0;
        for (var r = 0; r < placed.length; r++) {
            maxRight = Math.max(maxRight, placed[r].x + placed[r].width);
        }
        return { x: maxRight, y: placed.length > 0 ? placed[0].y : 0 };
    }

    function _normalizeAndEnsureConnected(list, anchorName) {
        var enabled = [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].enabled) enabled.push(list[i]);
        }
        if (enabled.length === 0) return list;

        // Verify overlap-free and single connected component
        var valid = true;
        for (var a = 0; a < enabled.length && valid; a++) {
            for (var b = a + 1; b < enabled.length; b++) {
                if (_rectsOverlap(enabled[a], enabled[b])) {
                    valid = false;
                    break;
                }
            }
        }
        if (valid && enabled.length > 1) {
            var visited = {};
            visited[0] = true;
            var queue = [0];
            var count = 1;
            while (queue.length > 0) {
                var cur = queue.shift();
                for (var n = 0; n < enabled.length; n++) {
                    if (!visited[n] && _rectsTouch(enabled[cur], enabled[n], 1)) {
                        visited[n] = true;
                        queue.push(n);
                        count++;
                    }
                }
            }
            if (count !== enabled.length) valid = false;
        }

        if (!valid) {
            // Keep anchor fixed, snap remaining enabled outputs closest to their current positions
            var sorted = enabled.slice().sort(function(u, v) {
                if (u.name === anchorName) return -1;
                if (v.name === anchorName) return 1;
                if (u.name === root.draftPrimary) return -1;
                if (v.name === root.draftPrimary) return 1;
                return u.x - v.x;
            });
            var placed = [sorted[0]];
            for (var k = 1; k < sorted.length; k++) {
                var pos = _snapRectToPlaced(sorted[k], placed, 60);
                sorted[k].x = pos.x;
                sorted[k].y = pos.y;
                placed.push(sorted[k]);
            }
        }

        // Normalize bounding box to (0, 0)
        var minX = 999999, minY = 999999;
        for (var m = 0; m < enabled.length; m++) {
            if (enabled[m].x < minX) minX = enabled[m].x;
            if (enabled[m].y < minY) minY = enabled[m].y;
        }
        for (var z = 0; z < enabled.length; z++) {
            enabled[z].x = Math.round(enabled[z].x - minX);
            enabled[z].y = Math.round(enabled[z].y - minY);
        }
        return list;
    }

    function _markDirty(updatedList) {
        root.draftOutputs = updatedList;
        root.hasPendingChanges = true;
    }

    // ── Drag lifecycle (updates scalar coords without recreating Repeater delegates) ──
    function beginDrag(idx) {
        if (idx < 0 || idx >= draftOutputs.length) return;
        if (!draftOutputs[idx].enabled || draftMirroring || draftEnabledCount < 2) return;
        root._dragViewScale = mapCanvas.mapScale;
        root._dragOriginX = mapCanvas.originX;
        root._dragOriginY = mapCanvas.originY;
        root._dragMinX = mapCanvas.bounds.minX;
        root._dragMinY = mapCanvas.bounds.minY;
        root.draggingLogicalX = draftOutputs[idx].x;
        root.draggingLogicalY = draftOutputs[idx].y;
        root.draggingIndex = idx;
        root.isDragging = true;
        root.snapGuideXActive = false;
        root.snapGuideYActive = false;
    }

    function updateDrag(idx, rawLogicalX, rawLogicalY) {
        if (!root.isDragging || idx !== root.draggingIndex) return;
        var list = root.draftOutputs;
        if (idx < 0 || idx >= list.length) return;
        var m = list[idx];
        var snapThreshold = Math.max(40, Math.round(16 / Math.max(0.02, root._dragViewScale)));

        var bestX = Math.round(rawLogicalX);
        var bestY = Math.round(rawLogicalY);
        var bestDx = snapThreshold + 1;
        var bestDy = snapThreshold + 1;
        var guideX = 0, hasGX = false;
        var guideY = 0, hasGY = false;

        for (var i = 0; i < list.length; i++) {
            if (i === idx || !list[i].enabled) continue;
            var o = list[i];

            // Candidate X snaps: adjacent left/right + left/right/center alignment
            var xSnaps = [
                { val: o.x + o.width,                             guide: o.x + o.width },
                { val: o.x - m.width,                             guide: o.x },
                { val: o.x,                                       guide: o.x },
                { val: o.x + o.width - m.width,                   guide: o.x + o.width },
                { val: Math.round(o.x + (o.width - m.width) / 2), guide: o.x + o.width / 2 }
            ];
            for (var xi = 0; xi < xSnaps.length; xi++) {
                var dx = Math.abs(rawLogicalX - xSnaps[xi].val);
                if (dx < bestDx) {
                    bestDx = dx;
                    bestX = xSnaps[xi].val;
                    guideX = xSnaps[xi].guide;
                    hasGX = true;
                }
            }

            // Candidate Y snaps: adjacent top/bottom + top/bottom/center alignment
            var ySnaps = [
                { val: o.y + o.height,                              guide: o.y + o.height },
                { val: o.y - m.height,                              guide: o.y },
                { val: o.y,                                         guide: o.y },
                { val: o.y + o.height - m.height,                   guide: o.y + o.height },
                { val: Math.round(o.y + (o.height - m.height) / 2), guide: o.y + o.height / 2 }
            ];
            for (var yi = 0; yi < ySnaps.length; yi++) {
                var dy = Math.abs(rawLogicalY - ySnaps[yi].val);
                if (dy < bestDy) {
                    bestDy = dy;
                    bestY = ySnaps[yi].val;
                    guideY = ySnaps[yi].guide;
                    hasGY = true;
                }
            }
        }

        root.draggingLogicalX = Math.round(bestX);
        root.draggingLogicalY = Math.round(bestY);
        root.snapGuideXActive = hasGX;
        root.snapGuideXLogical = guideX;
        root.snapGuideYActive = hasGY;
        root.snapGuideYLogical = guideY;
    }

    function finishDrag(idx) {
        if (!root.isDragging) return;
        var list = _cloneOutputs(root.draftOutputs);
        if (idx >= 0 && idx < list.length && list[idx].enabled) {
            var moved = list[idx];
            moved.x = Math.round(root.draggingLogicalX);
            moved.y = Math.round(root.draggingLogicalY);
            var others = [];
            for (var i = 0; i < list.length; i++) {
                if (i !== idx && list[i].enabled) others.push(list[i]);
            }
            if (others.length > 0) {
                var overlaps = false;
                var touches = false;
                var minShared = Math.min(40, moved.width, moved.height);
                for (var j = 0; j < others.length; j++) {
                    if (_rectsOverlap(moved, others[j])) overlaps = true;
                    if (_rectsTouch(moved, others[j], minShared)) touches = true;
                }
                if (overlaps || !touches) {
                    var snapped = _snapRectToPlaced(moved, others, Math.max(60, Math.round(18 / Math.max(0.02, root._dragViewScale))));
                    moved.x = snapped.x;
                    moved.y = snapped.y;
                }
            }
            // Ensure full connectivity (e.g. for 3+ monitors if middle monitor moved)
            _normalizeAndEnsureConnected(list, moved.name);
        }
        root.isDragging = false;
        root.draggingIndex = -1;
        root.snapGuideXActive = false;
        root.snapGuideYActive = false;
        _markDirty(list);
    }

    // ── Draft Editing Actions ───────────────────────────────────────
    function applyPresetToDraft(modeId) {
        var list = _cloneOutputs(root.draftOutputs);
        if (list.length < 2) return;
        var prim = _findOutput(list, root.draftPrimary) || list[0];
        var sec = _findSecondary(list, prim.name) || list[1];
        root.draftPrimary = prim.name;
        root.draftMirroring = (modeId === "mirror");

        if (modeId === "primary-only") {
            for (var i = 0; i < list.length; i++) {
                list[i].enabled = (list[i].name === prim.name);
                list[i].x = 0;
                list[i].y = 0;
            }
            root.selectedOutputName = prim.name;
            _markDirty(list);
            return;
        }
        if (modeId === "secondary-only") {
            for (var j = 0; j < list.length; j++) {
                list[j].enabled = (list[j].name === sec.name);
                list[j].x = 0;
                list[j].y = 0;
            }
            root.draftPrimary = sec.name;
            root.selectedOutputName = sec.name;
            _markDirty(list);
            return;
        }

        for (var k = 0; k < list.length; k++) list[k].enabled = true;

        var pw = prim.width, ph = prim.height;
        var sw = sec.width, sh = sec.height;
        var curX = pw + sw;

        if (modeId === "extend-right" || modeId === "mirror") {
            prim.x = 0; prim.y = Math.max(0, Math.round((sh - ph) / 2));
            sec.x = pw; sec.y = Math.max(0, Math.round((ph - sh) / 2));
            curX = pw + sw;
        } else if (modeId === "extend-left") {
            sec.x = 0;  sec.y = Math.max(0, Math.round((ph - sh) / 2));
            prim.x = sw; prim.y = Math.max(0, Math.round((sh - ph) / 2));
            curX = sw + pw;
        } else if (modeId === "extend-above") {
            sec.x = Math.max(0, Math.round((pw - sw) / 2));  sec.y = 0;
            prim.x = Math.max(0, Math.round((sw - pw) / 2)); prim.y = sh;
            curX = Math.max(pw, sw);
        } else if (modeId === "extend-below") {
            prim.x = Math.max(0, Math.round((sw - pw) / 2)); prim.y = 0;
            sec.x = Math.max(0, Math.round((pw - sw) / 2));  sec.y = ph;
            curX = Math.max(pw, sw);
        }

        if (modeId === "mirror") {
            root.draftMirrorSource = prim.name;
            root.draftMirrorTarget = sec.name;
        }

        for (var m = 0; m < list.length; m++) {
            if (list[m].name !== prim.name && list[m].name !== sec.name) {
                list[m].x = curX;
                list[m].y = 0;
                curX += list[m].width;
            }
        }
        _normalizeAndEnsureConnected(list, prim.name);
        _markDirty(list);
    }

    function alignDraftMonitors(alignment) {
        var list = _cloneOutputs(root.draftOutputs);
        var enabled = [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].enabled) enabled.push(list[i]);
        }
        if (enabled.length < 2) return;

        if (root.isHorizontalArrangement) {
            enabled.sort(function(a, b) { return a.x - b.x; });
            var maxH = 0;
            for (var h = 0; h < enabled.length; h++) maxH = Math.max(maxH, enabled[h].height);
            var cx = 0;
            for (var k = 0; k < enabled.length; k++) {
                enabled[k].x = cx;
                if (alignment === "start") enabled[k].y = 0;
                else if (alignment === "end") enabled[k].y = maxH - enabled[k].height;
                else enabled[k].y = Math.round((maxH - enabled[k].height) / 2);
                cx += enabled[k].width;
            }
        } else {
            enabled.sort(function(a, b) { return a.y - b.y; });
            var maxW = 0;
            for (var w = 0; w < enabled.length; w++) maxW = Math.max(maxW, enabled[w].width);
            var cy = 0;
            for (var m = 0; m < enabled.length; m++) {
                enabled[m].y = cy;
                if (alignment === "start") enabled[m].x = 0;
                else if (alignment === "end") enabled[m].x = maxW - enabled[m].width;
                else enabled[m].x = Math.round((maxW - enabled[m].width) / 2);
                cy += enabled[m].height;
            }
        }
        _normalizeAndEnsureConnected(list, root.draftPrimary);
        _markDirty(list);
    }

    function setDraftPrimary(name) {
        if (!name || name === root.draftPrimary) return;
        root.draftPrimary = name;
        if (root.draftMirroring) {
            var oldSource = root.draftMirrorSource;
            root.draftMirrorSource = name;
            if (root.draftMirrorTarget === name) {
                root.draftMirrorTarget = oldSource;
            }
        }
        root.hasPendingChanges = true;
    }

    function swapDraftPrimary() {
        var sec = _findSecondary(root.draftOutputs, root.draftPrimary);
        if (!sec) return;
        setDraftPrimary(sec.name);
    }

    function setDraftOutputEnabled(name, enable) {
        var list = _cloneOutputs(root.draftOutputs);
        var target = _findOutput(list, name);
        if (!target) return;
        if (!enable && root.draftEnabledCount <= 1) {
            DisplayService.showFeedback("Cannot disable the last active monitor");
            return;
        }
        target.enabled = !!enable;
        if (!enable && root.draftMirroring && (name === root.draftMirrorSource || name === root.draftMirrorTarget)) {
            root.draftMirroring = false;
        }
        if (!enable && root.draftPrimary === name) {
            for (var i = 0; i < list.length; i++) {
                if (list[i].enabled) {
                    root.draftPrimary = list[i].name;
                    break;
                }
            }
        }
        if (enable) {
            // Place newly re-enabled monitor cleanly adjacent to rightmost enabled monitor
            var others = [];
            for (var j = 0; j < list.length; j++) {
                if (list[j].name !== name && list[j].enabled) others.push(list[j]);
            }
            if (others.length > 0) {
                var maxR = 0;
                for (var r = 0; r < others.length; r++) maxR = Math.max(maxR, others[r].x + others[r].width);
                target.x = maxR;
                target.y = 0;
            }
        }
        _normalizeAndEnsureConnected(list, root.draftPrimary);
        _markDirty(list);
    }

    function _resizeDraftOutputAndResnap(list, target, newW, newH) {
        var oldW = target.width;
        var oldH = target.height;
        var oldRight = target.x + oldW;
        var oldBottom = target.y + oldH;
        var dw = newW - oldW;
        var dh = newH - oldH;

        target.width = newW;
        target.height = newH;

        // Shift flush neighbors so changing scale/mode/rotation never creates gaps or overlaps
        for (var i = 0; i < list.length; i++) {
            var o = list[i];
            if (o.name === target.name || !o.enabled) continue;
            if (Math.abs(o.x - oldRight) <= 2) o.x += dw;
            if (Math.abs(o.y - oldBottom) <= 2) o.y += dh;
        }
        _normalizeAndEnsureConnected(list, target.name);
    }

    function setDraftScale(name, scaleVal) {
        var list = _cloneOutputs(root.draftOutputs);
        var target = _findOutput(list, name);
        if (!target) return;
        target.scale = Number(scaleVal);
        var sz = _computeLogicalSize(target.physicalWidth, target.physicalHeight, target.scale, target.transform);
        _resizeDraftOutputAndResnap(list, target, sz.w, sz.h);
        _markDirty(list);
    }

    function setDraftTransform(name, transformVal) {
        var list = _cloneOutputs(root.draftOutputs);
        var target = _findOutput(list, name);
        if (!target) return;
        target.transform = transformVal;
        var sz = _computeLogicalSize(target.physicalWidth, target.physicalHeight, target.scale, target.transform);
        _resizeDraftOutputAndResnap(list, target, sz.w, sz.h);
        _markDirty(list);
    }

    function setDraftMode(name, modeObj) {
        var list = _cloneOutputs(root.draftOutputs);
        var target = _findOutput(list, name);
        if (!target || !modeObj) return;
        target.modeCmd = modeObj.cmd;
        target.physicalWidth = modeObj.width;
        target.physicalHeight = modeObj.height;
        target.refreshRate = modeObj.refreshHz + "Hz";
        var sz = _computeLogicalSize(target.physicalWidth, target.physicalHeight, target.scale, target.transform);
        _resizeDraftOutputAndResnap(list, target, sz.w, sz.h);
        _markDirty(list);
    }

    function _hasRiskyChanges() {
        var live = DisplayService.outputs || [];
        for (var i = 0; i < root.draftOutputs.length; i++) {
            var d = root.draftOutputs[i];
            var l = _findOutput(live, d.name);
            if (!l) continue;
            // Disabling a previously enabled monitor or changing display mode gets 15s auto-revert safety
            if (l.enabled && !d.enabled) return true;
            if (d.enabled && l.modeCmd && d.modeCmd && d.modeCmd !== l.modeCmd) return true;
        }
        return false;
    }

    function commitDraft() {
        if (DisplayService.isApplying || root.draftOutputs.length === 0) return;
        var list = _cloneOutputs(root.draftOutputs);
        _normalizeAndEnsureConnected(list, root.draftPrimary);
        root.draftOutputs = list;

        var risky = _hasRiskyChanges();
        DisplayService.applyConfiguration(
            list,
            root.draftPrimary,
            {
                enabled: root.draftMirroring,
                source: root.draftMirrorSource || root.draftPrimary,
                target: root.draftMirrorTarget
            },
            risky
        );
    }

    // ================= HEADER =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        // Back button
        Rectangle {
            implicitWidth: backRow.implicitWidth + 12
            implicitHeight: 24
            radius: 6
            color: backMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: backMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            RowLayout {
                id: backRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "󰁍"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 12
                    color: Theme.textPrimary
                }

                Text {
                    text: "Back"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backRequested()
            }
        }

        Text {
            text: "Monitors & Layout"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.textPrimary
        }

        // Status badge
        Rectangle {
            implicitWidth: statusBadgeLbl.implicitWidth + 10
            implicitHeight: 18
            radius: 5
            color: Theme.surface
            border.color: root.hasPendingChanges
                ? (Theme.warning || "#F59E0B")
                : (DisplayService.hasSavedProfile ? (Theme.success || Theme.accent) : Theme.border)
            border.width: 1

            Text {
                id: statusBadgeLbl
                anchors.centerIn: parent
                text: DisplayService.isApplying
                    ? "Applying..."
                    : (root.hasPendingChanges
                        ? "● Unsaved changes"
                        : (DisplayService.hasSavedProfile ? "✓ Profile saved" : "Not saved"))
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                color: root.hasPendingChanges
                    ? (Theme.warning || "#F59E0B")
                    : (DisplayService.hasSavedProfile ? (Theme.success || Theme.accent) : Theme.textMuted)
            }
        }

        Item { Layout.fillWidth: true }

        // Refresh button
        Rectangle {
            implicitWidth: 24
            implicitHeight: 24
            radius: 6
            color: refreshMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: refreshMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "󰑐"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 11
                color: refreshMouse.containsMouse ? Theme.accent : Theme.textSecondary
            }

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.hasPendingChanges = false;
                    DisplayService.refresh();
                }
            }
        }

        // Close button
        Text {
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pixelSize: 14
            color: closeDispMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

            MouseArea {
                id: closeDispMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    // ================= SAFETY CONFIRMATION / UNDO BANNER =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 8
        visible: DisplayService.pendingConfirmation || (DisplayService.canUndo && !root.hasPendingChanges)
        color: Theme.surface
        border.color: DisplayService.pendingConfirmation ? (Theme.warning || "#F59E0B") : Theme.accent
        border.width: 1.5

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: DisplayService.pendingConfirmation ? "󰀦" : "✓"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 13
                color: DisplayService.pendingConfirmation ? (Theme.warning || "#F59E0B") : Theme.accent
            }

            Text {
                Layout.fillWidth: true
                text: DisplayService.pendingConfirmation
                    ? ("Keep these display settings? Reverting in " + DisplayService.confirmationSecondsLeft + "s")
                    : (DisplayService.statusFeedback || "Layout applied & saved")
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            // Revert / Undo button
            Rectangle {
                implicitWidth: revLbl.implicitWidth + 12
                implicitHeight: 22
                radius: 5
                color: revMouse.containsMouse ? Theme.surfaceHover : Theme.background
                border.color: Theme.border
                border.width: 1

                Text {
                    id: revLbl
                    anchors.centerIn: parent
                    text: DisplayService.pendingConfirmation ? "Revert" : "Undo"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: revMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DisplayService.revertChanges()
                }
            }

            // Keep button (only when confirmation is pending)
            Rectangle {
                visible: DisplayService.pendingConfirmation
                implicitWidth: keepLbl.implicitWidth + 14
                implicitHeight: 22
                radius: 5
                color: keepMouse.containsMouse ? Theme.accent : Theme.accent
                opacity: keepMouse.containsMouse ? 0.9 : 1.0

                Text {
                    id: keepLbl
                    anchors.centerIn: parent
                    text: "Keep & Save"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.badgeFocusedText || "#11111B"
                }

                MouseArea {
                    id: keepMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DisplayService.keepPendingChanges()
                }
            }
        }
    }

    // ================= INTERACTIVE MONITOR ARRANGEMENT CANVAS =================
    Rectangle {
        id: mapCanvas
        Layout.fillWidth: true
        implicitHeight: 188
        radius: 10
        color: Theme.surface
        border.color: root.isDragging
            ? Theme.accent
            : (DisplayService.statusFeedback !== "" ? Theme.accent : Theme.border)
        border.width: root.isDragging ? 1.5 : 1
        clip: true

        // Subtle alignment dot grid
        Canvas {
            id: gridBg
            anchors.fill: parent
            opacity: 0.22
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = Theme.textMuted;
                var step = 18;
                for (var gx = step; gx < width; gx += step) {
                    for (var gy = 26; gy < height; gy += step) {
                        ctx.fillRect(gx, gy, 1.5, 1.5);
                    }
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // Compute bounding box of enabled outputs (frozen while dragging so viewport never jumps!)
        readonly property var bounds: {
            var outs = root.draftOutputs;
            if (!outs || outs.length === 0) return { minX: 0, minY: 0, totalW: 1920, totalH: 1080 };
            var minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
            var anyEnabled = false;
            for (var i = 0; i < outs.length; i++) {
                var o = outs[i];
                if (!o.enabled) continue;
                anyEnabled = true;
                if (o.x < minX) minX = o.x;
                if (o.y < minY) minY = o.y;
                if (o.x + o.width > maxX) maxX = o.x + o.width;
                if (o.y + o.height > maxY) maxY = o.y + o.height;
            }
            if (!anyEnabled) return { minX: 0, minY: 0, totalW: 1920, totalH: 1080 };
            return {
                minX: minX,
                minY: minY,
                totalW: Math.max(800, maxX - minX),
                totalH: Math.max(600, maxY - minY)
            };
        }

        readonly property real availW: Math.max(180, stageArea.width - 36)
        readonly property real availH: Math.max(80, stageArea.height - 24)
        readonly property real mapScale: root.isDragging
            ? root._dragViewScale
            : Math.min(availW / bounds.totalW, availH / bounds.totalH) * 0.76
        readonly property real activeMinX: root.isDragging ? root._dragMinX : bounds.minX
        readonly property real activeMinY: root.isDragging ? root._dragMinY : bounds.minY
        readonly property real originX: root.isDragging
            ? root._dragOriginX
            : (stageArea.width - bounds.totalW * mapScale) / 2
        readonly property real originY: root.isDragging
            ? root._dragOriginY
            : (stageArea.height - bounds.totalH * mapScale) / 2

        // Canvas top bar: hint + alignment buttons
        RowLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 7
            spacing: 5
            z: 10

            Text {
                Layout.fillWidth: true
                text: {
                    if (root.isDragging && root.draggingIndex >= 0 && root.draggingIndex < root.draftOutputs.length) {
                        var dm = root.draftOutputs[root.draggingIndex];
                        return "Moving " + dm.name + " ➔ (" + Math.round(root.draggingLogicalX) + ", " + Math.round(root.draggingLogicalY) + ")";
                    }
                    if (DisplayService.statusFeedback !== "") {
                        return "✔ " + DisplayService.statusFeedback;
                    }
                    if (root.draftMirroring) {
                        return "Mirroring " + root.draftMirrorSource + " ➔ " + root.draftMirrorTarget;
                    }
                    if (root.draftEnabledCount > 1) {
                        return "Drag screens to position · Click to configure";
                    }
                    return "Click a screen to configure";
                }
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: (root.isDragging || DisplayService.statusFeedback !== "") ? Theme.accent : Theme.textMuted
                elide: Text.ElideRight
            }

            // Quick alignment buttons for 2+ enabled non-mirrored displays
            Repeater {
                model: (root.draftEnabledCount > 1 && !root.draftMirroring)
                    ? [
                        { id: "start",  label: root.isHorizontalArrangement ? "Top"    : "Left" },
                        { id: "center", label: "Center" },
                        { id: "end",    label: root.isHorizontalArrangement ? "Bottom" : "Right" }
                    ]
                    : []

                delegate: Rectangle {
                    implicitWidth: alLbl.implicitWidth + 8
                    implicitHeight: 18
                    radius: 4
                    color: alMouse.containsMouse ? Theme.surfaceHover : Theme.background
                    border.color: alMouse.containsMouse ? Theme.accent : Theme.border
                    border.width: 1

                    Text {
                        id: alLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        color: alMouse.containsMouse ? Theme.accent : Theme.textSecondary
                    }

                    MouseArea {
                        id: alMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.alignDraftMonitors(modelData.id)
                    }
                }
            }

            // Swap Primary button
            Rectangle {
                visible: root.draftOutputs.length > 1
                implicitWidth: swapLbl.implicitWidth + 8
                implicitHeight: 18
                radius: 4
                color: swapMouse.containsMouse ? Theme.surfaceHover : Theme.background
                border.color: swapMouse.containsMouse ? Theme.accent : Theme.border
                border.width: 1

                Text {
                    id: swapLbl
                    anchors.centerIn: parent
                    text: "󰓡 Swap"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    color: swapMouse.containsMouse ? Theme.accent : Theme.textSecondary
                }

                MouseArea {
                    id: swapMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.swapDraftPrimary()
                }
            }
        }

        // Interactive stage area
        Item {
            id: stageArea
            anchors.fill: parent
            anchors.topMargin: 28
            anchors.bottomMargin: 8
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            // Magnetic snap guide lines (visible while dragging)
            Rectangle {
                visible: root.isDragging && root.snapGuideXActive
                x: mapCanvas.originX + (root.snapGuideXLogical - mapCanvas.activeMinX) * mapCanvas.mapScale
                y: 0
                width: 1
                height: parent.height
                color: Theme.accent
                opacity: 0.65
                z: 2
            }

            Rectangle {
                visible: root.isDragging && root.snapGuideYActive
                x: 0
                y: mapCanvas.originY + (root.snapGuideYLogical - mapCanvas.activeMinY) * mapCanvas.mapScale
                width: parent.width
                height: 1
                color: Theme.accent
                opacity: 0.65
                z: 2
            }

            // Monitor preview rectangles
            Repeater {
                model: root.draftOutputs

                delegate: Rectangle {
                    id: monBox
                    required property var modelData
                    required property int index

                    readonly property var out: modelData
                    readonly property bool isPrimary: out.name === root.draftPrimary
                    readonly property bool isSelected: out.name === root.selectedOutputName
                    readonly property bool isBeingDragged: root.isDragging && root.draggingIndex === index
                    readonly property bool draggable: out.enabled && !root.draftMirroring && root.draftEnabledCount > 1

                    readonly property real drawW: Math.max(66, out.width * mapCanvas.mapScale)
                    readonly property real drawH: Math.max(44, out.height * mapCanvas.mapScale)

                    // Offset disabled monitors neatly to the bottom-right corner of stage
                    readonly property int disabledOrder: {
                        var ord = 0;
                        for (var i = 0; i < index; i++) {
                            if (i < root.draftOutputs.length && !root.draftOutputs[i].enabled) ord++;
                        }
                        return ord;
                    }

                    readonly property real displayLogX: isBeingDragged ? root.draggingLogicalX : out.x
                    readonly property real displayLogY: isBeingDragged ? root.draggingLogicalY : out.y

                    width: drawW
                    height: drawH
                    x: {
                        if (root.draftMirroring) {
                            return (stageArea.width - drawW) / 2 + (isPrimary ? -10 : 10);
                        }
                        if (!out.enabled) {
                            return Math.max(4, stageArea.width - drawW - 6 - (disabledOrder * 12));
                        }
                        return mapCanvas.originX + (displayLogX - mapCanvas.activeMinX) * mapCanvas.mapScale;
                    }
                    y: {
                        if (root.draftMirroring) {
                            return (stageArea.height - drawH) / 2 + (isPrimary ? -6 : 6);
                        }
                        if (!out.enabled) {
                            return Math.max(4, stageArea.height - drawH - 4);
                        }
                        return mapCanvas.originY + (displayLogY - mapCanvas.activeMinY) * mapCanvas.mapScale;
                    }
                    z: isBeingDragged ? 20 : (isSelected ? 10 : (isPrimary ? 6 : 4))

                    radius: 7
                    color: !out.enabled
                        ? Theme.background
                        : (isSelected ? Theme.surfaceActive : Theme.background)
                    border.color: !out.enabled
                        ? Theme.border
                        : (isSelected ? Theme.accent : (isPrimary ? (Theme.success || Theme.accent) : Theme.borderHover))
                    border.width: (isSelected || isBeingDragged) ? 2 : 1.5
                    opacity: out.enabled ? (isBeingDragged ? 0.92 : 1.0) : 0.5

                    Behavior on x {
                        enabled: !root.isDragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: !root.isDragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on width {
                        enabled: !root.isDragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        enabled: !root.isDragging
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // Monitor index badge top-left
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 4
                        width: 14
                        height: 14
                        radius: 4
                        color: monBox.isSelected ? Theme.accent : Theme.surface

                        Text {
                            anchors.centerIn: parent
                            text: String(monBox.index + 1)
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: monBox.isSelected ? (Theme.badgeFocusedText || "#11111B") : Theme.textSecondary
                        }
                    }

                    // Scale badge top-right
                    Text {
                        visible: monBox.out.enabled && Math.abs(monBox.out.scale - 1.0) >= 0.05
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        text: Math.round(monBox.out.scale * 100) + "%"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 7
                        font.weight: Font.Bold
                        color: Theme.accent
                    }

                    // Center label
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1
                        width: parent.width - 10

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: parent.width
                            text: (monBox.isPrimary ? "★ " : "") + monBox.out.name
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: monBox.out.enabled ? Theme.textPrimary : Theme.textMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: parent.width
                            text: monBox.out.enabled
                                ? (monBox.out.width + "×" + monBox.out.height)
                                : "OFF"
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            color: monBox.out.enabled ? Theme.textSecondary : Theme.danger
                            elide: Text.ElideRight
                        }
                    }

                    // Drag & Click handler
                    MouseArea {
                        id: monDragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: monBox.draggable
                            ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                            : Qt.PointingHandCursor

                        property real pressStageX: 0
                        property real pressStageY: 0
                        property real startLogX: 0
                        property real startLogY: 0
                        property bool movedBeyondThreshold: false

                        onPressed: mouse => {
                            root.selectedOutputName = monBox.out.name;
                            var pt = monDragArea.mapToItem(stageArea, mouse.x, mouse.y);
                            pressStageX = pt.x;
                            pressStageY = pt.y;
                            startLogX = monBox.out.x;
                            startLogY = monBox.out.y;
                            movedBeyondThreshold = false;
                        }

                        onPositionChanged: mouse => {
                            if (!pressed || !monBox.draggable) return;
                            var pt = monDragArea.mapToItem(stageArea, mouse.x, mouse.y);
                            var dxPx = pt.x - pressStageX;
                            var dyPx = pt.y - pressStageY;
                            if (!movedBeyondThreshold) {
                                if (Math.abs(dxPx) < 4 && Math.abs(dyPx) < 4) return;
                                movedBeyondThreshold = true;
                                root.beginDrag(monBox.index);
                            }
                            var sc = Math.max(0.02, root._dragViewScale);
                            root.updateDrag(monBox.index, startLogX + (dxPx / sc), startLogY + (dyPx / sc));
                        }

                        onReleased: {
                            if (movedBeyondThreshold) {
                                root.finishDrag(monBox.index);
                            }
                            movedBeyondThreshold = false;
                        }

                        onCanceled: {
                            if (movedBeyondThreshold) {
                                root.finishDrag(monBox.index);
                            }
                            movedBeyondThreshold = false;
                        }
                    }
                }
            }
        }
    }

    // ================= QUICK LAYOUT PRESETS (2+ MONITORS) =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: root.draftOutputs.length > 1

        Repeater {
            model: root.layoutPresets

            delegate: Rectangle {
                id: presetBtn
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 6

                readonly property bool isCurrent: root.draftLayoutMode === modelData.id
                readonly property bool isMirrorMissing: modelData.id === "mirror" && !DisplayService.wlMirrorInstalled

                color: isCurrent
                    ? Theme.surfaceActive
                    : (presetMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                border.color: isCurrent
                    ? (modelData.id === "mirror" ? (Theme.warning || "#F59E0B") : Theme.accent)
                    : (presetMouse.containsMouse ? Theme.borderHover : Theme.border)
                border.width: isCurrent ? 1.5 : 1
                opacity: isMirrorMissing ? 0.5 : 1.0

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        text: presetBtn.modelData.icon
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 10
                        color: presetBtn.isCurrent
                            ? (presetBtn.modelData.id === "mirror" ? (Theme.warning || "#F59E0B") : Theme.accent)
                            : Theme.textSecondary
                    }

                    Text {
                        text: presetBtn.modelData.label
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        font.weight: presetBtn.isCurrent ? Font.Bold : Font.DemiBold
                        color: presetBtn.isCurrent ? Theme.textPrimary : Theme.textSecondary
                    }
                }

                MouseArea {
                    id: presetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (presetBtn.isMirrorMissing) {
                            DisplayService.showFeedback("Install wl-mirror for screen cloning");
                            return;
                        }
                        root.applyPresetToDraft(presetBtn.modelData.id);
                    }
                }
            }
        }
    }

    // Single-monitor informational banner
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 8
        visible: root.draftOutputs.length <= 1
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
                text: "󰍹"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 13
                color: Theme.accent
            }

            Text {
                text: "Single monitor connected · Connect another display to arrange or clone"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 9
                color: Theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // ================= MONITOR SELECTOR TABS (WHEN 2+ MONITORS) =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 5
        visible: root.draftOutputs.length > 1

        Repeater {
            model: root.draftOutputs

            delegate: Rectangle {
                id: monTab
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 26
                radius: 7

                readonly property bool isSel: modelData.name === root.selectedOutputName
                readonly property bool isPrim: modelData.name === root.draftPrimary

                color: isSel ? Theme.surfaceActive : (tabMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                border.color: isSel ? Theme.accent : Theme.border
                border.width: isSel ? 1.5 : 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: (monTab.index + 1) + ". " + (monTab.isPrim ? "★ " : "") + monTab.modelData.name
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 9
                        font.weight: monTab.isSel ? Font.Bold : Font.DemiBold
                        color: monTab.modelData.enabled
                            ? (monTab.isSel ? Theme.textPrimary : Theme.textSecondary)
                            : Theme.textMuted
                    }

                    Text {
                        visible: !monTab.modelData.enabled
                        text: "OFF"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 7
                        font.weight: Font.Bold
                        color: Theme.danger
                    }
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedOutputName = monTab.modelData.name
                }
            }
        }
    }

    // ================= SELECTED MONITOR INSPECTOR =================
    Rectangle {
        id: inspectorCard
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 9
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        visible: root.selectedOutput !== null

        readonly property var out: root.selectedOutput
        readonly property bool isPrimary: out ? (out.name === root.draftPrimary) : false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // Inspector Header: Identity + Primary + On/Off
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: (inspectorCard.out && inspectorCard.out.isInternal) ? "󰌢" : "󰍹"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 16
                    color: (inspectorCard.out && inspectorCard.out.enabled) ? Theme.accent : Theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        spacing: 6

                        Text {
                            text: inspectorCard.out ? inspectorCard.out.name : ""
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                        }

                        Text {
                            text: inspectorCard.out ? inspectorCard.out.makeModel : ""
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 9
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: {
                            if (!inspectorCard.out) return "";
                            if (!inspectorCard.out.enabled) return "Output disabled (off)";
                            return "Logical: " + inspectorCard.out.width + "×" + inspectorCard.out.height +
                                   " · Pos: (" + inspectorCard.out.x + ", " + inspectorCard.out.y + ") · " +
                                   inspectorCard.out.refreshRate;
                        }
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        color: (inspectorCard.out && inspectorCard.out.enabled) ? Theme.textSecondary : Theme.danger
                    }
                }

                // Set Primary button
                Rectangle {
                    visible: root.draftOutputs.length > 1 && inspectorCard.out && inspectorCard.out.enabled
                    implicitWidth: primBtnLbl.implicitWidth + 12
                    implicitHeight: 22
                    radius: 5
                    color: inspectorCard.isPrimary
                        ? Theme.accent
                        : (primBtnMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                    border.color: inspectorCard.isPrimary ? Theme.accent : Theme.border
                    border.width: 1

                    Text {
                        id: primBtnLbl
                        anchors.centerIn: parent
                        text: inspectorCard.isPrimary ? "★ Primary" : "Set Primary"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: inspectorCard.isPrimary ? (Theme.badgeFocusedText || "#11111B") : Theme.textSecondary
                    }

                    MouseArea {
                        id: primBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (inspectorCard.out) root.setDraftPrimary(inspectorCard.out.name)
                    }
                }

                // Turn On / Off button
                Rectangle {
                    visible: root.draftOutputs.length > 1 && inspectorCard.out !== null
                    implicitWidth: enBtnLbl.implicitWidth + 12
                    implicitHeight: 22
                    radius: 5
                    readonly property bool isOn: inspectorCard.out ? inspectorCard.out.enabled : true
                    color: isOn
                        ? (enBtnMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                        : (Theme.success || Theme.accent)
                    border.color: isOn ? Theme.border : (Theme.success || Theme.accent)
                    border.width: 1
                    opacity: (isOn && root.draftEnabledCount <= 1) ? 0.4 : 1.0

                    Text {
                        id: enBtnLbl
                        anchors.centerIn: parent
                        text: (inspectorCard.out && inspectorCard.out.enabled) ? "Turn Off" : "Turn On"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: (inspectorCard.out && inspectorCard.out.enabled) ? Theme.textSecondary : "#11111B"
                    }

                    MouseArea {
                        id: enBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (inspectorCard.out) root.setDraftOutputEnabled(inspectorCard.out.name, !inspectorCard.out.enabled)
                    }
                }
            }

            // Scale & Rotation controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                visible: inspectorCard.out !== null && inspectorCard.out.enabled

                Text {
                    text: "Scale:"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    color: Theme.textMuted
                }

                Repeater {
                    model: root.scalePresets

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: scLbl.implicitWidth + 10
                        implicitHeight: 22
                        radius: 5

                        readonly property bool selected: inspectorCard.out && Math.abs(inspectorCard.out.scale - modelData.value) < 0.05

                        color: selected ? Theme.accent : (scMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                        border.color: selected ? Theme.accent : Theme.border
                        border.width: 1

                        Text {
                            id: scLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            font.weight: selected ? Font.Bold : Font.Normal
                            color: selected ? (Theme.badgeFocusedText || "#11111B") : Theme.textSecondary
                        }

                        MouseArea {
                            id: scMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (inspectorCard.out) root.setDraftScale(inspectorCard.out.name, modelData.value)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Rot:"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    color: Theme.textMuted
                }

                Repeater {
                    model: root.transformPresets

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: trLbl.implicitWidth + 9
                        implicitHeight: 22
                        radius: 5

                        readonly property bool selected: inspectorCard.out && inspectorCard.out.transform === modelData.value

                        color: selected ? Theme.accent : (trMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                        border.color: selected ? Theme.accent : Theme.border
                        border.width: 1

                        Text {
                            id: trLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: "JetBrainsMono Nerd Font Propo"
                            font.pixelSize: 8
                            font.weight: selected ? Font.Bold : Font.Normal
                            color: selected ? (Theme.badgeFocusedText || "#11111B") : Theme.textSecondary
                        }

                        MouseArea {
                            id: trMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (inspectorCard.out) root.setDraftTransform(inspectorCard.out.name, modelData.value)
                        }
                    }
                }
            }

            // Resolution & Refresh Rate Grid
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                visible: inspectorCard.out !== null && inspectorCard.out.enabled && inspectorCard.out.modes && inspectorCard.out.modes.length > 0

                Text {
                    text: "Resolution & Refresh Rate:"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    color: Theme.textMuted
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: modeFlow.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Flow {
                        id: modeFlow
                        width: parent.width
                        spacing: 5

                        Repeater {
                            model: (inspectorCard.out && inspectorCard.out.modes) ? inspectorCard.out.modes : []

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: mdLbl.implicitWidth + 12
                                implicitHeight: 22
                                radius: 5

                                readonly property bool selected: inspectorCard.out && inspectorCard.out.modeCmd === modelData.cmd

                                color: selected ? Theme.surfaceActive : (mdMouse.containsMouse ? Theme.surfaceHover : Theme.background)
                                border.color: selected ? Theme.accent : Theme.border
                                border.width: selected ? 1.5 : 1

                                Text {
                                    id: mdLbl
                                    anchors.centerIn: parent
                                    text: modelData.width + "×" + modelData.height + " @ " + modelData.refreshHz + "Hz" + (modelData.isPreferred ? " ★" : "")
                                    font.family: "JetBrainsMono Nerd Font Propo"
                                    font.pixelSize: 8
                                    font.weight: selected ? Font.Bold : Font.Normal
                                    color: selected ? Theme.accent : Theme.textSecondary
                                }

                                MouseArea {
                                    id: mdMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (inspectorCard.out) root.setDraftMode(inspectorCard.out.name, modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Disabled placeholder
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: inspectorCard.out !== null && !inspectorCard.out.enabled

                Text {
                    anchors.centerIn: parent
                    text: "This display is turned off · Click \"Turn On\" above to include it in the layout"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    color: Theme.textMuted
                }
            }
        }
    }

    // ================= FOOTER: HOTPLUG SETTING & APPLY/RESET ACTIONS =================
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        // Hotplug auto-prompt toggle
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 8
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 7
                spacing: 6

                Text {
                    text: "󰚥"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 11
                    color: DisplayService.autoPromptOnHotplug ? Theme.accent : Theme.textMuted
                }

                Text {
                    text: "Auto-open for new monitor setups"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pixelSize: 9
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    implicitWidth: hpToggleLbl.implicitWidth + 10
                    implicitHeight: 18
                    radius: 5
                    color: DisplayService.autoPromptOnHotplug ? Theme.accent : Theme.background
                    border.color: DisplayService.autoPromptOnHotplug ? Theme.accent : Theme.border
                    border.width: 1

                    Text {
                        id: hpToggleLbl
                        anchors.centerIn: parent
                        text: DisplayService.autoPromptOnHotplug ? "ON" : "OFF"
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: DisplayService.autoPromptOnHotplug ? (Theme.badgeFocusedText || "#11111B") : Theme.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DisplayService.setAutoPromptOnHotplug(!DisplayService.autoPromptOnHotplug)
                    }
                }
            }
        }

        // Discard / Reset button
        Rectangle {
            visible: root.hasPendingChanges
            implicitWidth: resetLbl.implicitWidth + 16
            implicitHeight: 30
            radius: 8
            color: resetMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: resetMouse.containsMouse ? Theme.borderHover : Theme.border
            border.width: 1

            Text {
                id: resetLbl
                anchors.centerIn: parent
                text: "Reset"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.textSecondary
            }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.syncDraftFromService(false)
            }
        }

        // Apply & Save button
        Rectangle {
            readonly property bool canApply: !DisplayService.isApplying && (root.hasPendingChanges || !DisplayService.hasSavedProfile)
            implicitWidth: applyLbl.implicitWidth + 20
            implicitHeight: 30
            radius: 8
            color: canApply ? Theme.accent : Theme.surface
            border.color: canApply ? Theme.accent : Theme.border
            border.width: 1
            opacity: DisplayService.isApplying ? 0.6 : (canApply ? (applyMouse.containsMouse ? 0.9 : 1.0) : 0.65)

            Text {
                id: applyLbl
                anchors.centerIn: parent
                text: DisplayService.isApplying
                    ? "Applying..."
                    : (root.hasPendingChanges ? "󰆓 Apply & Save" : "󰆓 Save Profile")
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: parent.canApply ? (Theme.badgeFocusedText || "#11111B") : Theme.textMuted
            }

            MouseArea {
                id: applyMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: parent.canApply
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.hasPendingChanges) {
                        root.commitDraft();
                    } else {
                        DisplayService.saveToNiriConfig();
                    }
                }
            }
        }
    }
}
