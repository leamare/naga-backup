#!/bin/bash
# Step 2c: Flatpak applications

backup_flatpak() {
    if [ "$INCLUDE_FLATPAK" = true ]; then
        echo "[*] Backing up Flatpak applications..."
        if command -v flatpak >/dev/null 2>&1; then
            # Export installed applications
            flatpak list --app --columns=application > "$OUTPUT_DIR/flatpak-apps.txt"
            echo "✅ Exported $(wc -l < "$OUTPUT_DIR/flatpak-apps.txt") flatpak applications"

            # Export configured remotes (name|url)
            flatpak remotes | awk 'NR>1 {print $1 "|" $3}' > "$OUTPUT_DIR/flatpak-remotes.txt" || true
            echo "✅ Exported $(wc -l < "$OUTPUT_DIR/flatpak-remotes.txt" 2>/dev/null || echo 0) flatpak remotes"
        else
            echo "⚠️  Warning: flatpak not found, skipping flatpak backup"
        fi
    else
        echo "⏭️  Skipping flatpak backup (disabled)"
    fi
}

restore_flatpak() {
    if [ "$INCLUDE_FLATPAK" = true ] && [ -f "$OUTPUT_DIR/flatpak-apps.txt" ]; then
        echo "[*] Restoring Flatpak applications..."
        if command -v flatpak >/dev/null 2>&1; then
            # Ensure required remotes exist before installing apps
            if [ -f "$OUTPUT_DIR/flatpak-remotes.txt" ]; then
                echo "[*] Ensuring Flatpak remotes exist..."
                # Build a set of existing remote names
                mapfile -t existing_remotes < <(flatpak remotes | awk 'NR>1 {print $1}')
                for line in $(cat "$OUTPUT_DIR/flatpak-remotes.txt"); do
                    remote_name="${line%%|*}"
                    remote_url="${line#*|}"
                    # Check if remote exists
                    found=false
                    for r in "${existing_remotes[@]}"; do
                        if [ "$r" = "$remote_name" ]; then
                            found=true
                            break
                        fi
                    done
                    if [ "$found" = false ]; then
                        echo "➕ Adding Flatpak remote: $remote_name -> $remote_url"
                        flatpak remote-add --if-not-exists "$remote_name" "$remote_url" || echo "⚠️  Failed adding remote $remote_name"
                    fi
                done
            fi

            while read -r app; do
                if [ -n "$app" ]; then
                    echo "📦 Installing flatpak app: $app"
                    flatpak install -y --noninteractive flathub "$app" 2>/dev/null || echo "⚠️  Failed to install: $app"
                fi
            done < "$OUTPUT_DIR/flatpak-apps.txt"
        else
            echo "⚠️  Warning: flatpak not found, skipping flatpak restore"
        fi
    else
        echo "⏭️  Skipping flatpak restore (disabled or no backup)"
    fi
}

# Main execution
if [ "$OPERATION" = "backup" ]; then
    backup_flatpak
elif [ "$OPERATION" = "restore" ]; then
    restore_flatpak
fi
