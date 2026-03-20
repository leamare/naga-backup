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
    sync    [options] <archive>         Restore only changed/absent items
    diff    [options] <archive1> [archive2]
                                        Compare backups

OPTIONS:
    --no-pacman         Skip package list
    --no-aur            Skip AUR packages
    --no-flatpak        Skip Flatpak
    --no-snap           Skip Snap
    --no-desktop        Skip desktop configs
    --no-copy-hooks     Skip user files
    --sudo-copy         Include system files (requires sudo)
    --clean-install     Remove packages not in backup
    --diff-files        Include file content diffs
    --postinstall <dir> Run scripts from <dir> after restore/sync
    --exclude <src:pat> Exclude matching items (also -e)
    -y, --yes           Skip confirmation prompt
    -h, --help          Show help

EXAMPLES:
    $0 backup
    $0 backup --sudo-copy -e "aur:*-src"
    $0 restore backup.tar.gz
    $0 restore backup.tar.gz --postinstall ./my-scripts
    $0 sync    backup.tar.gz
    $0 diff    old.tar.gz new.tar.gz
EOF
}

OPERATION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        backup|restore|sync|diff)
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
    backup)  exec "$SCRIPT_DIR/backup.sh"  backup  "$@" ;;
    restore) exec "$SCRIPT_DIR/restore.sh" restore "$@" ;;
    sync)    exec "$SCRIPT_DIR/restore.sh" sync    "$@" ;;
    diff)    exec "$SCRIPT_DIR/diff.sh"    diff    "$@" ;;
esac
