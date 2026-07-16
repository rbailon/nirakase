# Nirakase

Nirakase is a minimal, elegant, and high-performance Wayland desktop environment configuration designed for Arch Linux / CachyOS, powered by the **Niri** window manager, **Waybar**, and interactive **FZF** terminal menus.

> !NOTE
> Inspired by Omarchy but not intended for developers

## Features

- **Niri Window Manager**: Highly optimized scroll-based tiling layout with window rules and custom keyboard shortcuts.
- **FZF Desktop Menu**: Interactive terminal-based menu for system triggers (screenshots, color picking), package management, WebApp creation, and system setup.
- **Color Picker**: Fast and lightweight color picker utilizing `hyprpicker` and `wl-clipboard` integrated directly into the capture submenu and keybinds (`Super+Alt+Print`).
- **Wallpaper Selector**: Persistent visual wallpaper changer daemon written in Quickshell/QML with accordion animation styling.
- **Unified Installer**: An idempotent `install.sh` script that manages backups, copies desktop portals, configures SDDM auto-login, and deploys all config symlinks.

## Directory Structure

```text
nirakase/
├── config/             # User configuration files (Niri, Waybar, Mako, Walker)
├── local/
│   ├── bin/            # Custom utility scripts and launchers
│   └── applications/   # WebApp shortcuts and .desktop entries
├── system/             # System-wide configuration (Wayland sessions, SDDM)
├── wallpapers/         # Default system backgrounds and wallpapers
├── install.sh          # Idempotent installer script
└── structure           # Directory and architecture map
```

## Installation

To deploy the Nirakase environment on your system, it is recommended to clone the repository to a temporary folder and run the installer:

```bash
git clone https://github.com/rbailon/nirakase.git /tmp/nirakase
cd /tmp/nirakase
chmod +x install.sh
./install.sh
```

> [!NOTE]
> The installer automatically detects if it is executed from a temporary location. If so, it relocates the entire repository to its official, persistent location at `~/.local/share/nirakase` and restarts execution from there. This ensures that the generated config symlinks under `~/.config/` remain persistent and do not break after a system reboot.

The script will automatically install missing system dependencies, back up conflicting files, create configuration symlinks under `~/.config`, and register the graphical session.
