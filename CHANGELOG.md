# Changelog

All notable changes to the **Nirakase** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.3] - 2026-11-12

### Added
- modified shortcuts to move windows in and out of workspaces

### Fixed
- shortcut conflict with Neovim

## [2.0.2] - 2026-11-12

### Fixed
- fix(tmux): added new shortcut

## [2.0.1] - 2026-11-12

### Fixed
- fix(proton-pass): start SSH agent on demand after pass-cli login

## [2.0.0] - 2026-11-11

### Added
- **Unified Quickshell Control Center (`ControlCenterWidget.qml`)**: Integrated quick toggles (`QuickToggleTile.qml`), system sliders (`SystemSlider.qml`), and expandable selector panels for Wi-Fi (`WifiSelectorPanel.qml`), Bluetooth (`BluetoothSelectorPanel.qml`), Audio (`AudioSelectorPanel.qml`), and Idle / Night Light (`IdleSelectorPanel.qml`).
- **Native Quickshell Services**:
  - `AudioService.qml`: Native PipeWire/Wpctl audio volume, mute, and sink/source selector management.
  - `NetworkService.qml` & `local/bin/nirakase-nm-agent`: Full Wi-Fi scanning, connection management, and custom NetworkManager secret agent.
  - `BluetoothService.qml`: Native Bluetooth adapter toggle, device discovery, pairing, and connection state.
  - `PolkitService.qml` & `AuthWidget.qml`: Native Polkit authentication agent integrated directly into the Quickshell island.
  - `MediaService.qml` & `MediaIsland.qml`: Dynamic MPRIS media player controls and visualizer in the top bar.
  - `IdleService.qml`: Native idle inhibition, screen blanking, lock, and suspend orchestration.
  - `PowerService.qml`: Native UPower battery monitoring and `power-profiles-daemon` switching.
  - `ClipboardService.qml`: Native clipboard history integration inside the Quickshell launcher.
- **System Tray & Network Island Widgets**: Added `SystemTrayWidget.qml` and `NetworkWidget.qml` to the Dynamic Island bar.
- **Proton Pass & SSH Agent**: Added `proton-pass-agent.service` and `proton-pass-agent.path` user systemd units for `pass-cli` SSH agent integration.
- **Display Manager (`greetd` + `tuigreet`)**: Added `system/etc/greetd/config.toml` with initial session auto-login and `tuigreet` fallback, replacing SDDM.
- **Tmux Configuration**: Added custom `config/tmux/` setup.
- **Release Automation**: Added `VERSION`, `CHANGELOG.md`, and `release.sh` for semantic versioning and automated Git/GitHub releases.

### Changed
- **Quickshell Shell & Launcher (`shell.qml`, `LauncherWidget.qml`)**: Expanded launcher with multi-mode support (Apps, WebApps, Remmina remote connections, Emoji/Symbols, Calculator, and Clipboard history), replacing Walker and Elephant.
- **Niri Configuration (`config/niri/`)**: Updated `autostart.kdl`, `keybinds.kdl`, and `window-rules.kdl` to communicate exclusively with Quickshell IPC endpoints (`quickshell ipc call ...`).
- **Screenshot & Color Picker (`nirakase-capture-screenshot`, `nirakase-menu-fzf`)**: Integrated `hyprpicker` color picker into capture menus and streamlined screenshot workflows with `grim`, `slurp`, and `satty`.
- **Default Applications & Shell**: Set **Zen Browser** (`zen-browser-bin`) as default browser, **Brave Origin** (`brave-origin-bin`) for isolated WebApps, **Strata** (`strata`) as file manager, and CachyOS **Zsh** as default user shell while preserving modular Bash configs.
- **Installer (`install.sh`)**: Added automatic cleanup of obsolete config symlinks (`waybar`, `mako`, `swayosd`, `walker`, `elephant`, `hypr`), `greetd` migration, locale setup (`en_US.UTF-8` + `es_ES.UTF-8`), and multi-bootloader Plymouth removal.

### Removed
- **Discontinued Standalone Services & Configs**:
  - Removed `waybar` (`config/waybar/`, `waybar.service`, `nirakase-waybar-*`).
  - Removed `mako` notification daemon (`config/mako/`, `mako.service`).
  - Removed `swayosd` (`config/swayosd/`, `swayosd.service`).
  - Removed `walker` and `elephant` (`config/walker/`, `config/elephant/`, `walker.service`, `elephant.service`, `nirakase-launch-walker`).
  - Removed `hyprland` and `hypridle` legacy configs (`config/hypr/`, `hypridle.service`).
  - Removed `polkit-gnome.service` and `nm-applet.service` in favor of native Quickshell services.
  - Removed obsolete helper scripts (`nirakase-battery-*`, `nirakase-launch-audio`, `nirakase-launch-bluetooth`, `nirakase-launch-wifi`, `nirakase-update-available`, `nirakase-weather`, `nirakase-tz-select`, `nirakase-logo`, `nirakase-show-done`).
  - Removed standalone `NotificationCenterWidget.qml`, `WifiWidget.qml`, and `ShadowEffect.qml` (superseded by `ControlCenterWidget.qml` and `NetworkWidget.qml`).

## [1.0.0] - 2026-10-12

### Added
- Initial stable architecture of **Nirakase** for Niri Wayland compositor.
- First iteration of the Quickshell island bar, wallpaper switcher (`awww`), FZF menus, WebApp creator, and modular installation script.
