#!/bin/bash

INCLUDE_PACMAN=true
INCLUDE_AUR=true
INCLUDE_FLATPAK=true
INCLUDE_SNAP=true
INCLUDE_DESKTOP_CONFIGS=true
INCLUDE_COPY_HOOK=true
INCLUDE_SUDO_COPY_HOOK=false
CLEAN_INSTALL=false
DIFF_FILES=false
OPERATION=""
ARCHIVE_PATH=""

detect_system() {
    if [ -f /etc/arch-release ]; then
        SYSTEM_TYPE="arch"
        PACKAGE_MANAGER="pacman"
        AUR_HELPER="yay"
    elif [ -f /etc/debian_version ]; then
        SYSTEM_TYPE="debian"
        PACKAGE_MANAGER="apt"
        AUR_HELPER=""
    elif [ -f /etc/redhat-release ]; then
        SYSTEM_TYPE="redhat"
        PACKAGE_MANAGER="dnf"
        AUR_HELPER=""
    else
        SYSTEM_TYPE="unknown"
        PACKAGE_MANAGER=""
        AUR_HELPER=""
    fi
}

detect_desktop() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        case "$XDG_CURRENT_DESKTOP" in
            *KDE*|*Plasma*) DESKTOP_ENV="kde" ;;
            *GNOME*) DESKTOP_ENV="gnome" ;;
            *XFCE*) DESKTOP_ENV="xfce" ;;
            *) DESKTOP_ENV="unknown" ;;
        esac
    else
        DESKTOP_ENV="unknown"
    fi
}

show_help() {
    cat << EOF
Naga - Linux System Backup & Restore

USAGE: $0 [OPTIONS] <operation> [archive_path]

OPERATIONS:
    backup                      Create a system backup
    restore <archive>           Restore from backup archive
    diff <archive1> [archive2]  Compare backups (or backup vs current system)

OPTIONS:
    --no-pacman         Skip package list backup
    --no-aur            Skip AUR packages (Arch only)
    --no-flatpak        Skip Flatpak apps
    --no-snap           Skip Snap packages
    --no-desktop        Skip desktop configs
    --no-copy-hooks     Skip user files
    --sudo-copy         Include system files (requires sudo)
    --clean-install     Remove packages not in backup during restore
    --diff-files        Include file content diffs (slow)
    -h, --help          Show help

EXAMPLES:
    $0 backup
    $0 backup --sudo-copy
    $0 restore backup.tar.gz
    $0 diff old.tar.gz new.tar.gz
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-pacman) INCLUDE_PACMAN=false; shift ;;
            --no-aur) INCLUDE_AUR=false; shift ;;
            --no-flatpak) INCLUDE_FLATPAK=false; shift ;;
            --no-snap) INCLUDE_SNAP=false; shift ;;
            --no-desktop) INCLUDE_DESKTOP_CONFIGS=false; shift ;;
            --no-copy-hooks) INCLUDE_COPY_HOOK=false; shift ;;
            --sudo-copy) INCLUDE_SUDO_COPY_HOOK=true; shift ;;
            --clean-install) CLEAN_INSTALL=true; shift ;;
            --diff-files) DIFF_FILES=true; shift ;;
            --help|-h) show_help; exit 0 ;;
            backup) OPERATION="backup"; shift ;;
            restore)
                OPERATION="restore"
                if [ -n "$2" ]; then
                    ARCHIVE_PATH="$2"
                    shift 2
                else
                    echo "❌ Error: restore requires archive path"
                    exit 1
                fi
                ;;
            diff)
                OPERATION="diff"
                if [ -n "$2" ]; then
                    ARCHIVE1="$2"
                    if [ -n "$3" ]; then
                        ARCHIVE2="$3"
                        shift 3
                    else
                        ARCHIVE2=""
                        shift 2
                    fi
                else
                    echo "❌ Error: diff requires at least one archive path"
                    exit 1
                fi
                ;;
            *)
                echo "❌ Error: Unknown option '$1'"
                echo "Use --help for usage"
                exit 1
                ;;
        esac
    done

    if [ -z "$OPERATION" ]; then
        echo "❌ Error: No operation specified"
        echo "Use --help for usage"
        exit 1
    fi
}

validate_system() {
    detect_system
    detect_desktop
    
    if [ "$SYSTEM_TYPE" = "unknown" ]; then
        echo "⚠️  Warning: Unknown system type"
    fi
    
    if [ "$OPERATION" = "restore" ] && [ -n "$ARCHIVE_PATH" ]; then
        if [ ! -f "$ARCHIVE_PATH" ]; then
            echo "❌ Error: Archive not found: $ARCHIVE_PATH"
            exit 1
        fi
    fi
}

check_dependencies() {
    local missing=()
    
    command -v tar >/dev/null 2>&1 || missing+=("tar")
    command -v gzip >/dev/null 2>&1 || missing+=("gzip")
    
    if [ "$SYSTEM_TYPE" = "arch" ]; then
        command -v pacman >/dev/null 2>&1 || missing+=("pacman")
        if [ "$INCLUDE_AUR" = true ]; then
            command -v yay >/dev/null 2>&1 || echo "⚠️  yay not found, skipping AUR"
        fi
    elif [ "$SYSTEM_TYPE" = "debian" ]; then
        command -v apt >/dev/null 2>&1 || missing+=("apt")
    fi
    
    if [ "$INCLUDE_FLATPAK" = true ]; then
        command -v flatpak >/dev/null 2>&1 || echo "⚠️  flatpak not found, skipping"
    fi
    
    if [ "$INCLUDE_SNAP" = true ]; then
        command -v snap >/dev/null 2>&1 || echo "⚠️  snap not found, skipping"
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Error: Missing tools: ${missing[*]}"
        exit 1
    fi
}
