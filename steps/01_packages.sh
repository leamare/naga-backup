#!/bin/bash
# Step 1: Basic package management (pacman/apt/dnf)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/exclude.sh"

backup_packages() {
    echo "[*] Backing up basic packages..."

    case "$SYSTEM_TYPE" in
        "arch")
            if [ "$INCLUDE_PACMAN" = true ]; then
                echo "📦 Exporting pacman packages..."
                local tmp
                tmp=$(mktemp)
                pacman -Qqen > "$tmp"
                local count=0 skipped=0
                while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    if is_excluded "pacman" "$pkg"; then
                        skipped=$((skipped + 1))
                    else
                        echo "$pkg"
                        count=$((count + 1))
                    fi
                done < "$tmp" > "$OUTPUT_DIR/pkglist.txt"
                rm -f "$tmp"
                echo "✅ Exported $count pacman packages${skipped:+ ($skipped excluded)}"
            fi
            ;;
        "debian")
            if [ "$INCLUDE_PACMAN" = true ]; then
                echo "📦 Exporting apt packages..."
                local tmp
                tmp=$(mktemp)
                apt list --installed 2>/dev/null | grep -v "^Listing..." | cut -d'/' -f1 > "$tmp"
                local count=0 skipped=0
                while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    if is_excluded "pacman" "$pkg"; then
                        skipped=$((skipped + 1))
                    else
                        echo "$pkg"
                        count=$((count + 1))
                    fi
                done < "$tmp" > "$OUTPUT_DIR/pkglist.txt"
                rm -f "$tmp"
                echo "✅ Exported $count apt packages${skipped:+ ($skipped excluded)}"
            fi
            ;;
        "redhat")
            if [ "$INCLUDE_PACMAN" = true ]; then
                echo "📦 Exporting dnf packages..."
                local tmp
                tmp=$(mktemp)
                dnf list installed 2>/dev/null | grep -v "^Installed Packages" | awk '{print $1}' | cut -d'.' -f1 > "$tmp"
                local count=0 skipped=0
                while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    if is_excluded "pacman" "$pkg"; then
                        skipped=$((skipped + 1))
                    else
                        echo "$pkg"
                        count=$((count + 1))
                    fi
                done < "$tmp" > "$OUTPUT_DIR/pkglist.txt"
                rm -f "$tmp"
                echo "✅ Exported $count dnf packages${skipped:+ ($skipped excluded)}"
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
            while read -r pkg; do
                [[ -z "$pkg" ]] && continue
                is_excluded "pacman" "$pkg" && { echo "  ⏭️  Skipping excluded: $pkg"; continue; }
                if [ "$SYNC_DIFF" = true ] && pacman -Qq "$pkg" >/dev/null 2>&1; then
                    continue
                fi
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
                comm -23 <(apt list --installed 2>/dev/null | grep -v "^Listing..." | cut -d'/' -f1 | sort) <(sort "$OUTPUT_DIR/pkglist.txt") | xargs -r sudo apt remove --purge -y
            fi
            echo "📦 Installing apt packages..."
            sudo apt update
            while read -r pkg; do
                [[ -z "$pkg" ]] && continue
                is_excluded "pacman" "$pkg" && { echo "  ⏭️  Skipping excluded: $pkg"; continue; }
                sudo apt install -y "$pkg" || echo "⚠️  Failed to install: $pkg"
            done < "$OUTPUT_DIR/pkglist.txt"
            ;;
        "redhat")
            if [ "$CLEAN_INSTALL" = true ]; then
                echo "🧹 Removing packages not in backup..."
                comm -23 <(dnf list installed 2>/dev/null | grep -v "^Installed Packages" | awk '{print $1}' | cut -d'.' -f1 | sort) <(sort "$OUTPUT_DIR/pkglist.txt") | xargs -r sudo dnf remove -y
            fi
            echo "📦 Installing dnf packages..."
            while read -r pkg; do
                [[ -z "$pkg" ]] && continue
                is_excluded "pacman" "$pkg" && { echo "  ⏭️  Skipping excluded: $pkg"; continue; }
                sudo dnf install -y "$pkg" || echo "⚠️  Failed to install: $pkg"
            done < "$OUTPUT_DIR/pkglist.txt"
            ;;
        *)
            echo "⚠️  Warning: Unknown system type, skipping package restore"
            ;;
    esac
}

if [ "$OPERATION" = "backup" ]; then
    backup_packages
elif [ "$OPERATION" = "restore" ]; then
    restore_packages
fi
