@echo off
:: WiFi Band Switcher - Simple Batch Launcher
:: Right-click and "Run as Administrator" for best results

@echo off
setlocal

:: Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%WifiBandSwitcher.ps1"

:: Check if the PowerShell script exists
if not exist "%PS_SCRIPT%" (
    echo Error: WiFiBandSwitcher.ps1 not found in %SCRIPT_DIR%
    echo.
    echo Please ensure WifiBandSwitcher.ps1 is in the same folder as this batch file.
    pause
    exit /b 1
)

:: Launch PowerShell with the script
echo Launching WiFi Band Switcher...
echo.
echo NOTE: This script requires Administrator privileges.
echo If you see permission errors, please right-click this file and select "Run as Administrator".
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

endlocal
