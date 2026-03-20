#!/bin/bash
# Step 2a: AUR packages (Arch Linux only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/exclude.sh"

backup_aur() {
    if [ "$SYSTEM_TYPE" = "arch" ] && [ "$INCLUDE_AUR" = true ]; then
        echo "[*] Backing up AUR packages..."
        if command -v yay >/dev/null 2>&1; then
            local tmp count=0 skipped=0
            tmp=$(mktemp)
            yay -Qqm > "$tmp"
            while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                if is_excluded "aur" "$pkg"; then
                    skipped=$((skipped + 1))
                else
                    echo "$pkg"
                    count=$((count + 1))
                fi
            done < "$tmp" > "$OUTPUT_DIR/pkglist-aur.txt"
            rm -f "$tmp"
            echo "✅ Exported $count AUR packages${skipped:+ ($skipped excluded)}"
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
            while read -r pkg; do
                [[ -z "$pkg" ]] && continue
                is_excluded "aur" "$pkg" && { echo "  ⏭️  Skipping excluded: $pkg"; continue; }
                if [ "$SYNC_DIFF" = true ] && yay -Qq "$pkg" >/dev/null 2>&1; then
                    continue
                fi
                yay -S --needed --noconfirm "$pkg" || echo "⚠️  Failed to install AUR package: $pkg"
            done < "$OUTPUT_DIR/pkglist-aur.txt"
        else
            echo "⚠️  Warning: yay not found, skipping AUR restore"
        fi
    else
        echo "⏭️  Skipping AUR restore (not Arch system, disabled, or no backup)"
    fi
}

if [ "$OPERATION" = "backup" ]; then
    backup_aur
elif [ "$OPERATION" = "restore" ]; then
    restore_aur
fi
