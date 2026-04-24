#!/bin/bash
# Step 2c: Flatpak applications

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/exclude.sh"

backup_flatpak() {
    if [ "$INCLUDE_FLATPAK" = true ]; then
        echo "[*] Backing up Flatpak applications..."
        if command -v flatpak >/dev/null 2>&1; then
            local tmp count=0 skipped=0
            tmp=$(mktemp)
            # Save app ID and installation scope (user/system) as "app|scope"
            flatpak list --app --columns=application,installation > "$tmp"
            while IFS=$'\t' read -r app install; do
                [ -z "$app" ] && continue
                if is_excluded "flatpak" "$app"; then
                    skipped=$((skipped + 1))
                else
                    echo "${app}|${install}"
                    count=$((count + 1))
                fi
            done < "$tmp" > "$OUTPUT_DIR/flatpak-apps.txt"
            rm -f "$tmp"
            echo "✅ Exported $count flatpak applications${skipped:+ ($skipped excluded)}"

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
            if [ -f "$OUTPUT_DIR/flatpak-remotes.txt" ]; then
                echo "[*] Ensuring Flatpak remotes exist..."
                mapfile -t existing_remotes < <(flatpak remotes | awk 'NR>1 {print $1}')
                for line in $(cat "$OUTPUT_DIR/flatpak-remotes.txt"); do
                    remote_name="${line%%|*}"
                    remote_url="${line#*|}"
                    local found=false
                    for r in "${existing_remotes[@]}"; do
                        [ "$r" = "$remote_name" ] && { found=true; break; }
                    done
                    if [ "$found" = false ]; then
                        echo "➕ Adding Flatpak remote: $remote_name -> $remote_url"
                        flatpak remote-add --if-not-exists "$remote_name" "$remote_url" || echo "⚠️  Failed adding remote $remote_name"
                    fi
                done
            fi

            while IFS= read -r line; do
                [ -z "$line" ] && continue
                if [[ "$line" == *"|"* ]]; then
                    app="${line%%|*}"
                    scope="${line#*|}"
                else
                    app="$line"
                    scope="system"
                fi
                is_excluded "flatpak" "$app" && { echo "  ⏭️  Skipping excluded: $app"; continue; }
                if [ "$SYNC_DIFF" = true ] && flatpak info "$app" >/dev/null 2>&1; then
                    continue
                fi
                echo "📦 Installing flatpak app: $app (--${scope})"
                flatpak install -y --noninteractive "--${scope}" flathub "$app" || echo "⚠️  Failed to install: $app"
            done < "$OUTPUT_DIR/flatpak-apps.txt"
        else
            echo "⚠️  Warning: flatpak not found, skipping flatpak restore"
        fi
    else
        echo "⏭️  Skipping flatpak restore (disabled or no backup)"
    fi
}

if [ "$OPERATION" = "backup" ]; then
    backup_flatpak
elif [ "$OPERATION" = "restore" ]; then
    restore_flatpak
fi
