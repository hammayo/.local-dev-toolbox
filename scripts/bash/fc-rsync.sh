#!/bin/bash
# fc-rsync.sh — Rsync a repo from a WSL-mounted Windows drive to a backup location.
#
# Usage:
#   ./fc-rsync.sh [SOURCE] [DEST]
#   SOURCE  WSL path to the repository (default: /mnt/d/Repos/Hydra.OPT.Service)
#   DEST    WSL path to the backup destination (default: /mnt/c/Backups/Repos/Hydra.OPT.Service)
#
# Environment overrides (lowest priority):
#   FC_RSYNC_SOURCE   same as SOURCE argument
#   FC_RSYNC_DEST     same as DEST argument
#
# Examples:
#   ./fc-rsync.sh
#   ./fc-rsync.sh /mnt/d/Repos/MyProject /mnt/c/Backups/Repos/MyProject
#   FC_RSYNC_SOURCE=/mnt/d/Repos/MyProject ./fc-rsync.sh

# -------------------------------------------------------------------------
# Defaults — WSL paths; adjust drive letters to match your Windows setup.
# Windows D:\Repos\... maps to /mnt/d/Repos/... in WSL.
DEFAULT_SOURCE="/mnt/d/Repos/Hydra.OPT.Service"
DEFAULT_DEST="/mnt/c/Backups/Repos/Hydra.OPT.Service"
# Timestamped backup variant (uncomment DEST line below and comment out the default):
# DEFAULT_DEST="/mnt/c/Backups/Repos/Hydra.OPT.Service_$(date +%Y%m%d_%H%M%S)"
# -------------------------------------------------------------------------

SOURCE="${1:-${FC_RSYNC_SOURCE:-$DEFAULT_SOURCE}}"
DEST="${2:-${FC_RSYNC_DEST:-$DEFAULT_DEST}}"

echo "📦 Copying files..."
rsync -av --delete --progress \
  --filter=':- .gitignore' \
  --exclude='node_modules/' \
  --exclude='*.log' \
  --exclude='*.tmp' \
  --exclude='*.cache' \
  "$SOURCE/" "$DEST/"

echo "✅ Sync complete → $DEST"

# Windows xcopy equivalent (run from CMD, not WSL):
# xcopy "D:\Repos\Hydra.OPT.Service" "C:\Backups\Repos\Hydra.OPT.Service" /E /H /C /I /Y /EXCLUDE:C:\Backups\.exclude.txt