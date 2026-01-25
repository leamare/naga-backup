#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_usage() {
    cat << EOF
Naga - Linux System Backup & Restore

USAGE: $0 <operation> [options] [arguments]

OPERATIONS:
    backup [options]                    Create a system backup
    restore [options] <archive>         Restore from backup
    diff [options] <archive1> [archive2] Compare backups

OPTIONS:
    --no-pacman         Skip package list
    --no-aur            Skip AUR packages
    --no-flatpak        Skip Flatpak apps
    --no-snap           Skip Snap packages
    --no-desktop        Skip desktop configs
    --no-copy-hooks     Skip user files
    --sudo-copy         Include system files (requires sudo)
    --clean-install     Remove packages not in backup
    --diff-files        Include file content diffs
    -h, --help          Show help

EXAMPLES:
    $0 backup
    $0 backup --sudo-copy
    $0 restore backup.tar.gz
    $0 diff old.tar.gz new.tar.gz
EOF
}

OPERATION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        backup|restore|diff)
            OPERATION="$1"
            shift
            break
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Error: Unknown operation '$1'"
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

case "$OPERATION" in
    backup)  exec "$SCRIPT_DIR/backup.sh" backup "$@" ;;
    restore) exec "$SCRIPT_DIR/restore.sh" restore "$@" ;;
    diff)    exec "$SCRIPT_DIR/diff.sh" diff "$@" ;;
esac
