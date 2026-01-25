#!/bin/bash
# Step 3: Desktop environment configurations (GNOME/KDE/XFCE)

backup_kde_configs() {
    echo "[*] Backing up KDE configurations..."
    local kde_dir="$OUTPUT_DIR/desktop/kde"
    mkdir -p "$kde_dir"
    
    # KDE Plasma settings
    if [ -d "$HOME/.config/plasma-workspace" ]; then
        cp -r "$HOME/.config/plasma-workspace" "$kde_dir/"
    fi
    
    # KDE applications
    if [ -d "$HOME/.config/kde.org" ]; then
        cp -r "$HOME/.config/kde.org" "$kde_dir/"
    fi
    
    # KDE global settings
    if [ -d "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]; then
        cp "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" "$kde_dir/"
    fi
    
    # KDE window manager settings
    if [ -d "$HOME/.config/kwinrc" ]; then
        cp "$HOME/.config/kwinrc" "$kde_dir/"
    fi
    
    # KDE file manager settings
    if [ -d "$HOME/.config/dolphinrc" ]; then
        cp "$HOME/.config/dolphinrc" "$kde_dir/"
    fi
    
    echo "✅ KDE configurations backed up"
}

restore_kde_configs() {
    echo "[*] Restoring KDE configurations..."
    local kde_dir="$OUTPUT_DIR/desktop/kde"
    
    if [ ! -d "$kde_dir" ]; then
        echo "⏭️  No KDE backup found, skipping"
        return
    fi
    
    # Restore KDE settings
    if [ -d "$kde_dir/plasma-workspace" ]; then
        cp -r "$kde_dir/plasma-workspace" "$HOME/.config/"
    fi
    
    if [ -d "$kde_dir/kde.org" ]; then
        cp -r "$kde_dir/kde.org" "$HOME/.config/"
    fi
    
    if [ -f "$kde_dir/plasma-org.kde.plasma.desktop-appletsrc" ]; then
        cp "$kde_dir/plasma-org.kde.plasma.desktop-appletsrc" "$HOME/.config/"
    fi
    
    if [ -f "$kde_dir/kwinrc" ]; then
        cp "$kde_dir/kwinrc" "$HOME/.config/"
    fi
    
    if [ -f "$kde_dir/dolphinrc" ]; then
        cp "$kde_dir/dolphinrc" "$HOME/.config/"
    fi
    
    echo "✅ KDE configurations restored"
}

backup_gnome_configs() {
    echo "[*] Backing up GNOME configurations..."
    local gnome_dir="$OUTPUT_DIR/desktop/gnome"
    mkdir -p "$gnome_dir"
    
    # GNOME settings
    if [ -d "$HOME/.config/dconf" ]; then
        cp -r "$HOME/.config/dconf" "$gnome_dir/"
    fi
    
    # GNOME extensions
    if [ -d "$HOME/.local/share/gnome-shell/extensions" ]; then
        cp -r "$HOME/.local/share/gnome-shell/extensions" "$gnome_dir/"
    fi
    
    # GNOME themes
    if [ -d "$HOME/.themes" ]; then
        cp -r "$HOME/.themes" "$gnome_dir/"
    fi
    
    # GNOME icons
    if [ -d "$HOME/.icons" ]; then
        cp -r "$HOME/.icons" "$gnome_dir/"
    fi
    
    # GNOME applications
    if [ -d "$HOME/.config/gnome-control-center" ]; then
        cp -r "$HOME/.config/gnome-control-center" "$gnome_dir/"
    fi
    
    # Export dconf settings
    if command -v dconf >/dev/null 2>&1; then
        dconf dump / > "$gnome_dir/dconf-settings.ini"
    fi
    
    echo "✅ GNOME configurations backed up"
}

restore_gnome_configs() {
    echo "[*] Restoring GNOME configurations..."
    local gnome_dir="$OUTPUT_DIR/desktop/gnome"
    
    if [ ! -d "$gnome_dir" ]; then
        echo "⏭️  No GNOME backup found, skipping"
        return
    fi
    
    # Restore GNOME settings
    if [ -d "$gnome_dir/dconf" ]; then
        cp -r "$gnome_dir/dconf" "$HOME/.config/"
    fi
    
    if [ -d "$gnome_dir/extensions" ]; then
        mkdir -p "$HOME/.local/share/gnome-shell/"
        cp -r "$gnome_dir/extensions" "$HOME/.local/share/gnome-shell/"
    fi
    
    if [ -d "$gnome_dir/.themes" ]; then
        cp -r "$gnome_dir/.themes" "$HOME/"
    fi
    
    if [ -d "$gnome_dir/.icons" ]; then
        cp -r "$gnome_dir/.icons" "$HOME/"
    fi
    
    if [ -d "$gnome_dir/gnome-control-center" ]; then
        cp -r "$gnome_dir/gnome-control-center" "$HOME/.config/"
    fi
    
    # Restore dconf settings
    if [ -f "$gnome_dir/dconf-settings.ini" ] && command -v dconf >/dev/null 2>&1; then
        dconf load / < "$gnome_dir/dconf-settings.ini"
    fi
    
    echo "✅ GNOME configurations restored"
}

backup_xfce_configs() {
    echo "[*] Backing up XFCE configurations..."
    local xfce_dir="$OUTPUT_DIR/desktop/xfce"
    mkdir -p "$xfce_dir"
    
    # XFCE settings
    if [ -d "$HOME/.config/xfce4" ]; then
        cp -r "$HOME/.config/xfce4" "$xfce_dir/"
    fi
    
    # XFCE themes
    if [ -d "$HOME/.themes" ]; then
        cp -r "$HOME/.themes" "$xfce_dir/"
    fi
    
    # XFCE icons
    if [ -d "$HOME/.icons" ]; then
        cp -r "$HOME/.icons" "$xfce_dir/"
    fi
    
    echo "✅ XFCE configurations backed up"
}

restore_xfce_configs() {
    echo "[*] Restoring XFCE configurations..."
    local xfce_dir="$OUTPUT_DIR/desktop/xfce"
    
    if [ ! -d "$xfce_dir" ]; then
        echo "⏭️  No XFCE backup found, skipping"
        return
    fi
    
    # Restore XFCE settings
    if [ -d "$xfce_dir/xfce4" ]; then
        cp -r "$xfce_dir/xfce4" "$HOME/.config/"
    fi
    
    if [ -d "$xfce_dir/.themes" ]; then
        cp -r "$xfce_dir/.themes" "$HOME/"
    fi
    
    if [ -d "$xfce_dir/.icons" ]; then
        cp -r "$xfce_dir/.icons" "$HOME/"
    fi
    
    echo "✅ XFCE configurations restored"
}

# Detect all available desktop environments
detect_all_desktops() {
    local desktops=()
    
    # Check for KDE
    if [ -d "$HOME/.config/plasma-workspace" ] || [ -d "$HOME/.config/kde.org" ] || [ -d "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]; then
        desktops+=("kde")
    fi
    
    # Check for GNOME
    if [ -d "$HOME/.config/dconf" ] || [ -d "$HOME/.local/share/gnome-shell/extensions" ] || [ -d "$HOME/.config/gnome-control-center" ]; then
        desktops+=("gnome")
    fi
    
    # Check for XFCE
    if [ -d "$HOME/.config/xfce4" ]; then
        desktops+=("xfce")
    fi
    
    # Check for other common DEs
    if [ -d "$HOME/.config/i3" ] || [ -d "$HOME/.i3" ]; then
        desktops+=("i3")
    fi
    
    if [ -d "$HOME/.config/openbox" ]; then
        desktops+=("openbox")
    fi
    
    if [ -d "$HOME/.config/bspwm" ]; then
        desktops+=("bspwm")
    fi
    
    if [ -d "$HOME/.config/sway" ]; then
        desktops+=("sway")
    fi
    
    echo "${desktops[@]}"
}

# Main execution
if [ "$OPERATION" = "backup" ]; then
    if [ "$INCLUDE_DESKTOP_CONFIGS" = true ]; then
        echo "[*] Detecting desktop environments..."
        local detected_desktops=($(detect_all_desktops))
        
        if [ ${#detected_desktops[@]} -eq 0 ]; then
            echo "⚠️  No desktop environments detected, skipping desktop config backup"
        else
            echo "🖥️  Found desktop environments: ${detected_desktops[*]}"
            
            for de in "${detected_desktops[@]}"; do
                case "$de" in
                    "kde")
                        backup_kde_configs
                        ;;
                    "gnome")
                        backup_gnome_configs
                        ;;
                    "xfce")
                        backup_xfce_configs
                        ;;
                    *)
                        echo "⚠️  Unsupported desktop environment: $de"
                        ;;
                esac
            done
        fi
    else
        echo "⏭️  Desktop config backup disabled"
    fi
elif [ "$OPERATION" = "restore" ]; then
    if [ "$INCLUDE_DESKTOP_CONFIGS" = true ]; then
        echo "[*] Restoring all available desktop configurations..."
        # Try to restore all desktop configs (user might have changed DE)
        backup_kde_configs
        backup_gnome_configs
        backup_xfce_configs
    else
        echo "⏭️  Desktop config restore disabled"
    fi
fi
