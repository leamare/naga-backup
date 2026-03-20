#!/bin/bash

is_excluded() {
    local source="$1"
    local name="$2"

    [ -z "$NAGA_EXCLUDES" ] && return 1

    local pattern pat_source pat_name
    local IFS='|'
    for pattern in $NAGA_EXCLUDES; do
        [ -z "$pattern" ] && continue
        pat_source="${pattern%%:*}"
        pat_name="${pattern#*:}"
        if [ "$pat_source" = "$source" ] && [[ "$name" == $pat_name ]]; then
            return 0
        fi
    done
    return 1
}

list_excludes_for() {
    local source="$1"
    [ -z "$NAGA_EXCLUDES" ] && return

    local pattern pat_source pat_name
    local IFS='|'
    for pattern in $NAGA_EXCLUDES; do
        [ -z "$pattern" ] && continue
        pat_source="${pattern%%:*}"
        pat_name="${pattern#*:}"
        [ "$pat_source" = "$source" ] && echo "    exclude: $pat_name"
    done
}
