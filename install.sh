#!/usr/bin/env bash

# ========================================================================
#             Nirakase: Official Evironment Installer
# ========================================================================
# Intelligent, idempotent, and highly portable installer script.
# Handles backups automatically and supports continuous development.
# ========================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

echo -e "${PURPLE}========================================================================${NC}"
echo -e "${CYAN}             Starting Nirakase Official Installation                     ${NC}"
echo -e "${PURPLE}========================================================================${NC}\n"

# Verify executed from the repo root
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$REPO_DIR/structure" ]; then
    echo -e "${RED}[Error] Please run the installer from the root of its repository.${NC}"
    exit 1
fi

# Official persistent target location
TARGET_DIR="$HOME/.local/share/nirakase"

# Check if the repository needs to be relocated to its official location
if [ "$REPO_DIR" != "$TARGET_DIR" ]; then
    echo -e "  ${BLUE}[System]${NC} Deploying repository to its official location ($TARGET_DIR)..."
    
    # Ensure parent directory exists
    mkdir -p "$(dirname "$TARGET_DIR")"
    
    # If the target exists and is not physically the same as REPO_DIR, back it up to prevent data loss
    if [ -e "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
        if [ "$(readlink -f "$TARGET_DIR")" != "$(readlink -f "$REPO_DIR")" ]; then
            BACKUP_TARGET="${TARGET_DIR}.bak.$(date +%Y%m%d_%H%M%S)"
            echo -e "  ${YELLOW}[!]${NC} Destination occupied. Backing up previous installation to $BACKUP_TARGET"
            mv "$TARGET_DIR" "$BACKUP_TARGET"
        fi
    fi
    
    # Copy the repository to its official location (preserving files and permissions)
    # Using -T ensures files are copied inside target directory, not nested
    cp -rT "$REPO_DIR" "$TARGET_DIR"
    
    # Relaunch the installer from its official path and exit the current process
    echo -e "  ${GREEN}[✔]${NC} Relaunching installer from the official location..."
    exec "$TARGET_DIR/install.sh" "$@"
fi

# 1. Install System Dependencies
echo -e "${GREEN}[1/5] Synchronizing system dependencies...${NC}"

required_packages=(
    niri uwsm git xdg-utils xdg-terminal-exec 
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk 
    foot waybar mako swayosd awww walker fzf hypridle 
    playerctl brightnessctl power-profiles-daemon polkit-gnome network-manager-applet 
    nwg-look qt5ct qt6ct kvantum yaru-icon-theme ttf-jetbrains-mono-nerd jq
    chromium imagemagick socat wl-clipboard hyprpicker
)

# Special: Verify if swaylock or swaylock-effects is already installed, if not, install swaylock-effects
if ! pacman -Qq swaylock-effects >/dev/null 2>&1 && ! pacman -Qq swaylock >/dev/null 2>&1; then
    required_packages+=("swaylock-effects")
fi

pkgs_to_install=()
for pkg in "${required_packages[@]}"; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        pkgs_to_install+=("$pkg")
    fi
done

if [ ${#pkgs_to_install[@]} -gt 0 ]; then
    echo -e "  ${BLUE}[System]${NC} Installing missing dependencies: ${pkgs_to_install[*]}"
    sudo pacman -S --needed --noconfirm "${pkgs_to_install[@]}"
else
    echo -e "  ${GREEN}[✔]${NC} All system dependencies are already installed."
fi

# Helper function for safe, idempotent symlinking
safe_symlink() {
    local source="$1"
    local target="$2"

    # 0. If source and target are physically the same path, do nothing
    if [ -e "$source" ] && [ -e "$target" ] && [ "$(readlink -f "$source")" = "$(readlink -f "$target")" ]; then
        echo -e "  ${GREEN}[✔]${NC} Physical folder at destination: $(basename "$target")"
        return 0
    fi

    # 1. If target is already a symlink pointing to the correct source, skip
    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
        echo -e "  ${GREEN}[✔]${NC} Already linked: $(basename "$target")"
        return 0
    fi

    # 2. If target exists physically, backup to prevent data loss
    if [ -e "$target" ] || [ -L "$target" ]; then
        local backup="${target}.bak.$(date +%Y%m%d_%H%M%S)"
        echo -e "  ${YELLOW}[!]${NC} Conflict detected at $target. Backing up to $backup"
        mv "$target" "$backup"
    fi

    # 3. Ensure parent directory exists
    mkdir -p "$(dirname "$target")"

    # 4. Create the symlink
    ln -sf "$source" "$target"
    echo -e "  ${BLUE}[+]${NC} Link created: $(basename "$target") ➔ $target"
}

# 2. Deploy User Configs (Folder-level symlinking)
echo -e "\n${GREEN}[2/5] Applying user configurations (Dotfiles)...${NC}"
for dir in "$REPO_DIR/config"/*; do
    [ -d "$dir" ] || continue
    app_name=$(basename "$dir")
    safe_symlink "$dir" "$HOME/.config/$app_name"
done

# 3. Deploy Local Resources
echo -e "\n${GREEN}[3/5] Applying local resources (Nirakase Local)...${NC}"
mkdir -p "$HOME/.local/share/nirakase"

# Clean up legacy icons symlink if it exists
if [ -L "$HOME/.local/share/nirakase/icons" ]; then
    rm -f "$HOME/.local/share/nirakase/icons"
fi

# Link complete folders for scripts and wallpapers
safe_symlink "$REPO_DIR/local/bin" "$HOME/.local/share/nirakase/bin"
safe_symlink "$REPO_DIR/wallpapers" "$HOME/.local/share/nirakase/wallpapers"

# Ensure all scripts are executable
chmod +x "$REPO_DIR"/local/bin/*

# 4. Install and Port WebApps (.desktop) and Icons
echo -e "\n${GREEN}[4/5] Installing and porting WebApp shortcuts...${NC}"
mkdir -p "$HOME/.local/share/applications/icons"

# Copy pre-packaged icons physically to application icons directory
for icon_file in "$REPO_DIR/local/icons"/*.png; do
    [ -f "$icon_file" ] || continue
    dest_icon="$HOME/.local/share/applications/icons/$(basename "$icon_file")"
    rm -f "$dest_icon"
    cp "$icon_file" "$dest_icon"
done

for desktop_file in "$REPO_DIR/local/applications"/*.desktop; do
    [ -f "$desktop_file" ] || continue
    filename=$(basename "$desktop_file")
    dest="$HOME/.local/share/applications/$filename"
    
    # Remove broken links or old Stow files to prevent conflicts
    rm -f "$dest"
    
    # Copy static file to the final destination
    cp "$desktop_file" "$dest"
    
    # Dynamically replace old absolute icon paths with standard icon directory
    sed -i "s|/home/[a-zA-Z0-9_-]*/.local/share/applications/icons|$HOME/.local/share/applications/icons|g" "$dest"
    sed -i "s|/home/rbailon|$HOME|g" "$dest"
    chmod +x "$dest"
    
    echo -e "  ${GREEN}[✔]${NC} WebApp installed and ported: $filename"
done

# Set default browser to Chromium for first installation
if command -v xdg-settings >/dev/null 2>&1; then
    xdg-settings set default-web-browser chromium.desktop 2>/dev/null || true
    echo -e "  ${GREEN}[✔]${NC} Configured Chromium as the default web browser"
fi

# 5. Install System Files (Wayland Session & SDDM Auto-login)
echo -e "\n${GREEN}[5/5] Installing system configurations (SUDO)...${NC}"
sudo mkdir -p /usr/local/share/wayland-sessions/
sudo cp "$REPO_DIR/system/usr/local/share/wayland-sessions/nirakase.desktop" /usr/local/share/wayland-sessions/

echo -e "\nConfiguring Autologin in SDDM for user $USER..."
sudo mkdir -p /etc/sddm.conf.d/
echo -e "[Autologin]\nUser=$USER\nSession=nirakase" | sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null

# 6. Enable Systemd User Services
echo -e "\nEnabling Systemd user daemons and services..."
systemctl --user daemon-reload

for service_file in "$REPO_DIR/config/systemd/user"/*.service; do
    [ -f "$service_file" ] || continue
    service_name=$(basename "$service_file")
    systemctl --user enable "$service_name"
    echo -e "  ${GREEN}[✔]${NC} Service enabled: $service_name"
done

echo -e "\n${PURPLE}========================================================================${NC}"
echo -e "${GREEN}             Nirakase Installation Completed Successfully              ${NC}"
echo -e "${PURPLE}========================================================================${NC}"
echo -e "${YELLOW}💡 Reboot your system to automatically start into your new environment.${NC}\n"
