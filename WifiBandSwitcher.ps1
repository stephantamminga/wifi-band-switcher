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

.NOTES
    File Name      : WifiBandSwitcher.ps1
    Prerequisite   : PowerShell 5.1 or later (Windows 10/11)
    Run as Administrator: Required for WiFi configuration changes
#>

param (
    [switch]$ScanOnly,
    [string]$SSID,
    [string]$Band,
    [switch]$Verbose,
    [switch]$Debug
)

# Require admin privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ("This script requires Administrator privileges to manage WiFi connections.") -ForegroundColor Red
    Write-Host ("Please run PowerShell as Administrator and try again.") -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

# Function to determine band from channel
function Get-BandFromChannel {
    param([int]$Channel)
    if ($Channel -ge 1 -and $Channel -le 14) { return "2.4GHz" }
    elseif ($Channel -ge 36 -and $Channel -le 165) { return "5GHz" }
    elseif ($Channel -ge 1 -and $Channel -le 233) { return "6GHz" }
    else { return "Unknown" }
}

# Function to parse netsh output and get all BSSIDs with bands
function Get-AvailableWifiNetworks {
    Write-Host ("`nScanning for available WiFi networks...") -ForegroundColor Cyan
    
    $networks = @{}
    $output = netsh wlan show networks mode=bssid 2>&1
    
    if ($Debug) {
        Write-Host "`n[DEBUG] Raw netsh output:" -ForegroundColor DarkGray
        Write-Host $output
        Write-Host "`n[DEBUG] End of raw output`n" -ForegroundColor DarkGray
    }
    
    $currentSSID = $null
    
    foreach ($line in $output -split "`r`n") {
        $line = $line.Trim()
        
        if ($Debug) { Write-Host "[DEBUG] Processing: $line" -ForegroundColor DarkGray }
        
        # Match SSID line - various formats
        if ($line -match "SSID\s+\d+\s*:\s*(.+)" -or $line -match "SSID\s*:\s*(.+)") {
            $currentSSID = $matches[1].Trim()
            if ($Debug) { Write-Host "[DEBUG] Found SSID: $currentSSID" -ForegroundColor Green }
            if (-not $networks.ContainsKey($currentSSID)) {
                $networks[$currentSSID] = @{
                    SSID = $currentSSID
                    BSSIDs = @()
                    Bands = @{}
                    BestSignal = 0
                }
            }
        }
        # Match BSSID line
        elseif ($line -match "BSSID\s+\d+\s*:\s*([0-9a-fA-F-]+)" -or $line -match "BSSID\s*:\s*([0-9a-fA-F-]+)") {
            $bssid = $matches[1].Trim()
            if ($currentSSID -and $networks.ContainsKey($currentSSID)) {
                if ($Debug) { Write-Host "[DEBUG] Found BSSID: $bssid for SSID: $currentSSID" -ForegroundColor Green }
                $bssidObj = @{
                    BSSID = $bssid
                    Channel = $null
                    Band = "Unknown"
                    Signal = 0
                }
                $networks[$currentSSID].BSSIDs += $bssidObj
            }
        }
        # Match Signal line
        elseif ($line -match "Signal\s*:\s*(\d+)%") {
            $signal = [int]$matches[1]
            if ($currentSSID -and $networks.ContainsKey($currentSSID) -and 
                $networks[$currentSSID].BSSIDs.Count -gt 0) {
                $lastBSSID = $networks[$currentSSID].BSSIDs[$networks[$currentSSID].BSSIDs.Count - 1]
                $lastBSSID.Signal = $signal
                if ($signal -gt $networks[$currentSSID].BestSignal) {
                    $networks[$currentSSID].BestSignal = $signal
                }
                if ($Debug) { Write-Host "[DEBUG] Set signal $signal for last BSSID" -ForegroundColor Green }
            }
        }
        # Match Channel line - also check for "Primary channels"
        elseif ($line -match "Channel\s*:\s*(\d+)" -or $line -match "Primary channels\s*:\s*(\d+)") {
            $channel = [int]$matches[1]
            $band = Get-BandFromChannel -Channel $channel
            if ($currentSSID -and $networks.ContainsKey($currentSSID) -and 
                $networks[$currentSSID].BSSIDs.Count -gt 0) {
                $lastBSSID = $networks[$currentSSID].BSSIDs[$networks[$currentSSID].BSSIDs.Count - 1]
                if ($lastBSSID.Channel -eq $null) {
                    $lastBSSID.Channel = $channel
                    $lastBSSID.Band = $band
                    if (-not $networks[$currentSSID].Bands.ContainsKey($band)) {
                        $networks[$currentSSID].Bands[$band] = $true
                        if ($Debug) { Write-Host "[DEBUG] Found band $band for SSID $currentSSID" -ForegroundColor Green }
                    }
                }
            }
        }
    }
    
    if ($Debug) {
        Write-Host "`n[DEBUG] Parsed networks:" -ForegroundColor DarkGray
        foreach ($key in $networks.Keys) {
            Write-Host "[DEBUG] SSID: $key, Bands: $($networks[$key].Bands.Keys -join ','), BSSIDs: $($networks[$key].BSSIDs.Count)" -ForegroundColor Green
            foreach ($b in $networks[$key].BSSIDs) {
                Write-Host "[DEBUG]   BSSID: $($b.BSSID), Channel: $($b.Channel), Band: $($b.Band), Signal: $($b.Signal)%" -ForegroundColor Green
            }
        }
    }
    
    # Convert to array of objects
    $result = @()
    foreach ($key in $networks.Keys | Sort-Object) {
        $net = $networks[$key]
        $netObj = [PSCustomObject]@{
            SSID = $net.SSID
            BestSignal = $net.BestSignal
            AvailableBands = [System.Collections.Generic.List[string]]::new()
            BSSIDDetails = $net.BSSIDs
        }
        
        $bandList = $net.Bands.Keys | Sort-Object { 
            if ($_ -eq "2.4GHz") { 1 }
            elseif ($_ -eq "5GHz") { 2 }
            elseif ($_ -eq "6GHz") { 3 }
            else { 4 }
        }
        foreach ($band in $bandList) {
            $netObj.AvailableBands.Add($band)
        }
        
        $result += $netObj
    }
    
    return $result
}

