<#PSScriptInfo
.VERSION 1.0
.GUID 5f8d0a4b-7e2c-4f1d-9c3a-8b1e6f2d3c4a
.AUTHOR Wifi Band Switcher
 DESCRIPTION Forces Windows WiFi to connect to a specific band (2.4GHz or 5GHz)
#>

<#
.SYNOPSIS
    WiFi Band Switcher for Windows
.DESCRIPTION
    This script allows you to scan available WiFi networks, identify their frequency bands,
    and force your computer to connect to a specific band (2.4GHz or 5GHz).
    
    Useful when your device keeps connecting to 2.4GHz when 5GHz is available.

.NOTES
    File Name      : WifiBandSwitcher.ps1
    Prerequisite   : PowerShell 5.1 or later (Windows 10/11)
    Run as Administrator: Required for WiFi configuration changes
#>

param (
    [switch]$ScanOnly,
    [string]$SSID,
    [string]$Band
)

# Require admin privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ("This script requires Administrator privileges to manage WiFi connections.") -ForegroundColor Red
    Write-Host ("Please run PowerShell as Administrator and try again.") -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

# Check if WiFi is available
try {
    $wlanInterfaces = (netsh wlan show interfaces) -split "`r`n"
    $hasWifi = $false
    foreach ($line in $wlanInterfaces) {
        if ($line -match "State\s+:\s+connected" -or $line -match "State\s+:\s+disconnected") {
            $hasWifi = $true
            break
        }
    }
    if (-not $hasWifi) {
        Write-Host ("No WiFi adapter found on this system.") -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host ("Error checking WiFi adapter: $_") -ForegroundColor Red
    exit 1
}

# Function to determine band from channel
function Get-BandFromChannel {
    param([int]$Channel)
    
    # 2.4 GHz: channels 1-14
    if ($Channel -ge 1 -and $Channel -le 14) {
        return "2.4GHz"
    }
    # 5 GHz: channels 36-165
    elseif ($Channel -ge 36 -and $Channel -le 165) {
        return "5GHz"
    }
    # 6 GHz: channels 1-233 (WiFi 6E)
    elseif ($Channel -ge 1 -and $Channel -le 233) {
        return "6GHz"
    }
    else {
        return "Unknown"
    }
}

# Function to get available WiFi networks with band information
function Get-AvailableWifiNetworks {
    Write-Host "`nScanning for available WiFi networks..." -ForegroundColor Cyan
    
    $networks = @()
    
    try {
        $output = netsh wlan show networks mode=bssid 2>&1
        
        $currentNetwork = $null
        $currentBSSID = $null
        $currentSSID = $null
        
        foreach ($line in $output -split "`r`n") {
            $line = $line.Trim()
            
            if ($line -match "^\s*SSID \d+\s+:\s+(.+)") {
                $currentSSID = $matches[1]
                $currentNetwork = [PSCustomObject]@{
                    SSID = $currentSSID
                    BSSIDs = @()
                    SignalStrength = 0
                    BestBSSID = $null
                }
                $networks += $currentNetwork
            }
            elseif ($line -match "^\s*BSSID \d+\s+:\s+([0-9a-fA-F-]+)") {
                $currentBSSID = $matches[1]
                $bssidObj = [PSCustomObject]@{
                    BSSID = $currentBSSID
                    Channel = $null
                    Frequency = $null
                    Band = $null
                    Signal = 0
                }
                if ($currentNetwork) {
                    $currentNetwork.BSSIDs += $bssidObj
                }
            }
            elseif ($line -match "^\s*Signal\s+:\s+(\d+)%") {
                $signal = [int]$matches[1]
                if ($currentNetwork -and $currentNetwork.BSSIDs.Count -gt 0) {
                    $currentNetwork.BSSIDs[$currentNetwork.BSSIDs.Count - 1].Signal = $signal
                    if ($signal -gt $currentNetwork.SignalStrength) {
                        $currentNetwork.SignalStrength = $signal
                        $currentNetwork.BestBSSID = $currentNetwork.BSSIDs[$currentNetwork.BSSIDs.Count - 1].BSSID
                    }
                }
            }
            elseif ($line -match "^\s*Channel\s+:\s+(\d+)") {
                $channel = [int]$matches[1]
                if ($currentNetwork -and $currentNetwork.BSSIDs.Count -gt 0) {
                    $currentNetwork.BSSIDs[$currentNetwork.BSSIDs.Count - 1].Channel = $channel
                    $currentNetwork.BSSIDs[$currentNetwork.BSSIDs.Count - 1].Band = Get-BandFromChannel -Channel $channel
                }
            }
            elseif ($line -match "^\s*Primary channels\s+:\s+([\d,]+)") {
                $channels = $matches[1] -split ","
                if ($channels.Count -gt 0 -and $currentBSSID -and $currentNetwork) {
                    $channel = [int]$channels[0]
                    foreach ($bssid in $currentNetwork.BSSIDs) {
                        if ($bssid.BSSID -eq $currentBSSID -and $bssid.Channel -eq $null) {
                            $bssid.Channel = $channel
                            $bssid.Band = Get-BandFromChannel -Channel $channel
                            break
                        }
                    }
                }
            }
        }
        
        # Deduplicate and clean up
        $uniqueNetworks = @{}
        foreach ($net in $networks) {
            if ($net.SSID -ne "") {
                if (-not $uniqueNetworks.ContainsKey($net.SSID)) {
                    $uniqueNetworks[$net.SSID] = $net
                } else {
                    foreach ($bssid in $net.BSSIDs) {
                        $exists = $false
                        foreach ($existingBssid in $uniqueNetworks[$net.SSID].BSSIDs) {
                            if ($existingBssid.BSSID -eq $bssid.BSSID) {
                                $exists = $true
                                break
                            }
                        }
                        if (-not $exists) {
                            $uniqueNetworks[$net.SSID].BSSIDs += $bssid
                        }
                    }
                }
            }
        }
        
        # Build final list with band information
        $result = @()
        foreach ($key in $uniqueNetworks.Keys) {
            $net = $uniqueNetworks[$key]
            $bands = @{}
            $bandSignals = @{}
            
            foreach ($bssid in $net.BSSIDs) {
                if ($bssid.Band -and $bssid.Band -ne "Unknown") {
                    if (-not $bands.ContainsKey($bssid.Band)) {
                        $bands[$bssid.Band] = @()
                        $bandSignals[$bssid.Band] = 0
                    }
                    $bands[$bssid.Band] += $bssid
                    if ($bssid.Signal -gt $bandSignals[$bssid.Band]) {
                        $bandSignals[$bssid.Band] = $bssid.Signal
                    }
                }
            }
            
            $netObj = [PSCustomObject]@{
                SSID = $net.SSID
                AvailableBands = [System.Collections.Generic.List[string]]::new()
                BandDetails = [System.Collections.Generic.Dictionary[string,object]]::new()
                BestSignal = $net.SignalStrength
            }
            
            foreach ($band in $bands.Keys) {
                $netObj.AvailableBands.Add($band)
                $bssidsForBand = $bands[$band] | Sort-Object Signal -Descending
                $netObj.BandDetails[$band] = @{
                    BSSIDs = $bssidsForBand | ForEach-Object { $_.BSSID }
                    BestBSSID = $bssidsForBand[0].BSSID
                    Signal = $bandSignals[$band]
                }
            }
            
            $result += $netObj
        }
        
        return $result | Sort-Object SSID
        
    } catch {
        Write-Host ("Error scanning networks: $_") -ForegroundColor Red
        return @()
    }
}

# Function to connect to a specific WiFi network on a specific band
function Connect-ToWifiBand {
    param(
        [string]$SSID,
        [string]$Band,
        [string]$BSSID = $null
    )
    
    Write-Host ("`nAttempting to connect to '$SSID' on $Band band...") -ForegroundColor Yellow
    
    $currentInterface = netsh wlan show interfaces 2>&1
    $connectedSSID = $null
    foreach ($line in $currentInterface -split "`r`n") {
        if ($line -match "^\s*SSID\s+:\s+(.+)") {
            $connectedSSID = $matches[1].Trim()
            break
        }
    }
    
    if ($connectedSSID -eq $SSID) {
        Write-Host ("Already connected to $SSID. Disconnecting first...") -ForegroundColor Cyan
        netsh wlan disconnect 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    }
    
    $networks = Get-AvailableWifiNetworks
    $targetNetwork = $networks | Where-Object { $_.SSID -eq $SSID -and $_.AvailableBands -contains $Band }
    
    if (-not $targetNetwork) {
        Write-Host ("Network '$SSID' with $Band band not found or not available.") -ForegroundColor Red
        return $false
    }
    
    $bssid = $BSSID
    if ([string]::IsNullOrEmpty($bssid)) {
        $bssid = $targetNetwork.BandDetails[$Band].BestBSSID
    }
    
    if ([string]::IsNullOrEmpty($bssid)) {
        Write-Host ("No BSSID found for $SSID on $Band band.") -ForegroundColor Red
        return $false
    }
    
    Write-Host ("Connecting to BSSID: $bssid") -ForegroundColor Cyan
    
    try {
        Write-Host ("Connecting to $SSID...") -ForegroundColor Cyan
        
        $result = netsh wlan connect name="$SSID" 2>&1
        
        Start-Sleep -Seconds 3
        
        $newInterface = netsh wlan show interfaces 2>&1
        $newSSID = $null
        foreach ($line in $newInterface -split "`r`n") {
            if ($line -match "^\s*SSID\s+:\s+(.+)") {
                $newSSID = $matches[1].Trim()
                break
            }
        }
        
        if ($newSSID -eq $SSID) {
            Write-Host ("Successfully connected to $SSID on $Band band!") -ForegroundColor Green
            return $true
        } else {
            Write-Host ("Failed to connect to $SSID.") -ForegroundColor Red
            return $false
        }
        
    } catch {
        Write-Host ("Error connecting: $_") -ForegroundColor Red
        return $false
    }
}

# Function to display available networks in a table
function Show-NetworkList {
    param([array]$Networks)
    
    Write-Host "`n" + ("=" * 80)
    Write-Host "Available WiFi Networks" -ForegroundColor Cyan
    Write-Host ("=" * 80)
    Write-Host ("{0,-30} {1,10} {2,15}" -f "SSID", "Signal", "Available Bands")
    Write-Host ("-" * 80)
    
    $index = 1
    foreach ($net in $Networks) {
        $bandsStr = ($net.AvailableBands -join ", ")
        if ($bandsStr -eq "") {
            $bandsStr = "Unknown"
        }
        Write-Host ("{0,2}. {1,-28} {2,3}%   {3}" -f $index, $net.SSID, $net.BestSignal, $bandsStr)
        $index++
    }
    Write-Host ("=" * 80)
}

# Function to display interactive menu
function Show-MainMenu {
    $networks = Get-AvailableWifiNetworks
    
    if ($networks.Count -eq 0) {
        Write-Host ("No WiFi networks found.") -ForegroundColor Red
        return
    }
    
    Show-NetworkList -Networks $networks
    
    Write-Host "`nSelect an option:" -ForegroundColor Cyan
    Write-Host "  [1-$($networks.Count)] Select a network to connect to"
    Write-Host "  [R] Refresh network list"
    Write-Host "  [Q] Quit"
    Write-Host "`nEnter your choice:" -ForegroundColor Yellow -NoNewline
    
    $choice = Read-Host
    
    if ($choice -match "^[qQ]$") {
        exit 0
    }
    elseif ($choice -match "^[rR]$") {
        Show-MainMenu
        return
    }
    elseif ($choice -match "^\d+$") {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $networks.Count) {
            Show-NetworkOptions -Network $networks[$index]
        } else {
            Write-Host ("Invalid selection.") -ForegroundColor Red
            Start-Sleep -Seconds 1
            Show-MainMenu
        }
    } else {
        Write-Host ("Invalid input.") -ForegroundColor Red
        Start-Sleep -Seconds 1
        Show-MainMenu
    }
}

