pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Standard user configuration path
    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/config.json"

    readonly property var defaults: ({
        "theme": {
            "current": "catppuccin",
            "iconSize": 14,
            "borderWidth": 1
        },
        "bar": {
            "longbar": false,
        },
        "clock": {
            "format24h": true,
            "showSeconds": false
        }
    })

    // Reactive in-memory state
    property var values: Object.assign({}, defaults)

    // Cache to prevent redundant JSON parsing if file content hasn't changed
    property string lastRawText: ""

    FileView {
        id: fileView
        path: root.configPath
        blockLoading: true
        watchChanges: true

        // onLoaded handles the initial read; onFileChanged handles external modifications
        onFileChanged: root.loadConfig()
        onLoaded: root.loadConfig()
    }

    // Component.onCompleted: root.loadConfig()

    function deepMerge(target, source) {
        var result = Object.assign({}, target);
        if (!source) return result;
        for (var key in source) {
            if (source[key] !== null && typeof source[key] === "object" && !Array.isArray(source[key])) {
                result[key] = deepMerge(target[key] || {}, source[key]);
            } else {
                result[key] = source[key];
            }
        }
        return result;
    }

    function loadConfig() {
        var rawText = fileView.text();

        // Skip parsing if content is unchanged
        if (rawText === root.lastRawText && rawText !== "") return;

        if (!rawText || rawText.trim() === "") {
            root.values = Object.assign({}, root.defaults);
            return;
        }
        try {
            var parsed = JSON.parse(rawText);
            root.values = deepMerge(root.defaults, parsed);
        } catch (e) {
            console.warn("[Config] Error parsing config.json:", e);
            root.values = Object.assign({}, root.defaults);
        }
    }

    readonly property var theme: values.theme
    readonly property var bar: values.bar
    readonly property var clock: values.clock

    function set(keyPath, newValue) {
        var current = JSON.parse(JSON.stringify(root.values));
        var keys = keyPath.split(".");
        var target = current;

        for (var i = 0; i < keys.length - 1; i++) {
            if (!target[keys[i]]) target[keys[i]] = {};
            target = target[keys[i]];
        }

        target[keys[keys.length - 1]] = newValue;
        root.values = current;
        save();
    }

    function save() {
        var formatted = JSON.stringify(root.values, null, 2);
        root.lastRawText = formatted;
        fileView.setText(formatted);
    }
}
