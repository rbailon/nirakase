#!/usr/bin/env bash
# ==============================================================================
# Nirakase: install.sh
# Description: Official installation script for the Nirakase Desktop Environment.
# License: MIT License | Copyright (c) 2026-present rbailon
# ==============================================================================

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

echo -e "  ${BLUE}[System]${NC} Synchronizing package databases..."
sudo pacman -Sy

# Separate official packages from AUR-only packages
official_packages=(
    niri uwsm git xdg-utils
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk 
    foot waybar mako swayosd awww fzf hypridle 
    playerctl brightnessctl power-profiles-daemon polkit-gnome network-manager-applet 
    nwg-look qt5ct qt6ct kvantum ttf-jetbrains-mono-nerd jq
    chromium neovim imagemagick socat wl-clipboard hyprpicker
    wiremix btop gum impala bluetui upower curl pamixer
)

aur_packages=(
    xdg-terminal-exec
    walker
    elephant
    elephant-providerlist
    elephant-desktopapplications
    yaru-icon-theme
)

# Special: Verify if swaylock or swaylock-effects is already installed, if not, install swaylock-effects (from AUR)
if ! pacman -Qq swaylock-effects >/dev/null 2>&1 && ! pacman -Qq swaylock >/dev/null 2>&1; then
    aur_packages+=("swaylock-effects")
fi

official_to_install=()
for pkg in "${official_packages[@]}"; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        official_to_install+=("$pkg")
    fi
done

aur_to_install=()
for pkg in "${aur_packages[@]}"; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        aur_to_install+=("$pkg")
    fi
done

# Install official packages
if [ ${#official_to_install[@]} -gt 0 ]; then
    echo -e "  ${BLUE}[System]${NC} Installing missing official dependencies: ${official_to_install[*]}"
    sudo pacman -S --needed --noconfirm "${official_to_install[@]}"
fi

# Install AUR packages
if [ ${#aur_to_install[@]} -gt 0 ]; then
    # Bootstrapping paru if it is not installed
    if ! command -v paru >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[!]${NC} paru (AUR helper) is required but not installed. Setting up paru-bin..."
        sudo pacman -S --needed --noconfirm base-devel git
        TEMP_DIR=$(mktemp -d)
        echo -e "  ${BLUE}[System]${NC} Cloning paru-bin repository..."
        git clone https://aur.archlinux.org/paru-bin.git "$TEMP_DIR/paru-bin"
        echo -e "  ${BLUE}[System]${NC} Building and installing paru-bin..."
        (cd "$TEMP_DIR/paru-bin" && makepkg -si --noconfirm)
        rm -rf "$TEMP_DIR"
    fi

    echo -e "  ${BLUE}[System]${NC} Installing missing AUR dependencies: ${aur_to_install[*]}"
    paru -S --needed --noconfirm "${aur_to_install[@]}"
fi

if [ ${#official_to_install[@]} -eq 0 ] && [ ${#aur_to_install[@]} -eq 0 ]; then
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

# Create default wallpaper.png symlink pointing to 1378545.jpg if not present
if [ ! -f "$HOME/.local/share/nirakase/wallpapers/wallpaper.png" ] && [ ! -L "$HOME/.local/share/nirakase/wallpapers/wallpaper.png" ]; then
    ln -sf "1378545.jpg" "$HOME/.local/share/nirakase/wallpapers/wallpaper.png"
    echo -e "  ${GREEN}[✔]${NC} Configured default wallpaper symlink (1378545.jpg)"
fi

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

# Configure default terminal for xdg-terminal-exec if not set
mkdir -p "$HOME/.config"
if [ ! -f "$HOME/.config/xdg-terminals.list" ]; then
    echo "foot.desktop" > "$HOME/.config/xdg-terminals.list"
    echo -e "  ${GREEN}[✔]${NC} Configured Foot as the default terminal"
fi

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