# Function to show options for a specific network
function Show-NetworkOptions {
    param([object]$Network)
    
    Clear-Host
    Write-Host "`n" + ("=" * 80)
    Write-Host ("Network: $($Network.SSID)") -ForegroundColor Cyan
    Write-Host ("=" * 80)
    Write-Host ("Available bands: $($Network.AvailableBands -join ', ')")
    Write-Host ("Signal strength: $($Network.BestSignal)%")
    Write-Host ("-" * 80)
    
    if ($Network.AvailableBands.Count -eq 0) {
        Write-Host ("No band information available for this network.") -ForegroundColor Yellow
        Write-Host "`nPress any key to return to main menu..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Show-MainMenu
        return
    }
    
    Write-Host "`nSelect a band to connect to:" -ForegroundColor Cyan
    
    $index = 1
    $bandMap = @{}
    foreach ($band in $Network.AvailableBands | Sort-Object) {
        Write-Host "  [$index] $band"
        $bandMap[$index] = $band
        $index++
    }
    
    Write-Host "  [B] Back to main menu"
    Write-Host "`nEnter your choice:" -ForegroundColor Yellow -NoNewline
    
    $choice = Read-Host
    
    if ($choice -match "^[bB]$") {
        Show-MainMenu
        return
    }
    elseif ($choice -match "^\d+$") {
        $bandIndex = [int]$choice
        if ($bandMap.ContainsKey($bandIndex)) {
            $selectedBand = $bandMap[$bandIndex]
            Write-Host "`nConnecting to $($Network.SSID) on $selectedBand..." -ForegroundColor Yellow
            
            $success = Connect-ToWifiBand -SSID $Network.SSID -Band $selectedBand
            
            if ($success) {
                Write-Host "`nConnection successful!" -ForegroundColor Green
            } else {
                Write-Host "`nConnection failed or band could not be verified." -ForegroundColor Red
            }
            
            Write-Host "`nPress any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-MainMenu
        } else {
            Write-Host ("Invalid selection.") -ForegroundColor Red
            Start-Sleep -Seconds 1
            Show-NetworkOptions -Network $Network
        }
    } else {
        Write-Host ("Invalid input.") -ForegroundColor Red
        Start-Sleep -Seconds 1
        Show-NetworkOptions -Network $Network
    }
}

# Main execution
Write-Host "WiFi Band Switcher for Windows" -ForegroundColor Cyan
Write-Host "Version 1.0" -ForegroundColor Cyan
Write-Host ""

# Handle command-line arguments
if ($ScanOnly) {
    $networks = Get-AvailableWifiNetworks
    Show-NetworkList -Networks $networks
    exit 0
}

if ($SSID -and $Band) {
    $success = Connect-ToWifiBand -SSID $SSID -Band $Band
    if ($success) {
        Write-Host ("Successfully connected to $SSID on $Band band.") -ForegroundColor Green
        exit 0
    } else {
        Write-Host ("Failed to connect to $SSID on $Band band.") -ForegroundColor Red
        exit 1
    }
}

if ($SSID) {
    $networks = Get-AvailableWifiNetworks
    $targetNetwork = $networks | Where-Object { $_.SSID -eq $SSID }
    if ($targetNetwork) {
        Show-NetworkOptions -Network $targetNetwork
    } else {
        Write-Host ("Network '$SSID' not found.") -ForegroundColor Red
        exit 1
    }
    exit 0
}

# Interactive mode
Show-MainMenu
