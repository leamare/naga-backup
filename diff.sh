#!/bin/bash
set -e

source ./lib/ui.sh
source ./lib/cli.sh

parse_args "$@"
validate_system
check_dependencies

mkdir -p ./output
TMP1=$(mktemp -d -p ./output .diff1.XXXXXX)
TMP2=$(mktemp -d -p ./output .diff2.XXXXXX)

create_temp_backup() {
    local temp_dir="$1"
    echo "[*] Creating snapshot of current system..."

    local temp_output="$temp_dir/output"
    mkdir -p "$temp_output"

    echo "SYSTEM_TYPE=$SYSTEM_TYPE"          > "$temp_output/system-info.txt"
    echo "DESKTOP_ENV=$DESKTOP_ENV"         >> "$temp_output/system-info.txt"
    echo "PACKAGE_MANAGER=$PACKAGE_MANAGER" >> "$temp_output/system-info.txt"
    echo "HOSTNAME=$(hostname)"             >> "$temp_output/system-info.txt"
    echo "BACKUP_DATE=$(date -Iseconds)"    >> "$temp_output/system-info.txt"

    case "$SYSTEM_TYPE" in
        "arch")
            [ "$INCLUDE_PACMAN" = true ] && pacman -Qqen > "$temp_output/pkglist.txt" 2>/dev/null || true
            [ "$INCLUDE_AUR" = true ] && command -v yay >/dev/null 2>&1 && yay -Qqm > "$temp_output/pkglist-aur.txt" 2>/dev/null || true
            ;;
        "debian")
            [ "$INCLUDE_PACMAN" = true ] && apt list --installed 2>/dev/null | grep -v "^Listing" | cut -d'/' -f1 > "$temp_output/pkglist.txt" || true
            ;;
        "redhat")
            [ "$INCLUDE_PACMAN" = true ] && dnf list installed 2>/dev/null | grep -v "^Installed" | awk '{print $1}' | cut -d'.' -f1 > "$temp_output/pkglist.txt" || true
            ;;
    esac

    [ "$INCLUDE_FLATPAK" = true ] && command -v flatpak >/dev/null 2>&1 && flatpak list --app --columns=application > "$temp_output/flatpak-apps.txt" 2>/dev/null || true
    [ "$INCLUDE_SNAP" = true ] && command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | awk 'NR>1 {print $1}' > "$temp_output/snap-packages.txt" || true
}

compare_lists() {
    local file1="$1"
    local file2="$2"
    local label="$3"

    if [ -f "$file1" ] && [ -f "$file2" ]; then
        echo "📦 $label:"
        if diff <(sort "$file1") <(sort "$file2") >/dev/null 2>&1; then
            echo "   ✅ Identical"
        else
            diff <(sort "$file1") <(sort "$file2") || true
        fi
        echo ""
    elif [ -f "$file1" ]; then
        echo "📦 $label: Only in backup 1 ($(wc -l < "$file1") items)"
    elif [ -f "$file2" ]; then
        echo "📦 $label: Only in backup 2 ($(wc -l < "$file2") items)"
    fi
}

