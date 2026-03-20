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
# restore only items that differ from the current system
./naga.sh sync backup.tar.gz
# compare backup with the current system's state
./naga.sh diff backup.tar.gz
# compare two backups
./naga.sh diff old.tar.gz new.tar.gz
```

## Options

```
--no-pacman          Skip package list
--no-aur             Skip AUR packages
--no-flatpak         Skip Flatpak
--no-snap            Skip Snap
--no-desktop         Skip desktop configs
--no-copy-hooks      Skip user files
--sudo-copy          Include system files (requires sudo)
--clean-install      Remove packages not in backup during restore
--diff-files         Include file content diffs
--exclude <src:path> Exclude items matching <path> from <src> (also -e)
--postinstall <dir>  Run scripts from <dir> after restore / sync
-y, --yes            Skip pre-flight confirmation prompt
```

## Exclusions

Use `--exclude` (or `-e`) to skip specific items during backup or restore.
The format is `source:pattern`, where wildcards are supported.

```bash
# skip a specific AUR package
./naga.sh backup -e aur:electron

# skip all AUR source packages
./naga.sh backup -e "aur:*-src"

# skip a copy-list entry by its alias
./naga.sh backup -e copy:thunderbird

# multiple exclusions
./naga.sh backup -e "aur:*-src" -e copy:thunderbird -e flatpak:org.mozilla.firefox
```

Valid sources: `pacman`, `aur`, `flatpak`, `snap`, `copy`, `sudo_copy`

## Sync Mode

`sync` is like `restore` but only processes items that have changed or are missing
on the current system:

```bash
./naga.sh sync backup.tar.gz
```

## Post-install Scripts

Pass `--postinstall <dir>` to run a set of shell scripts after a restore or sync:

```bash
./naga.sh restore backup.tar.gz --postinstall ./post-scripts
```

Scripts in the directory are executed in the order specified by an optional
`.order` file. Scripts not listed in `.order` are appended after the ordered ones in the default order.

Example `.order`:
```
# run these first
10_repos.sh
20_dotfiles.sh
# 30_optional.sh
```

## Copy Lists

All copy lists use the same format:
- `original_path|archive_tag` - copies file from `original_path` to `archive_tag` name in the archive. During restore process it copies `archive_tag` back to `original_path`
- `?path|archive` - same, but asks for confirmation from the user
- `#path|archive` - commented and ignored

Types of copy lists:

- `copy_list.conf` — User files
- `sudo_copy_list.conf` — System files (requires sudo, enable with `--sudo-copy`)
