@echo off
:: WiFi Band Switcher - Batch Launcher
:: This file launches the WiFi Band Switcher PowerShell script
:: It will auto-elevate to Administrator if needed

@echo off
setlocal

:: Check if we are running as administrator
NET FILE > NUL 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    :: Create a temporary VBScript to request elevation
    set "VBS_SCRIPT=%TEMP%\GetAdmin.vbs"
    echo Set UAC = CreateObject("Shell.Application") > "%VBS_SCRIPT%"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%VBS_SCRIPT%"
    "%VBS_SCRIPT%"
    del "%VBS_SCRIPT%" > NUL 2>&1
    exit /b
)

:: Check if PowerShell is available
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo PowerShell not found!
    pause
    exit /b 1
)

:: Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%WifiBandSwitcher.ps1"

:: Check if the PowerShell script exists
if not exist "%PS_SCRIPT%" (
    echo WiFi Band Switcher script not found!
    echo Expected location: %PS_SCRIPT%
    pause
    exit /b 1
)

:: Launch PowerShell with the script
:: -NoProfile: Don't load user profile for faster startup
:: -ExecutionPolicy Bypass: Skip execution policy checks
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

endlocal
