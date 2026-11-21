# Quickshell (QML) Agent Rules

Scoped rules for `config/quickshell/`. Inherited root rules in `AGENTS.md` also apply.

## 1. Architecture & Registration
- Register every new component, widget, theme, or singleton in `config/quickshell/qmldir`.
- Every file declared as `singleton` in `qmldir` MUST begin with `pragma Singleton`.
- Keep UI presentation (`island/`, `components/`, `themes/`) decoupled from system state and backend logic (`services/`).
- Keep all `IpcHandler` methods in `shell.qml` synchronized with callers in `config/niri/config.d/keybinds.kdl` and `local/bin/*`.

## 2. QML Performance & Responsiveness
- Avoid heavy loops, JSON parsing, regex compilation, or allocations inside frequently re-evaluated property bindings.
- Debounce bursts of compositor/display/network events (e.g., short restartable `Timer` such as `DisplayService.scheduleRefresh`).
- Keep `Process` and `Timer` instances inactive (`running: false`) whenever their panel, popup, or widget is hidden, unless background monitoring is strictly required.
- Prefer event streams (`niri msg -j event-stream`, D-Bus signals, native Quickshell services) over periodic polling.

## 3. Privacy & Security
- **Clipboard (`services/ClipboardService.qml`)**: Keep clipboard history strictly in volatile memory (never write to disk) and preserve or strengthen `looksLikeSecret()` heuristics.
- **Authentication (`services/PolkitService.qml`, `island/AuthWidget.qml`)**: Never log, cache, or persist authentication responses, PINs, or passwords. Clear sensitive text fields immediately after submission or cancellation.
- **Subprocess safety**: Always invoke external commands via array form (`command: ["binary", arg1, arg2]`). Never pass untrusted text (window titles, SSIDs, notification text, clipboard entries) into `sh -c` or shell command strings.
- **Python helpers (`scripts/`)**: Close inherited file descriptors, bind child lifetime cleanly to parent (`PR_SET_PDEATHSIG` / signal handlers), and avoid busy-wait loops.

## 4. Verification
- Run `./scripts/verify.sh --changed` after every edit (validates `config.json`, `qmldir` integrity, Niri <-> Quickshell IPC contracts, Python helpers, and `qmllint` when installed).
- When modifying `shell.qml` or active services, inspect for undefined properties, binding loops, and missing imports before concluding.
