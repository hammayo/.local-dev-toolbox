# fc-rsync.sh

A one-shot rsync script for backing up a local Git repository to another drive, respecting `.gitignore` rules.

## Overview

`fc-rsync.sh` mirrors a source repository to a backup destination using `rsync`. It honours the repository's `.gitignore` so that build artefacts, logs, and dependency folders are excluded automatically. The `--delete` flag keeps the backup in sync by removing files from the destination that no longer exist in the source.

## Usage

```bash
chmod +x scripts/bash/fc-rsync.sh

# Use the built-in defaults
./scripts/bash/fc-rsync.sh

# Override source and/or destination as positional arguments
./scripts/bash/fc-rsync.sh /mnt/d/Repos/MyProject /mnt/c/Backups/Repos/MyProject

# Override via environment variables
FC_RSYNC_SOURCE=/mnt/d/Repos/MyProject FC_RSYNC_DEST=/mnt/c/Backups/Repos/MyProject ./scripts/bash/fc-rsync.sh
```

## Configuration

Paths are resolved in this priority order: **positional arg → environment variable → default in script**.

| Source | Variable | Default |
|--------|----------|---------|
| Arg `$1` / env `FC_RSYNC_SOURCE` | `SOURCE` | `/mnt/d/Repos/Hydra.OPT.Service` |
| Arg `$2` / env `FC_RSYNC_DEST`   | `DEST`   | `/mnt/c/Backups/Repos/Hydra.OPT.Service` |

To change the permanent defaults, edit `DEFAULT_SOURCE` and `DEFAULT_DEST` at the top of the script.

## What It Does

1. Runs `rsync -av --delete --progress` from source to destination.
2. Uses `--filter=':- .gitignore'` to read and apply `.gitignore` rules from the source repo.
3. Explicitly excludes `node_modules/`, `*.log`, `*.tmp`, and `*.cache` as an extra safety net.
4. Prints progress during the transfer and a confirmation message on completion.

## Notes

- The `--delete` flag means files removed from source will also be removed from the backup. This keeps the backup a true mirror but means it is **not** a versioned backup -- if you delete something from source, it's gone from the backup too after the next run.
- For timestamped snapshots (keeping multiple backup versions), uncomment the alternative `DEST` line that appends a date suffix.
