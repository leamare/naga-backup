#!/bin/bash

_format_bytes() {
    local bytes="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec "$bytes" 2>/dev/null || echo "${bytes}B"
    else
        if   [ "$bytes" -ge $((1024*1024*1024)) ]; then printf "%.1fG\n" "$(echo "scale=1; $bytes/1073741824" | bc)"
        elif [ "$bytes" -ge $((1024*1024)) ];       then printf "%.1fM\n" "$(echo "scale=1; $bytes/1048576"    | bc)"
        elif [ "$bytes" -ge 1024 ];                 then printf "%.1fK\n" "$(echo "scale=1; $bytes/1024"       | bc)"
        else echo "${bytes}B"
        fi
    fi
}

_count_lines() {
    local f="$1"
    [ -f "$f" ] || { echo 0; return; }
    grep -c '[^[:space:]]' "$f" 2>/dev/null || echo 0
}

show_backup_preflight() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Backup Plan"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "$INCLUDE_PACMAN" = true ]; then
        local count=0
        case "$SYSTEM_TYPE" in
            arch)   count=$(pacman -Qqen 2>/dev/null | wc -l) ;;
            debian) count=$(apt list --installed 2>/dev/null | grep -vc "^Listing") ;;
            redhat) count=$(dnf list installed 2>/dev/null | grep -vc "^Installed") ;;
        esac
        echo "  pacman / native:  $count packages"
    fi

    if [ "$INCLUDE_AUR" = true ] && [ "$SYSTEM_TYPE" = "arch" ]; then
        local count=0
        command -v yay >/dev/null 2>&1 && count=$(yay -Qqm 2>/dev/null | wc -l)
        echo "  aur:              $count packages"
    fi

    if [ "$INCLUDE_FLATPAK" = true ] && command -v flatpak >/dev/null 2>&1; then
        local count
        count=$(flatpak list --app --columns=application 2>/dev/null | wc -l)
        echo "  flatpak:          $count apps"
    fi

    if [ "$INCLUDE_SNAP" = true ] && command -v snap >/dev/null 2>&1; then
        local count
        count=$(snap list 2>/dev/null | awk 'NR>1' | wc -l)
        echo "  snap:             $count packages"
    fi

    _preflight_copy_section "copy_list.conf" "copy (user files)"
    if [ "$INCLUDE_SUDO_COPY_HOOK" = true ]; then
        _preflight_copy_section "sudo_copy_list.conf" "sudo_copy (system files)"
    fi

    if [ -n "$NAGA_EXCLUDES" ]; then
        echo ""
        echo "  Excluded:"
        local pattern pat_source pat_name
        local IFS='|'
        for pattern in $NAGA_EXCLUDES; do
            [ -z "$pattern" ] && continue
            pat_source="${pattern%%:*}"
            pat_name="${pattern#*:}"
            echo "    ${pat_source}: ${pat_name}"
        done
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    _preflight_confirm
}

show_restore_preflight() {
    local archive_dir="$1"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "$SYNC_DIFF" = true ]; then
        echo "  Sync Plan  (diff mode — only changed items)"
    else
        echo "  Restore Plan"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    [ -f "$archive_dir/pkglist.txt" ]       && echo "  pacman:   $(_count_lines "$archive_dir/pkglist.txt") packages"
    [ -f "$archive_dir/pkglist-aur.txt" ]   && echo "  aur:      $(_count_lines "$archive_dir/pkglist-aur.txt") packages"
    [ -f "$archive_dir/flatpak-apps.txt" ]  && echo "  flatpak:  $(_count_lines "$archive_dir/flatpak-apps.txt") apps"
    [ -f "$archive_dir/snap-packages.txt" ] && echo "  snap:     $(_count_lines "$archive_dir/snap-packages.txt") packages"

    if [ -d "$archive_dir/copy" ]; then
        local total_bytes
        total_bytes=$(du -sb "$archive_dir/copy" 2>/dev/null | awk '{print $1}')
        local file_count
        file_count=$(find "$archive_dir/copy" -type f ! -name "copy_list.conf" ! -name "sudo_copy_list.conf" 2>/dev/null | wc -l)
        echo "  copy:     $file_count files  ($(_format_bytes "${total_bytes:-0}"))"
    fi

    if [ -d "$archive_dir/sudo_copy" ]; then
        local total_bytes
        total_bytes=$(du -sb "$archive_dir/sudo_copy" 2>/dev/null | awk '{print $1}')
        local file_count
        file_count=$(find "$archive_dir/sudo_copy" -type f ! -name "copy_list.conf" ! -name "sudo_copy_list.conf" 2>/dev/null | wc -l)
        echo "  sudo_copy: $file_count files  ($(_format_bytes "${total_bytes:-0}"))"
    fi

    if [ -n "$POSTINSTALL_DIR" ] && [ -d "$POSTINSTALL_DIR" ]; then
        echo ""
        echo "  Post-install scripts:"
        list_postinstall_scripts "$POSTINSTALL_DIR"
    fi

    # Excludes
    if [ -n "$NAGA_EXCLUDES" ]; then
        echo ""
        echo "  Excluded:"
        local pattern pat_source pat_name
        local IFS='|'
        for pattern in $NAGA_EXCLUDES; do
            [ -z "$pattern" ] && continue
            pat_source="${pattern%%:*}"
            pat_name="${pattern#*:}"
            echo "    ${pat_source}: ${pat_name}"
        done
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    _preflight_confirm
}

_preflight_copy_section() {
    local conf="$1"
    local label="$2"

    [ ! -f "$conf" ] && return

    local count=0 total_bytes=0 skipped_excl=0
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        local src="${line%%|*}"
        local alias="${line##*|}"
        [[ "$src" == \?* ]] && src="${src:1}"
        local expanded
        expanded=$(eval echo "$src" 2>/dev/null) || expanded="$src"

        local excluded=false
        if [ -n "$NAGA_EXCLUDES" ]; then
            local pattern pat_source pat_name
            local old_IFS="$IFS"; IFS='|'
            for pattern in $NAGA_EXCLUDES; do
                [ -z "$pattern" ] && continue
                pat_source="${pattern%%:*}"
                pat_name="${pattern#*:}"
                local src_label="${label%%[[:space:]]*}"
                if [ "$pat_source" = "$src_label" ] && [[ "$alias" == $pat_name ]]; then
                    excluded=true; break
                fi
            done
            IFS="$old_IFS"
        fi

        if $excluded; then
            skipped_excl=$((skipped_excl + 1))
            continue
        fi

        if [ -e "$expanded" ]; then
            local sz
            sz=$(du -sb "$expanded" 2>/dev/null | awk '{print $1}')
            total_bytes=$((total_bytes + ${sz:-0}))
            count=$((count + 1))
        fi
    done < "$conf"

    local excl_note=""
    [ "$skipped_excl" -gt 0 ] && excl_note=" ($skipped_excl excluded)"
    echo "  ${label}:  $count files/dirs  ($(_format_bytes "$total_bytes"))${excl_note}"
}

_preflight_confirm() {
    if [ "${NAGA_YES:-false}" = "true" ]; then
        return
    fi
    read -rp "  Press Enter to continue, or Ctrl+C to abort... " </dev/tty
    echo ""
}
