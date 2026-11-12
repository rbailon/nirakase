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

echo -e "  ${BLUE}[System]${NC} Synchronizing and upgrading package databases (preventing partial upgrades)..."
sudo pacman -Syu --noconfirm

# Separate official/repo packages from AUR-only packages
official_packages=(
    niri xwayland-satellite uwsm git xdg-utils paru
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    foot tmux zsh cachyos-zsh-config starship eza zoxide fzf bat awww
    playerctl brightnessctl power-profiles-daemon
    networkmanager networkmanager-openconnect networkmanager-openvpn nm-connection-editor python-gobject python-evdev
    nwg-look qt5ct qt6ct kvantum ttf-jetbrains-mono-nerd jq
    zen-browser-bin brave-origin-bin strata proton-pass neovim imagemagick wl-clipboard hyprpicker grim slurp satty libnotify
    wiremix btop impala bluetui upower curl pacman-contrib greetd greetd-tuigreet
    gnome-keyring libsecret quickshell
)

aur_packages=(
    xdg-terminal-exec
    yaru-icon-theme
    proton-pass-cli-bin
)

# Special: Verify if swaylock or swaylock-effects is already installed, if not, install swaylock-effects
if ! pacman -Qq swaylock-effects >/dev/null 2>&1 && ! pacman -Qq swaylock >/dev/null 2>&1; then
    aur_packages+=("swaylock-effects")
fi

official_to_install=()
aur_to_install=()

for pkg in "${official_packages[@]}"; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            official_to_install+=("$pkg")
        elif [ "$pkg" = "proton-pass" ]; then
            aur_to_install+=("proton-pass-bin")
        else
            aur_to_install+=("$pkg")
        fi
    fi
done

for pkg in "${aur_packages[@]}"; do
    # Skip proton-pass-cli-bin if pass-cli binary is already installed
    if [ "$pkg" = "proton-pass-cli-bin" ] && (command -v pass-cli >/dev/null 2>&1 || [ -x "$HOME/.local/bin/pass-cli" ]); then
        continue
    fi
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            official_to_install+=("$pkg")
        else
            aur_to_install+=("$pkg")
        fi
    fi
done