# Function to connect to a specific WiFi network on a specific band
function Connect-ToWifiBand {
    param(
        [string]$SSID,
        [string]$Band
    )
    
    Write-Host ("`nAttempting to connect to '$SSID' on $Band band...") -ForegroundColor Yellow
    
    $currentInterface = netsh wlan show interfaces 2>&1
    $connectedSSID = $null
    foreach ($line in $currentInterface -split "`r`n") {
        if ($line -match "SSID\s*:\s*(.+)") {
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
    
    $bestBSSID = $null
    $bestSignal = 0
    foreach ($bssid in $targetNetwork.BSSIDDetails) {
        if ($bssid.Band -eq $Band -and $bssid.Signal -gt $bestSignal) {
            $bestSignal = $bssid.Signal
            $bestBSSID = $bssid.BSSID
        }
    }
    
    if (-not $bestBSSID) {
        Write-Host ("No BSSID found for $SSID on $Band band.") -ForegroundColor Red
        Write-Host ("This might mean the $Band band is currently unavailable or out of range.") -ForegroundColor Yellow
        return $false
    }
    
    Write-Host ("Connecting to BSSID: $bestBSSID (Channel: $($targetNetwork.BSSIDDetails | Where-Object { $_.BSSID -eq $bestBSSID } | Select-Object -ExpandProperty Channel), Signal: $bestSignal%)") -ForegroundColor Cyan
    
    try {
        Write-Host ("Connecting to $SSID...") -ForegroundColor Cyan
        $result = netsh wlan connect name="$SSID" 2>&1
        Start-Sleep -Seconds 5
        
        $newInterface = netsh wlan show interfaces 2>&1
        $newSSID = $null
        $newBSSID = $null
        foreach ($line in $newInterface -split "`r`n") {
            if ($line -match "SSID\s*:\s*(.+)") { $newSSID = $matches[1].Trim() }
            if ($line -match "BSSID\s*:\s*([0-9a-fA-F-]+)") { $newBSSID = $matches[1].Trim() }
        }
        
        if ($newSSID -eq $SSID) {
            Write-Host ("Successfully connected to $SSID!") -ForegroundColor Green
            Write-Host ("BSSID: $newBSSID") -ForegroundColor Green
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

# Function to display detailed network information
function Show-NetworkDetails {
    param([object]$Network)
    
    Clear-Host
    Write-Host "`n" + ("=" * 80)
    Write-Host ("Network: $($Network.SSID)") -ForegroundColor Cyan
    Write-Host ("=" * 80)
    Write-Host ("Signal strength: $($Network.BestSignal)%")
    Write-Host ("Available bands: $($Network.AvailableBands -join ', ')")
    Write-Host ("-" * 80)
    
    # Always show BSSID details for networks with multiple bands
    if ($Verbose -or $Network.AvailableBands.Count -gt 1) {
        Write-Host "`nBSSID Details:" -ForegroundColor Cyan
        Write-Host ("-" * 80)
        Write-Host ("{0,-20} {1,-8} {2,-10} {3,5}%" -f "BSSID", "Channel", "Band", "Signal")
        Write-Host ("-" * 80)
        
        $sortedBSSIDs = $Network.BSSIDDetails | Sort-Object { $_.Signal } -Descending
        foreach ($bssid in $sortedBSSIDs) {
            $channelStr = if ($bssid.Channel -ne $null) { $bssid.Channel } else { "N/A" }
            $line = "{0,-20} {1,-8} {2,-10} {3,5}%" -f $bssid.BSSID, $channelStr, $bssid.Band, $bssid.Signal
            Write-Host $line
        }
        Write-Host "`n" + ("=" * 80)
    }
    
    # If network has multiple bands but we're not showing details, show a hint
    if (-not $Verbose -and $Network.AvailableBands.Count -gt 1) {
        Write-Host ("`nPress 'D' when selecting this network to see all BSSIDs and bands.") -ForegroundColor Yellow
    }
}

# Function to display available networks in a table
function Show-NetworkList {
    param([array]$Networks)
    
    Write-Host "`n" + ("=" * 80)
    Write-Host "Available WiFi Networks" -ForegroundColor Cyan
    Write-Host ("=" * 80)
    Write-Host ("{0,-3} {1,-30} {2,6}%  {3}" -f "#", "SSID", "Sig", "Bands") -ForegroundColor DarkGray
    Write-Host ("-" * 80)
    
    $index = 1
    foreach ($net in $Networks) {
        $bandsStr = $net.AvailableBands -join ","
        if ($bandsStr -eq "") { $bandsStr = "Unknown" }
        Write-Host ("{0,2}. {1,-29} {2,4}%   {3}" -f $index, $net.SSID, $net.BestSignal, $bandsStr)
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
    Write-Host "  [V] Toggle verbose mode (shows all BSSIDs)"
    Write-Host "  [D] Debug mode (shows raw parsing data)"
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
    elseif ($choice -match "^[vV]$") {
        $script:Verbose = -not $Verbose
        Write-Host ("Verbose mode: $Verbose") -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        Show-MainMenu
        return
    }
    elseif ($choice -match "^[dD]$") {
        $script:Debug = -not $Debug
        Write-Host ("Debug mode: $Debug") -ForegroundColor Yellow
        Start-Sleep -Seconds 1
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
    
    Show-NetworkDetails -Network $Network
    
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
    foreach ($band in $Network.AvailableBands) {
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
Clear-Host
Write-Host "WiFi Band Switcher for Windows" -ForegroundColor Cyan
Write-Host "Version 1.0" -ForegroundColor DarkGray
Write-Host ""

# Handle command-line arguments
if ($ScanOnly) {
    $networks = Get-AvailableWifiNetworks
    Show-NetworkList -Networks $networks
    exit 0
}

if ($Debug) {
    $networks = Get-AvailableWifiNetworks
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
        $Verbose = $true
        Show-NetworkDetails -Network $targetNetwork
    } else {
        Write-Host ("Network '$SSID' not found.") -ForegroundColor Red
        exit 1
    }
    exit 0
}

# Interactive mode
Show-MainMenu
