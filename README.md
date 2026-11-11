# Nirakase

Nirakase is a minimal, elegant, and high-performance Wayland desktop environment configuration designed for Arch Linux / CachyOS, powered by the **Niri** scrollable-tiling compositor, a unified **Quickshell** desktop shell, and interactive **FZF** terminal menus.

> [!NOTE]
> My custom environment based on Niri and managed by `uwsm` (inspired by Omarchy, tailored for personal daily use rather than a full developer suite).

## Features

- **Niri Window Manager**: Scroll-based tiling layout with clean modular rules (`config.d/`), custom animations, and intuitive keyboard shortcuts.
- **Quickshell Unified Desktop Shell**: Custom QML shell featuring a Dynamic Island bar, Control Center (Wi-Fi via custom NetworkManager agent, Bluetooth, Audio, Power Profiles, Night Light), OSD, Notification daemon, Application & WebApp Launcher (with Remmina integration), Polkit authentication agent, Idle manager, and Theme selector.
- **FZF Desktop Menu**: Interactive terminal-based menu (`nirakase-menu-fzf`) for system triggers (screenshots, color picking), package management (`pacman`/`paru`), WebApp creation, default applications, and system updates.
- **Color Picker**: Fast and lightweight color picker utilizing `hyprpicker` and `wl-clipboard` integrated directly into the capture submenu and keybinds (`Super+Alt+Print`).
- **Wallpaper Selector**: Persistent visual wallpaper changer written in Quickshell/QML (`nirakase-menu-images`) powered by `awww`.
- **Proton Pass & SSH Agent**: Preconfigured `proton-pass` desktop integration and `proton-pass-agent.service` (`pass-cli`) providing a seamless SSH agent socket.
- **Default Applications & Shell**: Preconfigured with **Zen Browser** (`zen-browser-bin`) as default browser, **Brave Origin** (`brave-origin-bin`) for dedicated `--app=` WebApps, **Strata** file manager (`strata`), **Foot** terminal (`foot`), and CachyOS **Zsh** as default shell while preserving Nirakase's modular **Bash** configuration.
- **Unified Installer**: An idempotent `install.sh` script that synchronizes dependencies (`pacman`/`paru`), cleans obsolete symlinks, configures `greetd` + `tuigreet` auto-login, and deploys all configuration symlinks.
- **Boot Optimization**: Automatic detection and removal of Plymouth splash screen and initramfs hooks to minimize system boot time while preserving silent boot (`quiet`) across supported bootloaders (Limine, GRUB, systemd-boot, rEFInd).

## Directory Structure

```text
nirakase/
├── config/             # User configuration files (Niri, Quickshell, Foot, Tmux, Neovim, UWSM, etc.)
├── default/
│   └── bash/           # Modular Bash environment (aliases, envs, functions, init, shell)
├── local/
│   ├── applications/   # WebApp shortcuts and .desktop entries
│   ├── bin/            # Custom utility scripts and launchers
│   └── icons/          # High-definition icons for WebApps
├── system/             # System-wide configuration (Wayland sessions, greetd, bashrc)
├── wallpapers/         # Default system backgrounds and wallpapers
├── install.sh          # Idempotent installer script
├── release.sh          # Semantic versioning and release automation script
├── VERSION             # Current environment version
├── CHANGELOG.md        # Detailed version history
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

The script will automatically install missing system dependencies, back up conflicting files, create configuration symlinks under `~/.config`, register the graphical session, and optimize system boot by removing Plymouth and regenerating kernel initramfs images.
