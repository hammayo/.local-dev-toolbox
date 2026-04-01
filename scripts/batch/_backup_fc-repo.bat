@echo off
rem _backup_fc-repo.bat — Copy a repo to a backup folder using xcopy.
rem
rem Usage:
rem   _backup_fc-repo.bat [REPONAME] [SOURCE_ROOT] [DEST_ROOT] [EXCLUDEFILE]
rem
rem   REPONAME      Repository folder name          (default: Hydra.OPT.Service)
rem   SOURCE_ROOT   Root directory for repositories (default: D:\Repos)
rem   DEST_ROOT     Root directory for backups      (default: C:\Backups\Repos)
rem   EXCLUDEFILE   Path to xcopy exclude list      (default: C:\Backups\.exclude.txt)
rem
rem Environment variable overrides (used when argument is not supplied):
rem   BACKUP_SOURCE_ROOT   same as SOURCE_ROOT argument
rem   BACKUP_DEST_ROOT     same as DEST_ROOT argument
rem   BACKUP_EXCLUDEFILE   same as EXCLUDEFILE argument
rem
rem Examples:
rem   _backup_fc-repo.bat
rem   _backup_fc-repo.bat .local-dev-toolbox
rem   _backup_fc-repo.bat Hydra.OPT.Service D:\Repos C:\Backups\Repos C:\Backups\.exclude.txt

rem SET LOGFILE=C:\Backups\_backup_fc-repo_%DATE:~-4,4%%DATE:~-7,2%%DATE:~-10,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.log

:: ℹ️ Config 📄
set REPONAME=%~1
if "%~1"=="" set REPONAME=Hydra.OPT.Service

:: SOURCE_ROOT: arg 2 → env var → default
set SOURCE_ROOT=%~2
if "%SOURCE_ROOT%"=="" set SOURCE_ROOT=%BACKUP_SOURCE_ROOT%
if "%SOURCE_ROOT%"=="" set SOURCE_ROOT=D:\Repos

:: DEST_ROOT: arg 3 → env var → default
set DEST_ROOT=%~3
if "%DEST_ROOT%"=="" set DEST_ROOT=%BACKUP_DEST_ROOT%
if "%DEST_ROOT%"=="" set DEST_ROOT=C:\Backups\Repos

:: EXCLUDEFILE: arg 4 → env var → default (same folder as this script)
set EXCLUDEFILE=%~4
if "%EXCLUDEFILE%"=="" set EXCLUDEFILE=%BACKUP_EXCLUDEFILE%
if "%EXCLUDEFILE%"=="" set EXCLUDEFILE=%~dp0.exclude.txt

set SOURCE=%SOURCE_ROOT%\%REPONAME%
set DEST=%DEST_ROOT%\%REPONAME%

:: 🗑️ Wipe destination
echo Clearing destination...
rd /s /q "%DEST%" 2>nul
mkdir "%DEST%"

:: 📁/📦 Copy files  
echo Copying files...
xcopy "%SOURCE%" "%DEST%" /e /h /c /i /y /EXCLUDE:%EXCLUDEFILE%

:: ✅ Done
echo.
if %ERRORLEVEL% NEQ 0 (
	echo Backup failed. Check your source, destination and exclude file paths. → LOGFILE
) else (
	echo Backup complete!
)

pause
