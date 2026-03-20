#!/bin/bash

run_postinstall_scripts() {
    local scripts_dir="$1"

    if [ ! -d "$scripts_dir" ]; then
        echo "  ❌ Post-install directory not found: $scripts_dir"
        return 1
    fi

    local all_scripts=()
    while IFS= read -r f; do
        all_scripts+=("$(basename "$f")")
    done < <(find "$scripts_dir" -maxdepth 1 -type f \( -name "*.sh" -o -perm /111 \) ! -name ".order" | sort)

    if [ ${#all_scripts[@]} -eq 0 ]; then
        echo "  ⚠️  No scripts found in $scripts_dir"
        return 0
    fi

    local ordered_scripts=()
    local seen=()

    if [ -f "$scripts_dir/.order" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            local name="${line// /}"
            if [ -f "$scripts_dir/$name" ]; then
                ordered_scripts+=("$name")
                seen+=("$name")
            else
                echo "  ⚠️  .order references missing script: $name"
            fi
        done < "$scripts_dir/.order"
    fi

    # Append unlisted scripts in alphabetical order
    for s in "${all_scripts[@]}"; do
        local already=false
        for x in "${seen[@]}"; do
            [ "$x" = "$s" ] && { already=true; break; }
        done
        $already || ordered_scripts+=("$s")
    done

    echo "[*] Running post-install scripts..."
    local count=0 failed=0
    for script_name in "${ordered_scripts[@]}"; do
        local script_path="$scripts_dir/$script_name"
        printf "  ▶  %s..." "$script_name"
        if bash "$script_path"; then
            printf " ✔️\n"
            count=$((count + 1))
        else
            printf " ❌\n"
            failed=$((failed + 1))
        fi
    done
    echo "  ✅ Post-install: $count script(s) succeeded, $failed failed"
}

list_postinstall_scripts() {
    local scripts_dir="$1"
    [ ! -d "$scripts_dir" ] && return

    local all_scripts=()
    while IFS= read -r f; do
        all_scripts+=("$(basename "$f")")
    done < <(find "$scripts_dir" -maxdepth 1 -type f \( -name "*.sh" -o -perm /111 \) ! -name ".order" | sort)

    [ ${#all_scripts[@]} -eq 0 ] && return

    local ordered_scripts=()
    local seen=()

    if [ -f "$scripts_dir/.order" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            local name="${line// /}"
            if [ -f "$scripts_dir/$name" ]; then
                ordered_scripts+=("$name")
                seen+=("$name")
            fi
        done < "$scripts_dir/.order"
    fi

    for s in "${all_scripts[@]}"; do
        local already=false
        for x in "${seen[@]}"; do
            [ "$x" = "$s" ] && { already=true; break; }
        done
        $already || ordered_scripts+=("$s")
    done

    for s in "${ordered_scripts[@]}"; do
        echo "    $s"
    done
}
