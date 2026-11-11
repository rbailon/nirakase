pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // In-memory volatile history (never written to disk for security)
    property var history: []
    readonly property int count: history.length
    readonly property int maxItems: 60

    // Internal monotonic counter for unique entry IDs
    property int _nextId: 1
    // Track text copied from our own history to avoid redundant work
    property string _lastInternalCopy: ""

    // Pre-resolved icon for clipboard items
    readonly property string clipboardIconSource: {
        var icons = ["edit-paste", "klipper", "preferences-desktop-clipboard", "accessories-clipboard", "edit-copy", "text-x-generic"];
        for (var i = 0; i < icons.length; i++) {
            var p = Quickshell.iconPath(icons[i], true);
            if (p !== "") return p;
        }
        return "";
    }

    // Security heuristic: detect private keys or single-token high-entropy secrets
    function looksLikeSecret(text) {
        var trimmed = text.trim();
        if (trimmed === "") return true;

        // 1. Block PEM / SSH private keys
        if (/-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----/.test(trimmed)) {
            return true;
        }

        // 2. Check if it is a single continuous token (no whitespace, single line)
        // that looks like a password, API key, or bearer token
        if (!/\s/.test(trimmed) && trimmed.length >= 8 && trimmed.length <= 128) {
            // Do not block normal URLs, file paths, or email addresses
            if (/^(https?|ftp|file|ssh|git):\/\//i.test(trimmed)) return false;
            if (trimmed.startsWith("/") || trimmed.startsWith("~/") || trimmed.startsWith("./")) return false;
            if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) return false;

            var hasLower = /[a-z]/.test(trimmed);
            var hasUpper = /[A-Z]/.test(trimmed);
            var hasDigit = /[0-9]/.test(trimmed);
            var hasSymbol = /[^a-zA-Z0-9._\-\/:~]/.test(trimmed);

            // Standard complex password pattern: lower + upper + digit + special symbol
            if (hasLower && hasUpper && hasDigit && hasSymbol) {
                return true;
            }

            // Common API secret / token prefixes
            if (/^(ghp_|gho_|ghu_|ghs_|ghr_|glpat-|sk-[a-zA-Z0-9]{16,}|xox[baprs]-|AKIA[0-9A-Z]{16})/.test(trimmed)) {
                return true;
            }
        }

        return false;
    }

    function formatPreview(text) {
        var lines = text.split(/\r?\n/);
        var firstNonEmpty = "";
        var secondNonEmpty = "";
        for (var i = 0; i < lines.length; i++) {
            var clean = lines[i].trim();
            if (clean !== "") {
                if (firstNonEmpty === "") {
                    firstNonEmpty = clean.replace(/\s+/g, " ");
                } else if (secondNonEmpty === "") {
                    secondNonEmpty = clean.replace(/\s+/g, " ");
                    break;
                }
            }
        }

        if (firstNonEmpty === "") {
            firstNonEmpty = text.trim().replace(/\s+/g, " ");
        }

        var lineCount = lines.length;
        var charCount = text.length;
        var metaParts = [];

        if (lineCount > 1) {
            metaParts.push(lineCount + " lines");
        }
        metaParts.push(charCount + (charCount === 1 ? " char" : " chars"));

        if (secondNonEmpty !== "") {
            metaParts.push(secondNonEmpty);
        }

        return {
            title: firstNonEmpty,
            subtitle: metaParts.join(" • ")
        };
    }

    function addEntry(rawText) {
        if (!rawText) return;
        // Skip empty or whitespace-only copies
        if (rawText.trim() === "") return;

        // Security check: skip if it matches secret heuristics
        if (looksLikeSecret(rawText)) return;

        var preview = formatPreview(rawText);
        var titleLower = preview.title.toLowerCase();
        var fullLower = rawText.toLowerCase();

        var current = root.history.slice();

        // Deduplicate: if exact text already exists, remove old position and move to top
        for (var i = current.length - 1; i >= 0; i--) {
            if (current[i].fullText === rawText) {
                current.splice(i, 1);
            }
        }

        var item = {
            id: root._nextId++,
            isClipboard: true,
            isRemmina: false,
            fullText: rawText,
            name: preview.title,
            nameLower: titleLower,
            description: preview.subtitle,
            searchKey: fullLower,
            icon: root.clipboardIconSource
        };

        current.unshift(item);

        if (current.length > root.maxItems) {
            current.length = root.maxItems;
        }

        root.history = current;
    }

    function copyItem(item) {
        if (!item || !item.fullText) return;
        root._lastInternalCopy = item.fullText;

        // Promote selected item to top of history immediately
        var current = root.history.slice();
        var idx = -1;
        for (var i = 0; i < current.length; i++) {
            if (current[i].id === item.id || current[i].fullText === item.fullText) {
                idx = i;
                break;
            }
        }
        if (idx > 0) {
            var picked = current.splice(idx, 1)[0];
            current.unshift(picked);
            root.history = current;
        }

        copyProc.exec(["wl-copy", "--", item.fullText]);
    }

    function removeEntry(id) {
        var current = root.history.filter(function(item) {
            return item.id !== id;
        });
        root.history = current;
    }

    function clearAll() {
        root.history = [];
    }

    Process {
        id: copyProc
    }

    Timer {
        id: watcherRestartTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (!watcherProc.running) {
                watcherProc.running = true;
            }
        }
    }

    // Event-driven Wayland clipboard watcher (0% CPU when idle).
    // Filters out password manager entries (x-kde-passwordManagerHint, secret, sensitive)
    // and oversized/binary payloads before base64-encoding a single line to stdout.
    Process {
        id: watcherProc
        running: true
        command: [
            "sh", "-c",
            "exec wl-paste --type text --watch sh -c '" +
            "if [ \"${CLIPBOARD_STATE:-data}\" != \"data\" ]; then exit 0; fi; " +
            "types=$(wl-paste --list-types 2>/dev/null || true); " +
            "case \"$types\" in " +
            "  *x-kde-passwordManagerHint*|*password*|*secret*|*sensitive*) exit 0 ;; " +
            "esac; " +
            "data=$(wl-paste --no-newline --type text 2>/dev/null | head -c 65537 || true); " +
            "len=${#data}; " +
            "if [ \"$len\" -eq 0 ] || [ \"$len\" -gt 65536 ]; then exit 0; fi; " +
            "printf \"%s\" \"$data\" | base64 -w 0; printf \"\\n\"" +
            "'"
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var b64 = data.trim();
                if (b64 === "") return;
                try {
                    var binary = Qt.atob(b64);
                    // Properly decode UTF-8 bytes from Latin1 binary string
                    var decoded = decodeURIComponent(escape(binary));
                    root.addEntry(decoded);
                } catch (e) {
                    // Fallback if escape/decodeURIComponent fails on malformed sequences
                    try {
                        root.addEntry(Qt.atob(b64));
                    } catch (_) {}
                }
            }
        }

        onExited: watcherRestartTimer.restart()
    }
}
