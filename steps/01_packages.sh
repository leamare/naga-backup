#!/bin/bash
# Step 1: Basic package management (pacman/apt/dnf)

backup_packages() {
    echo "[*] Backing up basic packages..."
    
    case "$SYSTEM_TYPE" in
        "arch")
            if [ "$INCLUDE_PACMAN" = true ]; then
                echo "📦 Exporting pacman packages..."
                pacman -Qqen > "$OUTPUT_DIR/pkglist.txt"
                echo "✅ Exported $(wc -l < "$OUTPUT_DIR/pkglist.txt") pacman packages"
            fi
            ;;
        "debian")
            if [ "$INCLUDE_PACMAN" = true ]; then
                echo "📦 Exporting apt packages..."
                apt list --installed | grep -v "^Listing..." | cut -d'/' -f1 > "$OUTPUT_DIR/pkglist.txt"
                echo "✅ Exported $(wc -l < "$OUTPUT_DIR/pkglist.txt") apt packages"
            fi
            ;;
        "redhat")
            if [ "$INCLUDE_PACMAN" = true ]; then
                echo "📦 Exporting dnf packages..."
                dnf list installed | grep -v "^Installed Packages" | awk '{print $1}' | cut -d'.' -f1 > "$OUTPUT_DIR/pkglist.txt"
                echo "✅ Exported $(wc -l < "$OUTPUT_DIR/pkglist.txt") dnf packages"
            fi
            ;;
        *)
            echo "⚠️  Warning: Unknown system type, skipping package backup"
            ;;
    esac
}

restore_packages() {
    echo "[*] Restoring basic packages..."
    
    if [ ! -f "$OUTPUT_DIR/pkglist.txt" ]; then
        echo "⚠️  Warning: Package list not found, skipping package restore"
        return
    fi
    
    # Check system compatibility
    local backup_system=""
    if [ -f "$OUTPUT_DIR/system-info.txt" ]; then
        backup_system=$(grep "SYSTEM_TYPE" "$OUTPUT_DIR/system-info.txt" | cut -d'=' -f2)
    fi
    
    if [ -n "$backup_system" ] && [ "$backup_system" != "$SYSTEM_TYPE" ]; then
        echo "❌ Error: System type mismatch!"
        echo "   Backup was created on: $backup_system"
        echo "   Current system is: $SYSTEM_TYPE"
        echo "   Cannot restore packages between different system types"
        exit 1
    fi
    
    case "$SYSTEM_TYPE" in
        "arch")
            if [ "$CLEAN_INSTALL" = true ]; then
                echo "🧹 Removing packages not in backup..."
                comm -23 <(pacman -Qqen | sort) <(sort "$OUTPUT_DIR/pkglist.txt") | xargs -r sudo pacman -Rns --noconfirm
            fi
            echo "📦 Installing pacman packages (resilient)..."
            # Install packages one by one so missing/broken packages don't abort the whole step
            while read -r pkg; do
                [[ -z "$pkg" ]] && continue
                if sudo pacman -Si "$pkg" >/dev/null 2>&1; then
                    sudo pacman -S --needed --noconfirm "$pkg" || echo "⚠️  Failed to install pacman package: $pkg"
                else
                    echo "⚠️  Package not found in repositories: $pkg"
                fi
            done < "$OUTPUT_DIR/pkglist.txt"
            ;;
        "debian")
            if [ "$CLEAN_INSTALL" = true ]; then
                echo "🧹 Removing packages not in backup..."
                comm -23 <(apt list --installed | grep -v "^Listing..." | cut -d'/' -f1 | sort) <(sort "$OUTPUT_DIR/pkglist.txt") | xargs -r sudo apt remove --purge -y
            fi
            echo "📦 Installing apt packages..."
            sudo apt update
            xargs -a "$OUTPUT_DIR/pkglist.txt" sudo apt install -y
            ;;
        "redhat")
            if [ "$CLEAN_INSTALL" = true ]; then
                echo "🧹 Removing packages not in backup..."
                comm -23 <(dnf list installed | grep -v "^Installed Packages" | awk '{print $1}' | cut -d'.' -f1 | sort) <(sort "$OUTPUT_DIR/pkglist.txt") | xargs -r sudo dnf remove -y
            fi
            echo "📦 Installing dnf packages..."
            xargs -a "$OUTPUT_DIR/pkglist.txt" sudo dnf install -y
            ;;
        *)
            echo "⚠️  Warning: Unknown system type, skipping package restore"
            ;;
    esac
}

# Main execution
if [ "$OPERATION" = "backup" ]; then
    backup_packages
elif [ "$OPERATION" = "restore" ]; then
    restore_packages
fi
