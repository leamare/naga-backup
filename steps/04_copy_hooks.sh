#!/bin/bash

process_copy_list() {
    local config_file="$1"
    local dest_dir="$2"
    local use_sudo="$3"
    local operation="$4"
    
    if [ ! -f "$config_file" ]; then
        return 0
    fi
    
    # Pre-authenticate sudo if needed
    if [ "$use_sudo" = true ]; then
        echo "  🔐 Requesting sudo access..."
        sudo -v </dev/tty || { echo "  ❌ Sudo authentication failed"; return 1; }
    fi
    
    local count=0
    local skipped=0
    
    # Read config into array first to free stdin for prompts
    local entries=()
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        entries+=("$line")
    done < "$config_file"
    
    for entry in "${entries[@]}"; do
        local source_path="${entry%%|*}"
        local alias="${entry##*|}"
        
        local is_optional=false
        if [[ "$source_path" == \?* ]]; then
            is_optional=true
            source_path="${source_path:1}"
        fi
        
        local expanded_path=$(eval echo "$source_path")
        
        if [ "$operation" = "backup" ]; then
            # Check if file exists (use sudo for system files)
            local exists=false
            if [ "$use_sudo" = true ]; then
                sudo test -e "$expanded_path" </dev/tty 2>/dev/null && exists=true
            else
                [ -e "$expanded_path" ] && exists=true
            fi
            
            if [ "$exists" = true ]; then
                if [ "$is_optional" = true ]; then
                    read -p "  Include $expanded_path? [y/N] " -n 1 -r </dev/tty
                    echo
                    [[ ! $REPLY =~ ^[Yy]$ ]] && { ((skipped++)); continue; }
                fi
                
                echo "  📁 $expanded_path -> $alias"
                if [ "$use_sudo" = true ]; then
                    if ! sudo cp -a "$expanded_path" "$dest_dir/$alias" </dev/tty; then
                        echo "  ⚠️  Failed to copy $expanded_path"
                        ((skipped++))
                        continue
                    fi
                    sudo chown -R "$(id -u):$(id -g)" "$dest_dir/$alias" </dev/tty
                else
                    cp -a "$expanded_path" "$dest_dir/$alias" 2>/dev/null || { ((skipped++)); continue; }
                fi
                ((count++))
            else
                ((skipped++))
            fi
        elif [ "$operation" = "restore" ]; then
            local backup_path="$dest_dir/$alias"
            if [ -e "$backup_path" ]; then
                if [ "$is_optional" = true ]; then
                    read -p "  Restore $alias -> $expanded_path? [y/N] " -n 1 -r </dev/tty
                    echo
                    [[ ! $REPLY =~ ^[Yy]$ ]] && { ((skipped++)); continue; }
                fi
                
                echo "  📁 $alias -> $expanded_path"
                if [ "$use_sudo" = true ]; then
                    sudo mkdir -p "$(dirname "$expanded_path")" </dev/tty
                    sudo rm -rf "$expanded_path" </dev/tty
                    sudo cp -a "$backup_path" "$expanded_path" </dev/tty
                else
                    mkdir -p "$(dirname "$expanded_path")"
                    rm -rf "$expanded_path"
                    cp -a "$backup_path" "$expanded_path"
                fi
                ((count++))
            fi
        fi
    done
    
    echo "  ✅ Processed $count items, skipped $skipped"
}

backup_copy_hooks() {
    echo "[*] Backing up user files..."
    
    local copy_dir="$OUTPUT_DIR/copy"
    mkdir -p "$copy_dir"
    
    if [ -f "copy_list.conf" ]; then
        cp "copy_list.conf" "$copy_dir/"
        process_copy_list "copy_list.conf" "$copy_dir" false backup
    fi
}

backup_sudo_copy_hooks() {
    echo "[*] Backing up system files (sudo required)..."
    
    local sudo_dir="$OUTPUT_DIR/sudo_copy"
    mkdir -p "$sudo_dir"
    
    if [ -f "sudo_copy_list.conf" ]; then
        cp "sudo_copy_list.conf" "$sudo_dir/"
        process_copy_list "sudo_copy_list.conf" "$sudo_dir" true backup
    else
        echo "  ⚠️  sudo_copy_list.conf not found"
    fi
}

restore_copy_hooks() {
    echo "[*] Restoring user files..."
    
    local copy_dir="$OUTPUT_DIR/copy"
    
    if [ -d "$copy_dir" ] && [ -f "$copy_dir/copy_list.conf" ]; then
        process_copy_list "$copy_dir/copy_list.conf" "$copy_dir" false restore
    else
        echo "  ⏭️  No user files backup found"
    fi
}

restore_sudo_copy_hooks() {
    echo "[*] Restoring system files (sudo required)..."
    
    local sudo_dir="$OUTPUT_DIR/sudo_copy"
    
    if [ -d "$sudo_dir" ] && [ -f "$sudo_dir/sudo_copy_list.conf" ]; then
        process_copy_list "$sudo_dir/sudo_copy_list.conf" "$sudo_dir" true restore
    else
        echo "  ⏭️  No system files backup found"
    fi
}

if [ "$OPERATION" = "backup" ]; then
    if [ "$INCLUDE_COPY_HOOK" = true ]; then
        backup_copy_hooks
    fi
    if [ "$INCLUDE_SUDO_COPY_HOOK" = true ]; then
        backup_sudo_copy_hooks
    fi
elif [ "$OPERATION" = "restore" ]; then
    if [ "$INCLUDE_COPY_HOOK" = true ]; then
        restore_copy_hooks
    fi
    if [ "$INCLUDE_SUDO_COPY_HOOK" = true ]; then
        restore_sudo_copy_hooks
    fi
fi
