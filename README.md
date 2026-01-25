# Naga

Backup and restore Linux system configuration between installations.

Exports the complete list of installed packages (also detects linux distro used and package managers installed), along with listed config files, and restores it on another (compatible) installation.

I made these scripts primarily for my personal use. It was tested primarily with Arch, exporting pacman + aur + flatpak + snap packages, along with the plasma configuration, themes and my personal dotfiles (so the copylists examples are tailored for me).

Any additional improvements are welcome.

The process itself is based on the steps specified in `steps` folder.

## Usage

```bash
# create backup
./naga.sh backup
# restore from backup
./naga.sh restore backup.tar.gz
# compare backup with the current system's state
./naga.sh diff backup.tar.gz
```

## Options

```
--no-pacman         Skip package list
--no-aur            Skip AUR packages
--no-flatpak        Skip Flatpak
--no-snap           Skip Snap
--no-desktop        Skip desktop configs
--no-copy-hooks     Skip user files
--sudo-copy         Include system files (requires sudo)
--clean-install     Remove packages not in backup during restore
--diff-files        Include file content diffs
```

## Options

## Copy Lists

All copy lists use the same format:
- `original_path|archive_tag` - copies file from `original_path` to `archive_tag` name in the archive. During restore process it copies `archive_tag` back to `original_path`
- `?path|archive` - same, but asks for confirmation from the user
- `#path|archive` - commented and ignored

Types of copy lists:

- `copy_list.conf` — User files
- `sudo_copy_list.conf` — System files (requires sudo, enable with `--sudo-copy`)

