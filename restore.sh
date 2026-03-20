#!/bin/bash
set -e

source ./lib/ui.sh
source ./lib/cli.sh
source ./lib/exclude.sh
source ./lib/postinstall.sh
source ./lib/preflight.sh

parse_args "$@"
validate_system
check_dependencies

STEPS_DIR="./steps"
OUTPUT_DIR="./output"

if [ "$SYNC_DIFF" = true ]; then
    echo "🔄 Starting sync from: $ARCHIVE_PATH"
else
    echo "🔄 Starting restore from: $ARCHIVE_PATH"
fi
echo "🔍 Current system: $SYSTEM_TYPE ($PACKAGE_MANAGER)"
echo "🖥️  Desktop: $DESKTOP_ENV"
echo ""

echo "[*] Extracting archive..."
tar -xzf "$ARCHIVE_PATH" -C "$OUTPUT_DIR/"

if [ -f "$OUTPUT_DIR/system-info.txt" ]; then
    backup_system=$(grep "SYSTEM_TYPE"  "$OUTPUT_DIR/system-info.txt" | cut -d'=' -f2)
    backup_date=$(grep   "BACKUP_DATE" "$OUTPUT_DIR/system-info.txt" | cut -d'=' -f2)
    echo "📅 Backup created: $backup_date"
    echo "🖥️  Backup system: $backup_system"

    if [ "$backup_system" != "$SYSTEM_TYPE" ]; then
        echo "⚠️  Warning: System type mismatch!"
        echo "   Backup: $backup_system | Current: $SYSTEM_TYPE"
        echo ""
    fi
fi

show_restore_preflight "$OUTPUT_DIR"

step_scripts=()
[[ "$INCLUDE_PACMAN" == true ]] && step_scripts+=("$STEPS_DIR/01_packages.sh")
[[ "$INCLUDE_AUR" == true ]] && step_scripts+=("$STEPS_DIR/02_aur.sh")
[[ "$INCLUDE_SNAP" == true ]] && step_scripts+=("$STEPS_DIR/02_snap.sh")
[[ "$INCLUDE_FLATPAK" == true ]] && step_scripts+=("$STEPS_DIR/02_flatpak.sh")
[[ "$INCLUDE_DESKTOP_CONFIGS" == true ]] && step_scripts+=("$STEPS_DIR/03_desktop_configs.sh")
[[ "$INCLUDE_COPY_HOOK" == true || "$INCLUDE_SUDO_COPY_HOOK" == true ]] && step_scripts+=("$STEPS_DIR/04_copy_hooks.sh")

step_count=${#step_scripts[@]}
step_index=1

if [ "$SYNC_DIFF" = true ]; then
    echo "🔄 Running sync steps..."
else
    echo "🔄 Running restore steps..."
fi

for script in "${step_scripts[@]}"; do
    script_name=$(basename "$script")
    draw_progress_bar $((step_index - 1)) "$step_count"
    printf "  %s..." "$script_name"

    if OPERATION="restore" OUTPUT_DIR="$OUTPUT_DIR" \
       SYSTEM_TYPE="$SYSTEM_TYPE" PACKAGE_MANAGER="$PACKAGE_MANAGER" \
       DESKTOP_ENV="$DESKTOP_ENV" INCLUDE_PACMAN="$INCLUDE_PACMAN" \
       INCLUDE_AUR="$INCLUDE_AUR" INCLUDE_FLATPAK="$INCLUDE_FLATPAK" \
       INCLUDE_SNAP="$INCLUDE_SNAP" INCLUDE_DESKTOP_CONFIGS="$INCLUDE_DESKTOP_CONFIGS" \
       INCLUDE_COPY_HOOK="$INCLUDE_COPY_HOOK" INCLUDE_SUDO_COPY_HOOK="$INCLUDE_SUDO_COPY_HOOK" \
       CLEAN_INSTALL="$CLEAN_INSTALL" NAGA_EXCLUDES="$NAGA_EXCLUDES" \
       SYNC_DIFF="$SYNC_DIFF" \
       bash "$script"; then
        printf " ✔️\n"
    else
        printf " ❌\n"
    fi
    ((step_index++))
done

draw_progress_bar "$step_count" "$step_count"
echo ""

if [ -n "$POSTINSTALL_DIR" ]; then
    run_postinstall_scripts "$POSTINSTALL_DIR"
fi

if [ "$SYNC_DIFF" = true ]; then
    echo "✅ Sync complete"
else
    echo "✅ Restore complete"
fi
