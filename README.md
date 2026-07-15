# WiFi Band Switcher for Windows

A PowerShell script that allows you to force your Windows device to connect to a specific WiFi band (2.4GHz, 5GHz, or 6GHz).

## Problem
Windows sometimes connects to the 2.4GHz band even when 5GHz is available, resulting in slower speeds. This tool helps you manually select which band to use.

## Features
- Scan and list all available WiFi networks
- Display which bands (2.4GHz, 5GHz, 6GHz) each network supports
- Force connection to a specific band
- Interactive menu for easy selection
- Command-line arguments for automation

## Requirements
- Windows 10 or Windows 11
- PowerShell 5.1 or later (included with Windows)
- **Administrator privileges** (required for WiFi management)
- WiFi adapter with working drivers

## Installation

1. **Download the files:**
   - `WifiBandSwitcher.ps1` - Main PowerShell script
   - `Run-WifiBandSwitcher.bat` - Batch file launcher (optional)

2. **Place them in a folder:**
   - Create a new folder (e.g., `C:\WiFiBandSwitcher`)
   - Copy both files to this folder

## Usage

### Method 1: Using the Batch File (Easiest)
1. Right-click on `Run-WifiBandSwitcher.bat`
2. Select "Run as administrator"
3. Follow the on-screen menu

### Method 2: Using PowerShell Directly
1. Open PowerShell as Administrator
2. Navigate to the script location:
   ```powershell
   cd C:\WiFiBandSwitcher
   ```
3. Run the script:
   ```powershell
   .\WifiBandSwitcher.ps1
   ```

### Method 3: Command-Line Arguments
You can use the script with command-line arguments for automation:

- **Scan only (list networks):**
  ```powershell
  .\WifiBandSwitcher.ps1 -ScanOnly
  ```

- **Connect to specific SSID and band:**
  ```powershell
  .\WifiBandSwitcher.ps1 -SSID "YourWiFiName" -Band "5GHz"
  ```

- **Connect to specific SSID (interactive band selection):**
  ```powershell
  .\WifiBandSwitcher.ps1 -SSID "YourWiFiName"
  ```

## How It Works

1. The script uses `netsh wlan show networks mode=bssid` to scan for available networks
2. It parses the output to identify which access points (BSSIDs) are on which bands
3. Channel numbers determine the band:
   - Channels 1-14 = 2.4GHz
   - Channels 36-165 = 5GHz
   - Channels 1-233 = 6GHz (WiFi 6E)
4. When you select a band, the script disconnects from the current network and reconnects, attempting to use the BSSID on your selected band

## Limitations

- **Same SSID for both bands:** If your router uses the same SSID for both 2.4GHz and 5GHz, Windows may still connect to the wrong band after reconnection. This is a Windows limitation.
  
  **Solution:** Configure your router to use different SSID names for different bands (e.g., "MyWiFi-2G" and "MyWiFi-5G").

- **Band steering:** Some enterprise networks use band steering technologies that may override your selection.

- **Driver limitations:** Some WiFi adapter drivers may not fully support band selection.

## Troubleshooting

### "This script requires Administrator privileges"
- Right-click PowerShell or the batch file and select "Run as administrator"

### "No WiFi networks found"
- Make sure your WiFi adapter is enabled
- Check that you're in range of WiFi networks
- Try running the script again

### "5GHz band not available"
- Your router may not support 5GHz
- Your WiFi adapter may not support 5GHz
- You may be too far from the 5GHz access point

### Script doesn't connect to the right band
- Your router might be using the same SSID for both bands
- Try using different SSID names for each band on your router

## Security
This script only uses built-in Windows commands (`netsh`) and does not:
- Send any data over the internet
- Modify system files outside of WiFi profiles
- Install any additional software
- Require internet access to function

## License
This script is provided as-is for personal use. Feel free to modify and redistribute.

## Version History
- **1.0** - Initial release
  - WiFi network scanning with band detection
  - Interactive menu system
  - Band-specific connection
  - Command-line argument support