compare_files() {
    local archive_copy_dir="$1"
    local other_dir="$2"
    local compare_live="${3:-false}"

    [ ! -d "$archive_copy_dir" ] && return

    local conf="$archive_copy_dir/copy_list.conf"
    if [ ! -f "$conf" ]; then
        echo "📁 Copied files: no copy_list.conf found in archive"
        return
    fi

    echo "📁 Copied files:"

    local any_diff=false

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        local src_path="${line%%|*}"
        local alias="${line##*|}"
        [[ "$src_path" == \?* ]] && src_path="${src_path:1}"

        local item1="$archive_copy_dir/$alias"

        local item2
        if [ "$compare_live" = true ]; then
            item2=$(eval echo "$src_path" 2>/dev/null) || item2="$src_path"
        else
            item2="$other_dir/$alias"
        fi

        if [ ! -e "$item1" ]; then
            continue
        fi

        if [ ! -e "$item2" ]; then
            if [ "$compare_live" = true ]; then
                echo "   ➖ $alias  →  absent on current system  ($src_path)"
            else
                echo "   ➖ $alias  →  absent from archive 2"
            fi
            any_diff=true
            continue
        fi

        if diff -r "$item1" "$item2" >/dev/null 2>&1; then
            :
        else
            if [ -d "$item1" ]; then
                local changed_count
                changed_count=$(diff -rq "$item1" "$item2" 2>/dev/null | wc -l)
                echo "   📁 $alias/  ($changed_count item(s) changed)"
            else
                echo "   📝 $alias  (modified)"
            fi

            if [ "$DIFF_FILES" = true ]; then
                diff -r -u "$item1" "$item2" 2>/dev/null | sed 's/^/      /' || true
            fi

            any_diff=true
        fi
    done < "$conf"

    if [ "$compare_live" = false ] && [ -f "$other_dir/copy_list.conf" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            local alias2="${line##*|}"
            [ ! -e "$archive_copy_dir/$alias2" ] && [ -e "$other_dir/$alias2" ] && {
                echo "   ➕ $alias2  →  only in archive 2"
                any_diff=true
            }
        done < "$other_dir/copy_list.conf"
    fi

    if [ "$any_diff" = false ]; then
        echo "   ✅ All copied files identical"
    fi
    echo ""
}

if [ -n "$ARCHIVE2" ]; then
    echo "🔍 Comparing two backups..."
    echo "📦 Archive 1: $ARCHIVE1"
    echo "📦 Archive 2: $ARCHIVE2"
    echo ""

    tar -xzf "$ARCHIVE1" -C "$TMP1"
    tar -xzf "$ARCHIVE2" -C "$TMP2"

    echo "🖥️  System Info:"
    [ -f "$TMP1/system-info.txt" ] && { echo "Backup 1:"; cat "$TMP1/system-info.txt"; echo ""; }
    [ -f "$TMP2/system-info.txt" ] && { echo "Backup 2:"; cat "$TMP2/system-info.txt"; echo ""; }

    compare_lists "$TMP1/pkglist.txt"       "$TMP2/pkglist.txt"       "Packages"
    compare_lists "$TMP1/pkglist-aur.txt"   "$TMP2/pkglist-aur.txt"   "AUR packages"
    compare_lists "$TMP1/flatpak-apps.txt"  "$TMP2/flatpak-apps.txt"  "Flatpak"
    compare_lists "$TMP1/snap-packages.txt" "$TMP2/snap-packages.txt" "Snap"

    compare_files "$TMP1/copy" "$TMP2/copy" false
    compare_files "$TMP1/sudo_copy" "$TMP2/sudo_copy" false
else
    echo "🔍 Comparing backup with current system..."
    echo "📦 Archive: $ARCHIVE1"
    echo ""

    tar -xzf "$ARCHIVE1" -C "$TMP1"
    create_temp_backup "$TMP2"

    echo "🖥️  System Info:"
    [ -f "$TMP1/system-info.txt" ] && { echo "Backup:"; cat "$TMP1/system-info.txt"; echo ""; }
    echo "Current:"; cat "$TMP2/output/system-info.txt"; echo ""

    compare_lists "$TMP1/pkglist.txt"       "$TMP2/output/pkglist.txt"       "Packages"
    compare_lists "$TMP1/pkglist-aur.txt"   "$TMP2/output/pkglist-aur.txt"   "AUR packages"
    compare_lists "$TMP1/flatpak-apps.txt"  "$TMP2/output/flatpak-apps.txt"  "Flatpak"
    compare_lists "$TMP1/snap-packages.txt" "$TMP2/output/snap-packages.txt" "Snap"

    compare_files "$TMP1/copy"      "" true
    compare_files "$TMP1/sudo_copy" "" true
fi

rm -rf "$TMP1" "$TMP2"
echo "✅ Comparison complete"
