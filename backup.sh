#!/bin/bash
set -e

source ./lib/ui.sh
source ./lib/cli.sh

parse_args "$@"
validate_system
check_dependencies

STEPS_DIR="./steps"
OUTPUT_DIR="./output"
mkdir -p "$OUTPUT_DIR"

HOSTNAME=$(hostname)
DATE=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="backup_config_${HOSTNAME}_${DATE}.tar.gz"
FINAL_ARCHIVE="$OUTPUT_DIR/$ARCHIVE_NAME"

TEMP_BACKUP_DIR=$(mktemp -d -p "$OUTPUT_DIR" .backup.XXXXXX)

echo "SYSTEM_TYPE=$SYSTEM_TYPE" > "$TEMP_BACKUP_DIR/system-info.txt"
echo "DESKTOP_ENV=$DESKTOP_ENV" >> "$TEMP_BACKUP_DIR/system-info.txt"
echo "PACKAGE_MANAGER=$PACKAGE_MANAGER" >> "$TEMP_BACKUP_DIR/system-info.txt"
echo "HOSTNAME=$HOSTNAME" >> "$TEMP_BACKUP_DIR/system-info.txt"
echo "BACKUP_DATE=$(date -Iseconds)" >> "$TEMP_BACKUP_DIR/system-info.txt"

step_scripts=()
[[ "$INCLUDE_PACMAN" == true ]] && step_scripts+=("$STEPS_DIR/01_packages.sh")
[[ "$INCLUDE_AUR" == true ]] && step_scripts+=("$STEPS_DIR/02_aur.sh")
[[ "$INCLUDE_SNAP" == true ]] && step_scripts+=("$STEPS_DIR/02_snap.sh")
[[ "$INCLUDE_FLATPAK" == true ]] && step_scripts+=("$STEPS_DIR/02_flatpak.sh")
[[ "$INCLUDE_DESKTOP_CONFIGS" == true ]] && step_scripts+=("$STEPS_DIR/03_desktop_configs.sh")
[[ "$INCLUDE_COPY_HOOK" == true || "$INCLUDE_SUDO_COPY_HOOK" == true ]] && step_scripts+=("$STEPS_DIR/04_copy_hooks.sh")

step_count=${#step_scripts[@]}
step_index=1

echo "📦 Starting backup..."
echo "🔍 System: $SYSTEM_TYPE ($PACKAGE_MANAGER)"
echo "🖥️  Desktop: $DESKTOP_ENV"
echo ""

for script in "${step_scripts[@]}"; do
    script_name=$(basename "$script")
    draw_progress_bar $((step_index - 1)) "$step_count"
    printf "  %s..." "$script_name"

    if OPERATION="backup" OUTPUT_DIR="$TEMP_BACKUP_DIR" \
       SYSTEM_TYPE="$SYSTEM_TYPE" PACKAGE_MANAGER="$PACKAGE_MANAGER" \
       DESKTOP_ENV="$DESKTOP_ENV" INCLUDE_PACMAN="$INCLUDE_PACMAN" \
       INCLUDE_AUR="$INCLUDE_AUR" INCLUDE_FLATPAK="$INCLUDE_FLATPAK" \
       INCLUDE_SNAP="$INCLUDE_SNAP" INCLUDE_DESKTOP_CONFIGS="$INCLUDE_DESKTOP_CONFIGS" \
       INCLUDE_COPY_HOOK="$INCLUDE_COPY_HOOK" INCLUDE_SUDO_COPY_HOOK="$INCLUDE_SUDO_COPY_HOOK" \
       CLEAN_INSTALL="$CLEAN_INSTALL" bash "$script"; then
        printf " ✔️\n"
    else
        printf " ❌\n"
    fi
    ((step_index++))
done

draw_progress_bar "$step_count" "$step_count"
echo -e "  Compressing archive..."

tar -czf "$FINAL_ARCHIVE" -C "$TEMP_BACKUP_DIR" .
rm -rf "$TEMP_BACKUP_DIR"

echo "✅ Backup complete: $FINAL_ARCHIVE"