# Install official/configured repository packages
if [ ${#official_to_install[@]} -gt 0 ]; then
    echo -e "  ${BLUE}[System]${NC} Installing missing repository dependencies: ${official_to_install[*]}"
    sudo pacman -S --needed --noconfirm "${official_to_install[@]}"
fi

# Install AUR packages
if [ ${#aur_to_install[@]} -gt 0 ]; then
    # Verify paru availability and functionality (preventing libalpm version mismatches)
    if ! command -v paru >/dev/null 2>&1 || ! paru --version >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[!]${NC} paru is missing or has a library mismatch. Installing/refreshing paru via pacman..."
        if ! sudo pacman -S --noconfirm paru 2>/dev/null; then
            echo -e "  ${YELLOW}[!]${NC} Failed to install paru from repository. Building paru-bin from AUR as fallback..."
            sudo pacman -S --needed --noconfirm base-devel git
            TEMP_DIR=$(mktemp -d)
            echo -e "  ${BLUE}[System]${NC} Cloning paru-bin repository..."
            git clone https://aur.archlinux.org/paru-bin.git "$TEMP_DIR/paru-bin"
            echo -e "  ${BLUE}[System]${NC} Building and installing paru-bin..."
            (cd "$TEMP_DIR/paru-bin" && makepkg -si --noconfirm)
            rm -rf "$TEMP_DIR"
        fi
    fi

    echo -e "  ${BLUE}[System]${NC} Installing missing AUR dependencies: ${aur_to_install[*]}"
    paru -S --needed --noconfirm "${aur_to_install[@]}" || true
fi

# Fallback: Ensure Proton Pass CLI (pass-cli) is installed via official SHA-256 verified installer if AUR build failed
if ! command -v pass-cli >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/pass-cli" ]; then
    echo -e "  ${BLUE}[System]${NC} Installing Proton Pass CLI (pass-cli) via official Proton verified installer..."
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://proton.me/download/pass-cli/install.sh | bash || echo -e "  ${YELLOW}[!]${NC} Could not install pass-cli automatically."
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

# Helper function to recursively symlink files individually
link_files_recursively() {
    local source_dir="$1"
    local target_dir="$2"

    mkdir -p "$target_dir"

    # Find all files and symlinks in the source directory
    (
        cd "$source_dir" || exit 1
        find . -type f -o -type l | while read -r file; do
            # Remove leading './'
            file="${file#./}"
            local src_file="$source_dir/$file"
            local tgt_file="$target_dir/$file"
            
            # Ensure target parent directory exists
            mkdir -p "$(dirname "$tgt_file")"
            
            # Use safe_symlink to link the file
            safe_symlink "$src_file" "$tgt_file"
        done
    )
}

# 2. Deploy User Configs (Folder-level symlinking)
echo -e "\n${GREEN}[2/5] Applying user configurations (Dotfiles)...${NC}"

# Clean up obsolete config symlinks from previous versions
obsolete_configs=("waybar" "mako" "swayosd" "walker" "elephant" "hypr" "hypridle" "bash")
for obs in "${obsolete_configs[@]}"; do
    obs_path="$HOME/.config/$obs"
    if [ -L "$obs_path" ]; then
        rm -f "$obs_path"
        echo -e "  ${YELLOW}[-]${NC} Removed obsolete config symlink: $obs_path"
    fi
done

for dir in "$REPO_DIR/config"/*; do
    [ -d "$dir" ] || continue
    app_name=$(basename "$dir")
    
    # Skip directories that must be linked at the individual file-level
    if [ "$app_name" = "gtk-3.0" ] || [ "$app_name" = "gtk-4.0" ] || [ "$app_name" = "systemd" ]; then
        continue
    fi
    
    safe_symlink "$dir" "$HOME/.config/$app_name"
done

# 2.5. Deploy Special User Configs (File-level symlinking)
echo -e "\n${GREEN}[2.5/5] Applying modular configurations (File-level)...${NC}"
for special_dir in "gtk-3.0" "gtk-4.0" "systemd" "systemd/user"; do
    target="$HOME/.config/$special_dir"
    # If the target path exists and is a symlink, remove it to prevent issues
    if [ -L "$target" ]; then
        echo -e "  ${YELLOW}[!]${NC} Converting folder symlink to physical directory: $target"
        rm -f "$target"
    fi
    mkdir -p "$target"
done

# Clean up broken symlinks in ~/.config/systemd/user
if [ -d "$HOME/.config/systemd/user" ]; then
    find "$HOME/.config/systemd/user" -xtype l -delete 2>/dev/null || true
fi

link_files_recursively "$REPO_DIR/config/gtk-3.0" "$HOME/.config/gtk-3.0"
link_files_recursively "$REPO_DIR/config/gtk-4.0" "$HOME/.config/gtk-4.0"
link_files_recursively "$REPO_DIR/config/systemd" "$HOME/.config/systemd"

# Deploy individual system/user dotfiles (Bash configuration preserved alongside CachyOS Zsh)
safe_symlink "$REPO_DIR/system/bashrc" "$HOME/.bashrc"

# Ensure CachyOS Zsh configuration is present and Zsh is the default shell
if [ ! -f "$HOME/.zshrc" ] && [ -f "/etc/skel/.zshrc" ]; then
    cp "/etc/skel/.zshrc" "$HOME/.zshrc"
    echo -e "  ${GREEN}[✔]${NC} Initialized ~/.zshrc from CachyOS skeleton (/etc/skel/.zshrc)"
fi

if command -v zsh >/dev/null 2>&1; then
    current_shell=$(getent passwd "$USER" | cut -d: -f7)
    if [ "$current_shell" != "/bin/zsh" ] && [ "$current_shell" != "/usr/bin/zsh" ]; then
        sudo usermod -s /bin/zsh "$USER"
        echo -e "  ${GREEN}[✔]${NC} Configured Zsh (/bin/zsh) as the default user shell"
    fi
fi


# 3. Deploy Local Resources
echo -e "\n${GREEN}[3/5] Applying local resources (Nirakase Local)...${NC}"
mkdir -p "$HOME/.local/share/nirakase"

# Clean up legacy symlinks if they exist
for legacy_link in "$HOME/.local/share/nirakase/icons" "$HOME/.local/share/nirakase/bin"; do
    if [ -L "$legacy_link" ]; then
        rm -f "$legacy_link"
    fi
done

# Create default wallpaper.png symlink pointing to 1378545.jpg if not present
if [ ! -f "$HOME/.local/share/nirakase/wallpapers/wallpaper.png" ] && [ ! -L "$HOME/.local/share/nirakase/wallpapers/wallpaper.png" ]; then
    ln -sf "1378545.jpg" "$HOME/.local/share/nirakase/wallpapers/wallpaper.png"
    echo -e "  ${GREEN}[✔]${NC} Configured default wallpaper symlink (1378545.jpg)"
fi

# Ensure all scripts are executable
chmod +x "$REPO_DIR"/local/bin/* 2>/dev/null || true

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

# Set default browser to Zen Browser
if command -v xdg-settings >/dev/null 2>&1; then
    xdg-settings set default-web-browser zen.desktop 2>/dev/null || true
    echo -e "  ${GREEN}[✔]${NC} Configured Zen Browser as the default web browser"
fi

# Set default file manager to Strata if installed
if command -v xdg-mime >/dev/null 2>&1 && pacman -Qq strata >/dev/null 2>&1; then
    strata_desktop=$(pacman -Ql strata 2>/dev/null | awk '/\/usr\/share\/applications\/.*\.desktop$/ {print $2; exit}')
    if [ -n "$strata_desktop" ]; then
        xdg-mime default "$(basename "$strata_desktop")" inode/directory 2>/dev/null || true
        echo -e "  ${GREEN}[✔]${NC} Configured Strata as the default file manager"
    fi
fi

# Set GTK icon theme and font settings
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "Yaru-magenta-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 10" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 10" 2>/dev/null || true
    echo -e "  ${GREEN}[✔]${NC} Configured Yaru-magenta-dark GTK theme & JetBrains Mono Nerd Font"
fi

# Refresh font cache
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 || true
    echo -e "  ${GREEN}[✔]${NC} Refreshed system font cache (fc-cache)"
fi

# 5. Install System Files (Wayland Session, Locale & greetd Auto-login)
echo -e "\n${GREEN}[5/5] Installing system configurations (SUDO)...${NC}"

echo -e "  ${BLUE}[System]${NC} Configuring system locales (en_US.UTF-8 + es_ES.UTF-8) and Spanish keyboard layout..."
sudo sed -i 's/^#\s*\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sudo sed -i 's/^#\s*\(es_ES\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sudo locale-gen >/dev/null

sudo tee /etc/locale.conf > /dev/null << 'EOF'
LANG=en_US.UTF-8
LC_TIME=es_ES.UTF-8
LC_NUMERIC=es_ES.UTF-8
LC_MONETARY=es_ES.UTF-8
LC_PAPER=es_ES.UTF-8
LC_MEASUREMENT=es_ES.UTF-8
EOF
echo -e "  ${GREEN}[✔]${NC} Configured /etc/locale.conf (LANG=en_US.UTF-8 with es_ES.UTF-8 regional formats)"

sudo tee /etc/vconsole.conf > /dev/null << 'EOF'
KEYMAP=es
XKBLAYOUT=es
EOF
echo -e "  ${GREEN}[✔]${NC} Configured /etc/vconsole.conf (KEYMAP=es, XKBLAYOUT=es)"

sudo mkdir -p /usr/local/share/wayland-sessions/
sudo cp "$REPO_DIR/system/usr/local/share/wayland-sessions/nirakase.desktop" /usr/local/share/wayland-sessions/

# Configure default terminal for xdg-terminal-exec if not set
mkdir -p "$HOME/.config"
if [ ! -f "$HOME/.config/xdg-terminals.list" ]; then
    echo "foot.desktop" > "$HOME/.config/xdg-terminals.list"
    echo -e "  ${GREEN}[✔]${NC} Configured Foot as the default terminal"
fi

echo -e "\nConfiguring greetd + tuigreet Display Manager and Autologin for user $USER..."
known_dms=("sddm" "gdm" "lightdm" "ly" "lxdm" "slim" "nodm" "lemurs" "cosmic-greeter")
for dm in "${known_dms[@]}"; do
    if systemctl is-enabled "$dm.service" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}[!]${NC} Disabling active display manager: $dm"
        sudo systemctl disable "$dm.service" 2>/dev/null || true
    fi
done

# Remove legacy SDDM autologin configuration if present
if [ -f "/etc/sddm.conf.d/autologin.conf" ]; then
    echo -e "  ${BLUE}[System]${NC} Removing legacy /etc/sddm.conf.d/autologin.conf..."
    sudo rm -f /etc/sddm.conf.d/autologin.conf
fi

sudo mkdir -p /etc/greetd
sed "s/__USER__/$USER/g" "$REPO_DIR/system/etc/greetd/config.toml" | sudo tee /etc/greetd/config.toml > /dev/null
echo -e "  ${GREEN}[✔]${NC} Deployed /etc/greetd/config.toml (initial_session autologin + tuigreet)"

if ! systemctl is-enabled greetd.service >/dev/null 2>&1; then
    echo -e "  ${BLUE}[System]${NC} Enabling greetd.service..."
    sudo systemctl enable greetd.service 2>/dev/null || true
else
    echo -e "  ${GREEN}[✔]${NC} greetd.service is already enabled"
fi

# 5.5. Boot Optimization: Automatic Plymouth Removal & Silent Boot
echo -e "\n${GREEN}[5.5/5] Optimizing system boot (Plymouth removal & silent boot)...${NC}"

plymouth_detected=false
if pacman -Qq plymouth >/dev/null 2>&1 || pacman -Qq cachyos-plymouth-theme >/dev/null 2>&1 || grep -q "plymouth" /etc/mkinitcpio.conf 2>/dev/null; then
    plymouth_detected=true
fi

if [ "$plymouth_detected" = true ]; then
    echo -e "  ${BLUE}[System]${NC} Plymouth detected. Uninstalling packages..."
    sudo pacman -Rns --noconfirm plymouth cachyos-plymouth-theme plymouth-krunner-plugin 2>/dev/null || true
    
    # 1. Clean /etc/mkinitcpio.conf
    if grep -qE "\b(sd-)?plymouth\b" /etc/mkinitcpio.conf 2>/dev/null; then
        echo -e "  ${BLUE}[System]${NC} Removing plymouth hook from /etc/mkinitcpio.conf..."
        sudo sed -i -E 's/\b(sd-)?plymouth\b//g' /etc/mkinitcpio.conf
        sudo sed -i -E 's/HOOKS=\(( +)/HOOKS=\(/g; s/  +/ /g' /etc/mkinitcpio.conf
    fi

    # 2. Multi-bootloader detection and configuration update
    
    # 2a. Limine
    for limine_cfg in "/boot/limine.conf" "/boot/limine/limine.conf" "/etc/default/limine"; do
        if [ -f "$limine_cfg" ]; then
            echo -e "  ${BLUE}[System]${NC} Updating Limine boot configuration ($limine_cfg)..."
            sudo sed -i -E 's/\bsplash\b//g; s/\bplymouth\.enable=[01]\b//g' "$limine_cfg"
            if ! grep -q "quiet" "$limine_cfg"; then
                sudo sed -i -E 's/(cmdline|KERNEL_CMDLINE.*=.*")/\1 quiet /' "$limine_cfg"
            fi
        fi
    done

    # 2b. GRUB
    if [ -f "/etc/default/grub" ]; then
        echo -e "  ${BLUE}[System]${NC} Updating GRUB configuration..."
        sudo sed -i -E 's/\bsplash\b//g; s/\bplymouth\.enable=[01]\b//g' /etc/default/grub
        if ! grep -q "quiet" /etc/default/grub; then
            sudo sed -i -E 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet /' /etc/default/grub
        fi
        if command -v grub-mkconfig >/dev/null 2>&1; then
            echo -e "  ${BLUE}[System]${NC} Regenerating grub.cfg..."
            sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
        fi
    fi

    # 2c. systemd-boot
    for entry_dir in "/boot/loader/entries" "/efi/loader/entries"; do
        if [ -d "$entry_dir" ]; then
            echo -e "  ${BLUE}[System]${NC} Updating systemd-boot entries in $entry_dir..."
            for entry_file in "$entry_dir"/*.conf; do
                [ -f "$entry_file" ] || continue
                sudo sed -i -E 's/\bsplash\b//g; s/\bplymouth\.enable=[01]\b//g' "$entry_file"
                if ! grep -q "quiet" "$entry_file"; then
                    sudo sed -i -E 's/^options /options quiet /' "$entry_file"
                fi
            done
        fi
    done
    if [ -f "/etc/kernel/cmdline" ]; then
        sudo sed -i -E 's/\bsplash\b//g; s/\bplymouth\.enable=[01]\b//g' /etc/kernel/cmdline
    fi

    # 2d. rEFInd
    for refind_cfg in "/boot/refind_linux.conf" "/boot/EFI/refind/refind.conf"; do
        if [ -f "$refind_cfg" ]; then
            echo -e "  ${BLUE}[System]${NC} Updating rEFInd configuration..."
            sudo sed -i -E 's/\bsplash\b//g; s/\bplymouth\.enable=[01]\b//g' "$refind_cfg"
        fi
    done

    # 3. Regenerate Kernel Initramfs
    echo -e "  ${BLUE}[System]${NC} Regenerating initramfs images with mkinitcpio..."
    sudo mkinitcpio -P

    echo -e "  ${GREEN}[✔]${NC} Boot optimization complete (Plymouth removed, silent boot preserved)."
else
    echo -e "  ${GREEN}[✔]${NC} Plymouth is not present on this system."
fi

# 6. Enable Systemd User Services
echo -e "\nEnabling Systemd user daemons and services..."
systemctl --user daemon-reload

for service_file in "$REPO_DIR/config/systemd/user"/*.service; do
    [ -f "$service_file" ] || continue
    service_name=$(basename "$service_file")
    # On-demand unit: started by the pass-cli wrapper (local/bin/pass-cli) after 'pass-cli login'
    if [ "$service_name" = "proton-pass-agent.service" ]; then
        echo -e "  ${GREEN}[✔]${NC} On-demand unit: $service_name (starts after 'pass-cli login')"
        continue
    fi
    systemctl --user enable "$service_name"
    echo -e "  ${GREEN}[✔]${NC} Service enabled: $service_name"
done

echo -e "\n${PURPLE}========================================================================${NC}"
echo -e "${GREEN}             Nirakase Installation Completed Successfully              ${NC}"
echo -e "${PURPLE}========================================================================${NC}"
echo -e "${YELLOW}💡 Reboot your system to automatically start into your new environment.${NC}\n"
