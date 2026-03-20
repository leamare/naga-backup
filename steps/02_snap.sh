#!/bin/bash
# Step 2b: Snap packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/exclude.sh"

backup_snap() {
    if [ "$INCLUDE_SNAP" = true ]; then
        echo "[*] Backing up Snap packages..."
        if command -v snap >/dev/null 2>&1; then
            local tmp count=0 skipped=0
            tmp=$(mktemp)
            snap list 2>/dev/null | awk 'NR>1 {print $1}' > "$tmp"
            while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                if is_excluded "snap" "$pkg"; then
                    skipped=$((skipped + 1))
                else
                    echo "$pkg"
                    count=$((count + 1))
                fi
            done < "$tmp" > "$OUTPUT_DIR/snap-packages.txt"
            rm -f "$tmp"
            echo "✅ Exported $count snap packages${skipped:+ ($skipped excluded)}"
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
                [ -z "$package" ] && continue
                is_excluded "snap" "$package" && { echo "  ⏭️  Skipping excluded: $package"; continue; }
                if [ "$SYNC_DIFF" = true ] && snap list "$package" >/dev/null 2>&1; then
                    continue
                fi
                echo "📦 Installing snap package: $package"
                sudo snap install "$package" --classic 2>/dev/null || sudo snap install "$package"
            done < "$OUTPUT_DIR/snap-packages.txt"
        else
            echo "⚠️  Warning: snap not found, skipping snap restore"
        fi
    else
        echo "⏭️  Skipping snap restore (disabled or no backup)"
    fi
}

if [ "$OPERATION" = "backup" ]; then
    backup_snap
elif [ "$OPERATION" = "restore" ]; then
    restore_snap
fi
