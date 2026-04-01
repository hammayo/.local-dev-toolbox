# fix-timestamps.ps1

A utility script that sets the creation, modification, and access timestamps of files in a folder to a specific date and time.

## Overview

`fix-timestamps.ps1` bulk-updates file timestamps in a target directory. It filters files by extension so that only the file types you care about are touched. This is useful when build outputs or deployment artefacts need consistent timestamps — for example, when comparing builds or preparing a release folder where the file dates should reflect the build time rather than when they were copied.

## Configuration

Values are resolved in this priority order: **CLI parameter → environment variable → default in script**.

| Setting | `-Parameter` | Env var | Default |
|---------|-------------|---------|---------|
| Folder path | `-FolderPath` | `FIX_TS_FOLDER` | `C:\Backups\_Builds\_Forecourt_Service\Local\` |
| File extensions | `-Extensions` | `FIX_TS_EXTS` | `.pdb,.xml,.config,.dll,.exe` |
| Target timestamp | `-Timestamp` | `FIX_TS_TIMESTAMP` | `2026-03-30 07:46:50` |

To change permanent defaults, edit `$Script:DefaultFolderPath`, `$Script:DefaultTimestamp`, and `$Script:DefaultExtensions` at the top of the script.

## Usage

```powershell
# Use the built-in defaults
.\fix-timestamps.ps1

# Override folder and timestamp via parameters
.\fix-timestamps.ps1 -FolderPath "D:\Builds\MyApp" -Timestamp "2025-01-01 00:00:00"

# Override extensions (comma-separated)
.\fix-timestamps.ps1 -Extensions ".dll,.exe"

# Override via environment variables
$env:FIX_TS_FOLDER = "D:\Builds\MyApp"
$env:FIX_TS_TIMESTAMP = "2025-06-15 08:00:00"
.\fix-timestamps.ps1
```

## What It Does

1. Scans `$folderPath` for files (non-recursive, immediate children only).
2. Filters to files whose extension matches one of the entries in `$extensions`.
3. Sets three timestamp properties on each matching file:
   - `CreationTime` — when the file was created
   - `LastWriteTime` — when the file was last modified
   - `LastAccessTime` — when the file was last accessed
4. Prints the name of each updated file.

## Notes

- The script does **not** recurse into subdirectories. To process nested folders, change `Get-ChildItem -Path $folderPath -File` to include `-Recurse`.
- Requires write access to the target files. Run as administrator if the folder is in a protected location.
