# Niri Compositor Agent Rules

Scoped rules for `config/niri/`. Inherited root rules in `AGENTS.md` also apply.

## 1. Modularity & Style
- Keep `config/niri/config.kdl` minimal as the module entry point; place actual configuration in the appropriate file under `config/niri/config.d/` (`autostart.kdl`, `input.kdl`, `outputs.kdl`, `layout.kdl`, `window-rules.kdl`, `animations.kdl`, `keybinds.kdl`).
- Write all comments, `hotkey-overlay-title` labels, and identifiers in English.
- Avoid introducing keybind conflicts with Neovim, Tmux, or terminal workflows.

## 2. IPC & Security
- Keep `spawn "quickshell" "ipc" "call" ...` targets and method names in `keybinds.kdl` synchronized with `IpcHandler` in `config/quickshell/shell.qml`.
- Prefer direct argument-array `spawn "cmd" "arg1" "arg2"` forms over `spawn "sh" "-c" ...` whenever possible.

## 3. Verification
- Always validate the full Niri configuration after any edit:
  - `niri validate -c config/niri/config.kdl`
  - `./scripts/verify.sh --changed`
