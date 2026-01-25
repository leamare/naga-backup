#!/bin/bash
# Step 2b: Snap packages

backup_snap() {
    if [ "$INCLUDE_SNAP" = true ]; then
        echo "[*] Backing up Snap packages..."
        if command -v snap >/dev/null 2>&1; then
            snap list | awk 'NR>1 {print $1}' > "$OUTPUT_DIR/snap-packages.txt"
            echo "✅ Exported $(wc -l < "$OUTPUT_DIR/snap-packages.txt") snap packages"
        else
            echo "⚠️  Warning: snap not found, skipping snap backup"
        fi
    else
        echo "⏭️  Skipping snap backup (disabled)"
    fi
}

restore_snap() {
    if [ "$INCLUDE_SNAP" = true ] && [ -f "$OUTPUT_DIR/snap-packages.txt" ]; then
        echo "[*] Restoring Snap packages..."
        if command -v snap >/dev/null 2>&1; then
            while read -r package; do
                if [ -n "$package" ]; then
                    echo "📦 Installing snap package: $package"
                    sudo snap install "$package" --classic 2>/dev/null || sudo snap install "$package"
                fi
            done < "$OUTPUT_DIR/snap-packages.txt"
        else
            echo "⚠️  Warning: snap not found, skipping snap restore"
        fi
    else
        echo "⏭️  Skipping snap restore (disabled or no backup)"
    fi
}

# Main execution
if [ "$OPERATION" = "backup" ]; then
    backup_snap
elif [ "$OPERATION" = "restore" ]; then
    restore_snap
fi
