# fix-timestamps.ps1
#
# Usage:
#   pwsh fix-timestamps.ps1 [[-FolderPath] <path>] [[-Timestamp] <datetime>] [[-Extensions] <ext,...>]
#
# Parameters:
#   -FolderPath   Directory containing files to update (default: C:\Backups\_Builds\_Forecourt_Service\Local\)
#   -Timestamp    Target datetime string, e.g. "2026-03-30 07:46:50" (default: value below)
#   -Extensions   Comma-separated list of extensions to match (default: .pdb,.xml,.config,.dll,.exe)
#
# Environment overrides (used when parameter is not supplied):
#   FIX_TS_FOLDER     same as -FolderPath
#   FIX_TS_TIMESTAMP  same as -Timestamp
#   FIX_TS_EXTS       comma-separated extensions, same as -Extensions
#
# Examples:
#   pwsh fix-timestamps.ps1
#   pwsh fix-timestamps.ps1 -FolderPath "D:\Builds\MyApp" -Timestamp "2025-01-01 00:00:00"
#   $env:FIX_TS_FOLDER = "D:\Builds\MyApp"; pwsh fix-timestamps.ps1

param (
    [Parameter(Mandatory = $false)]
    [string]$FolderPath,

    [Parameter(Mandatory = $false)]
    [string]$Timestamp,

    [Parameter(Mandatory = $false)]
    [string]$Extensions
)

Set-StrictMode -Version Latest 2>$null

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# -------------------------------------------------------------------------
# Defaults — edit these to match your environment
$Script:DefaultFolderPath = 'C:\Backups\_Builds\_Forecourt_Service\Local\'
$Script:DefaultTimestamp  = '2026-03-30 07:46:50'
$Script:DefaultExtensions = @('.pdb', '.xml', '.config', '.dll', '.exe')
# -------------------------------------------------------------------------

# Resolve: CLI param > env var > default
$resolvedFolder = if ($FolderPath)  { $FolderPath }
                  elseif ($env:FIX_TS_FOLDER) { $env:FIX_TS_FOLDER }
                  else { $Script:DefaultFolderPath }

$resolvedTimestamp = if ($Timestamp)  { $Timestamp }
                     elseif ($env:FIX_TS_TIMESTAMP) { $env:FIX_TS_TIMESTAMP }
                     else { $Script:DefaultTimestamp }

$resolvedExtensions = if ($Extensions) { $Extensions -split ',' | ForEach-Object { $_.Trim() } }
                      elseif ($env:FIX_TS_EXTS) { $env:FIX_TS_EXTS -split ',' | ForEach-Object { $_.Trim() } }
                      else { $Script:DefaultExtensions }

$Script:Config = @{
    FolderPath  = $resolvedFolder
    Extensions  = $resolvedExtensions
    Timestamp   = Get-Date $resolvedTimestamp
}
# -------------------------------------------------------------------------

function Set-FileTimestamps ([string]$folderPath, [string[]]$extensions, [datetime]$timestamp)
{
    Get-ChildItem -Path $folderPath -File |
    Where-Object { $extensions -contains $_.Extension.ToLower() } |
    ForEach-Object {
        $_.CreationTime   = $timestamp
        $_.LastWriteTime  = $timestamp
        $_.LastAccessTime = $timestamp
        Write-Host "Updated: $($_.Name)"
    }
}

function Main ([string]$folderPath, [string[]]$extensions, [datetime]$timestamp)
{
    if (-not (Test-Path -Path $folderPath -PathType Container))
    {
        Write-Error "FolderPath '$folderPath' does not exist or is not a directory."
        $global:LASTEXITCODE = 1
        return
    }

    Set-FileTimestamps -folderPath $folderPath -extensions $extensions -timestamp $timestamp
    Write-Host 'Done.'
}

Main -folderPath $Script:Config.FolderPath `
     -extensions ([string[]]$Script:Config.Extensions) `
     -timestamp $Script:Config.Timestamp
