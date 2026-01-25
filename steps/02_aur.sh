#!/bin/bash
# Step 2a: AUR packages (Arch Linux only)

backup_aur() {
    if [ "$SYSTEM_TYPE" = "arch" ] && [ "$INCLUDE_AUR" = true ]; then
        echo "[*] Backing up AUR packages..."
        if command -v yay >/dev/null 2>&1; then
            yay -Qqm > "$OUTPUT_DIR/pkglist-aur.txt"
            echo "✅ Exported $(wc -l < "$OUTPUT_DIR/pkglist-aur.txt") AUR packages"
        else
            echo "⚠️  Warning: yay not found, skipping AUR backup"
        fi
    else
        echo "⏭️  Skipping AUR backup (not Arch system or disabled)"
    fi
}

restore_aur() {
    if [ "$SYSTEM_TYPE" = "arch" ] && [ "$INCLUDE_AUR" = true ] && [ -f "$OUTPUT_DIR/pkglist-aur.txt" ]; then
        echo "[*] Restoring AUR packages..."
        if command -v yay >/dev/null 2>&1; then
            if [ "$CLEAN_INSTALL" = true ]; then
                echo "🧹 Removing AUR packages not in backup..."
                comm -23 <(yay -Qqm | sort) <(sort "$OUTPUT_DIR/pkglist-aur.txt") | xargs -r yay -Rns --noconfirm
            fi
            echo "📦 Installing AUR packages..."
            yay -S --needed - < "$OUTPUT_DIR/pkglist-aur.txt"
        else
            echo "⚠️  Warning: yay not found, skipping AUR restore"
        fi
    else
        echo "⏭️  Skipping AUR restore (not Arch system, disabled, or no backup)"
    fi
}

# Main execution
if [ "$OPERATION" = "backup" ]; then
    backup_aur
elif [ "$OPERATION" = "restore" ]; then
    restore_aur
fi
