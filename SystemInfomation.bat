# 2>nul & cls & set "SCRIPT_PATH=%~f0" & powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0' -Encoding UTF8) -join [char]10)" & exit /b

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =========================================================================
# BlueFIX IT Tool Kit - Professional Diagnostics & Systems Kit
# Website: bluefix.in
# =========================================================================

# 1. CHECK FOR ADMINISTRATOR PRIVILEGES
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($env:SCRIPT_PATH) {
        # Re-launch from Batch wrapper with elevation
        Start-Process cmd.exe -ArgumentList "/c `"$env:SCRIPT_PATH`"" -Verb RunAs
    } else {
        # Re-launch directly in PowerShell with elevation (for in-memory run)
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm bluefix.in/sitk | iex`"" -Verb RunAs
    }
    exit
}

# 2. CONSOLE SETUP
$Host.UI.RawUI.WindowTitle = "BlueFIX IT Tool Kit"
try {
    # Set window size and buffer size for standard console compatibility
    $size = $Host.UI.RawUI.WindowSize
    $size.Width = 120
    $size.Height = 45
    $Host.UI.RawUI.WindowSize = $size
    $buf = $Host.UI.RawUI.BufferSize
    $buf.Width = 120
    $buf.Height = 3000
    $Host.UI.RawUI.BufferSize = $buf
} catch {}

# 3. HELPER FUNCTIONS
function Show-LoadingScreen {
    Clear-Host
    Write-Host "╔═════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      BLUEFIX IT TOOL KIT - LOADING                      ║" -ForegroundColor Yellow
    Write-Host "╚═════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Gathering system diagnostics and initializing modules..." -ForegroundColor White
    Write-Host "  Please wait, this will take just a moment..." -ForegroundColor Gray
    Write-Host ""
}

function Get-SystemOverview {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_Bios -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
    
    $diskHealth = "Healthy (SMART OK)"
    try {
        $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        if ($disks) {
            foreach ($d in $disks) {
                if ($d.HealthStatus -ne 'Healthy') { $diskHealth = "Warning ($($d.HealthStatus))" }
            }
        } else { $diskHealth = "Unknown" }
    } catch { $diskHealth = "Unknown" }
    
    $ip = "Disconnected"
    $net = "Offline"
    try {
        $ipAddress = Get-NetIPAddress -InterfaceAddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1
        if ($ipAddress) {
            $ip = $ipAddress.IPAddress
            if (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                $net = "Online"
            } else { $net = "No Internet Connection" }
        }
    } catch { $ip = "Unknown"; $net = "Unknown" }
    
    $batStatus = "No Battery (Desktop)"
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $charge = $battery.EstimatedChargeRemaining
            $status = if ($battery.BatteryStatus -eq 2) { "Charging" } else { "Discharging" }
            $batStatus = "$status ($charge%)"
        }
    } catch {}
    
    $uptime = "Unknown"
    $lastBoot = "Unknown"
    $firstPowerOn = "Unknown"
    try {
        $uptimeSpan = (Get-Date) - $os.LastBootUpTime
        $uptime = "{0}d {1}h {2}m" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes
        $lastBoot = $os.LastBootUpTime.ToString("dd-MMM-yyyy hh:mm:ss tt")
    } catch {}
    try {
        $firstPowerOn = $os.InstallDate.ToString("dd-MMM-yyyy hh:mm:ss tt")
    } catch {}
    
    $winAct = "Unknown"
    try {
        $license = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%' and ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' and PartialProductKey is not null" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($license) {
            $statusMap = @{0="Unlicensed"; 1="Licensed"; 2="OOBGrace"; 3="OOTGrace"; 4="NonGenuineGrace"; 5="Notification"; 6="ExtendedGrace"}
            $winAct = $statusMap[[int]$license.LicenseStatus]
        }
    } catch {}

    return [PSCustomObject]@{
        WINVER = $os.Caption
        WINBUILD = "$($os.Version) (Build $($os.BuildNumber))"
        WINACT = $winAct
        BIOS = $bios.SerialNumber
        CPU = $cpu.Name
        RAM = "$([math]::Round($cs.TotalPhysicalMemory/1GB)) GB"
        GPU = $gpu.Name
        DISK = $diskHealth
        IP = $ip
        NET = $net
        BAT = $batStatus
        UPTIME = $uptime
        LASTBOOT = $lastBoot
        FIRSTPOWERON = $firstPowerOn
    }
}

function Show-MenuHeader {
    param($overview)
    Clear-Host
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host "                          BlueFIX IT Tool Kit - Professional Diagnostics                                  " -NoNewline -ForegroundColor Yellow
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host "                                      Website: bluefix.in                                                 " -NoNewline -ForegroundColor Gray
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║ SYSTEM OVERVIEW                                                                                          ║" -ForegroundColor Yellow
    Write-Host "  ╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("WINDOWS EDITION   = " + $overview.WINVER).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("WINDOWS BUILD     = " + $overview.WINBUILD).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("ACTIVATION STATUS = " + $overview.WINACT).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("BIOS SERIAL       = " + $overview.BIOS).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("CPU MODEL         = " + $overview.CPU).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("RAM CAPACITY      = " + $overview.RAM).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("GPU MODEL         = " + $overview.GPU).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("DISK HEALTH       = " + $overview.DISK).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("IP ADDRESS        = " + $overview.IP).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("NETWORK STATUS    = " + $overview.NET).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("BATTERY HEALTH    = " + $overview.BAT).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("SYSTEM UPTIME     = " + $overview.UPTIME).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("LAST BOOT TIME    = " + $overview.LASTBOOT).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("FIRST POWERED ON  = " + $overview.FIRSTPOWERON).PadRight(104) -NoNewline -ForegroundColor Green; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Show-MenuOptions {
    Write-Host "  ╔═════════════════════════════════════════════════╦═════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║ A. CORE INFORMATION TOOLS                       ║ B. ADDITIONAL PROFESSIONAL TOOLS                ║" -ForegroundColor Yellow
    Write-Host "  ╠═════════════════════════════════════════════════╬═════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║ 1. Full PC Information Viewer                   ║ 12. GPU Information Viewer                      ║" -ForegroundColor White
    Write-Host "  ║ 2. Windows Version & Build Checker              ║ 13. Windows Activation Status Checker           ║" -ForegroundColor White
    Write-Host "  ║ 3. BIOS Serial Number Viewer                    ║ 14. Office Activation Status Checker            ║" -ForegroundColor White
    Write-Host "  ║ 4. Installed Software List Exporter             ║ 15. Disk Partition Viewer                       ║" -ForegroundColor White
    Write-Host "  ║ 5. System Power On Date (Boot & Install)        ║ 16. Running Process Viewer                      ║" -ForegroundColor White
    Write-Host "  ║ 6. Driver Information Viewer                    ║ 17. Startup Apps Viewer                         ║" -ForegroundColor White
    Write-Host "  ║ 7. Network Information Tool                     ║ 18. Installed Windows Updates Viewer            ║" -ForegroundColor White
    Write-Host "  ║ 8. Battery Health Checker                       ║ 19. Internet Speed Quick Test                   ║" -ForegroundColor White
    Write-Host "  ║ 9. TPM & Secure Boot Status Checker             ║ 20. System Uptime Checker                       ║" -ForegroundColor White
    Write-Host "  ║ 10. RAM & CPU Info Tool                         ║ 21. Windows Error Log Exporter                  ║" -ForegroundColor White
    Write-Host "  ║ 11. Disk Health SMART Checker                   ║ 22. USB Device Viewer                           ║" -ForegroundColor White
    Write-Host "  ║                                                 ║ 23. WiFi Password Viewer                        ║" -ForegroundColor White
    Write-Host "  ║                                                 ║ 24. Temperature Monitoring Shortcut             ║" -ForegroundColor White
    Write-Host "  ║                                                 ║ 25. Restore Point Creator                       ║" -ForegroundColor White
    Write-Host "  ║                                                 ║ 26. Export Full Diagnostic Report               ║" -ForegroundColor White
    Write-Host "  ╚═════════════════════════════════════════════════╩═════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Run-Tool {
    param($title, $action)
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║" -NoNewline -ForegroundColor Cyan
    Write-Host ("  $title").PadRight(84) -NoNewline -ForegroundColor Yellow
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Invoke-Command -ScriptBlock $action
    
    Write-Host ""
    Write-Host "--------------------------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host " >>> Press any key to return to the main dashboard..." -ForegroundColor Green
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# =========================================================================
# 4. DIAGNOSTIC MODULE DEFINITIONS
# =========================================================================

function Show-PCInfo {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_Bios -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $bootMode = if (Test-Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State") { "UEFI" } else { "Legacy BIOS" }
    
    Write-Host "  Computer Name      : " -NoNewline -ForegroundColor Cyan; Write-Host $env:COMPUTERNAME -ForegroundColor White
    Write-Host "  Manufacturer       : " -NoNewline -ForegroundColor Cyan; Write-Host $cs.Manufacturer -ForegroundColor White
    Write-Host "  Model              : " -NoNewline -ForegroundColor Cyan; Write-Host $cs.Model -ForegroundColor White
    Write-Host "  System Type        : " -NoNewline -ForegroundColor Cyan; Write-Host $cs.SystemType -ForegroundColor White
    Write-Host "  Motherboard        : " -NoNewline -ForegroundColor Cyan; Write-Host "$($bb.Manufacturer) $($bb.Product)" -ForegroundColor White
    Write-Host "  Processor          : " -NoNewline -ForegroundColor Cyan; Write-Host $cpu.Name -ForegroundColor White
    Write-Host "  Total Memory (RAM) : " -NoNewline -ForegroundColor Cyan; Write-Host "$([math]::Round($cs.TotalPhysicalMemory/1GB, 2)) GB" -ForegroundColor White
    Write-Host "  OS Name            : " -NoNewline -ForegroundColor Cyan; Write-Host $os.Caption -ForegroundColor White
    Write-Host "  OS Version/Build   : " -NoNewline -ForegroundColor Cyan; Write-Host "$($os.Version) (Build $($os.BuildNumber))" -ForegroundColor White
    Write-Host "  OS Architecture    : " -NoNewline -ForegroundColor Cyan; Write-Host $os.OSArchitecture -ForegroundColor White
    Write-Host "  BIOS Serial        : " -NoNewline -ForegroundColor Cyan; Write-Host $bios.SerialNumber -ForegroundColor White
    Write-Host "  BIOS Version/Date  : " -NoNewline -ForegroundColor Cyan; Write-Host "$($bios.SMBIOSBIOSVersion) ($($bios.ReleaseDate))" -ForegroundColor White
    Write-Host "  Boot Mode          : " -NoNewline -ForegroundColor Cyan; Write-Host $bootMode -ForegroundColor White
    Write-Host "  System Language    : " -NoNewline -ForegroundColor Cyan; Write-Host $os.MUILanguages[0] -ForegroundColor White
}

function Show-WinVersion {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
    
    Write-Host "  Windows Edition    : " -NoNewline -ForegroundColor Cyan; Write-Host $os.Caption -ForegroundColor White
    Write-Host "  Display Version    : " -NoNewline -ForegroundColor Cyan; Write-Host $reg.DisplayVersion -ForegroundColor White
    Write-Host "  Release ID         : " -NoNewline -ForegroundColor Cyan; Write-Host $reg.ReleaseId -ForegroundColor White
    Write-Host "  Current Build      : " -NoNewline -ForegroundColor Cyan; Write-Host $reg.CurrentBuild -ForegroundColor White
    Write-Host "  UBR (Update Build) : " -NoNewline -ForegroundColor Cyan; Write-Host $reg.UBR -ForegroundColor White
    Write-Host "  Build Branch       : " -NoNewline -ForegroundColor Cyan; Write-Host $reg.BuildBranch -ForegroundColor White
    Write-Host "  Installation Date  : " -NoNewline -ForegroundColor Cyan; Write-Host $os.InstallDate -ForegroundColor White
    Write-Host "  Registered Owner   : " -NoNewline -ForegroundColor Cyan; Write-Host $reg.RegisteredOwner -ForegroundColor White
    Write-Host "  Product ID         : " -NoNewline -ForegroundColor Cyan; Write-Host $os.SerialNumber -ForegroundColor White
}

function Show-BiosSerial {
    $bios = Get-CimInstance Win32_Bios -ErrorAction SilentlyContinue
    $bb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
    
    Write-Host "  BIOS Serial Number : " -NoNewline -ForegroundColor Cyan; Write-Host $bios.SerialNumber -ForegroundColor Green
    Write-Host "  BIOS Manufacturer  : " -NoNewline -ForegroundColor Cyan; Write-Host $bios.Manufacturer -ForegroundColor White
    Write-Host "  BIOS Version       : " -NoNewline -ForegroundColor Cyan; Write-Host $bios.SMBIOSBIOSVersion -ForegroundColor White
    Write-Host "  Motherboard Serial : " -NoNewline -ForegroundColor Cyan; Write-Host $bb.SerialNumber -ForegroundColor White
    Write-Host "  System UUID        : " -NoNewline -ForegroundColor Cyan; Write-Host $cs.UUID -ForegroundColor White
}

function Export-SoftwareList {
    Write-Host "Gathering installed software database..." -ForegroundColor Yellow
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $apps = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
            Sort-Object DisplayName
            
    $file = "$env:USERPROFILE\Desktop\Installed_Software_List.txt"
    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine("======================================================================") | Out-Null
    $sb.AppendLine("                 INSTALLED SOFTWARE LIST EXPORT") | Out-Null
    $sb.AppendLine("                     Website: bluefix.in") | Out-Null
    $sb.AppendLine("                     Total Apps Found: $($apps.Count)") | Out-Null
    $sb.AppendLine("                     Generated: $(Get-Date)") | Out-Null
    $sb.AppendLine("======================================================================") | Out-Null
    $sb.AppendLine() | Out-Null
    foreach ($app in $apps) {
        $sb.AppendLine("App Name  : $($app.DisplayName)") | Out-Null
        $sb.AppendLine("Version   : $($app.DisplayVersion)") | Out-Null
        $sb.AppendLine("Publisher : $($app.Publisher)") | Out-Null
        $sb.AppendLine("InstallDt : $($app.InstallDate)") | Out-Null
        $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    }
    $sb.ToString() | Out-File -FilePath $file -Encoding utf8
    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Saved to: $file" -ForegroundColor Yellow
    Start-Process "notepad.exe" $file
}

function Show-PowerOnDate {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $installDate = $os.InstallDate
    $lastBoot = $os.LastBootUpTime
    $uptime = (Get-Date) - $lastBoot
    
    Write-Host "  Operating System Install Date : " -NoNewline -ForegroundColor Cyan
    Write-Host $installDate -ForegroundColor White
    Write-Host "  System Last Power On (Boot)   : " -NoNewline -ForegroundColor Cyan
    Write-Host $lastBoot -ForegroundColor Green
    Write-Host "  Current System Run Duration   : " -NoNewline -ForegroundColor Cyan
    Write-Host "$($uptime.Days) Days, $($uptime.Hours) Hours, $($uptime.Minutes) Minutes, $($uptime.Seconds) Seconds" -ForegroundColor Yellow
}

function Show-DriverInfo {
    Write-Host "  Listing active and critical system drivers (first 30 entries):" -ForegroundColor Gray
    Write-Host ""
    $drivers = Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | 
               Where-Object { $_.State -eq 'Running' } | 
               Select-Object Name, DisplayName, StartMode, ServiceType | 
               Select-Object -First 30
    foreach ($d in $drivers) {
        Write-Host "  [$($d.Name)]" -ForegroundColor Cyan
        Write-Host "    Display Name : $($d.DisplayName)" -ForegroundColor White
        Write-Host "    Start Mode   : $($d.StartMode)" -ForegroundColor White
        Write-Host "    Service Type : $($d.ServiceType)" -ForegroundColor Gray
    }
}

function Show-NetworkInfo {
    Write-Host "  [Active Network Connections]" -ForegroundColor Yellow
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        Write-Host "    Adapter Name : " -NoNewline -ForegroundColor Cyan; Write-Host $_.Name -ForegroundColor White
        Write-Host "    Description  : " -NoNewline -ForegroundColor Cyan; Write-Host $_.InterfaceDescription -ForegroundColor Gray
        Write-Host "    Link Speed   : " -NoNewline -ForegroundColor Cyan; Write-Host $_.LinkSpeed -ForegroundColor White
        Write-Host "    MAC Address  : " -NoNewline -ForegroundColor Cyan; Write-Host $_.MacAddress -ForegroundColor White
        Write-Host "    Status       : " -NoNewline -ForegroundColor Cyan; Write-Host $_.Status -ForegroundColor Green
        Write-Host "    --------------------------------------------------" -ForegroundColor Gray
    }
    Write-Host "  [IP Address Settings]" -ForegroundColor Yellow
    Get-NetIPAddress -InterfaceAddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | ForEach-Object {
        Write-Host "    IP Address   : " -NoNewline -ForegroundColor Cyan; Write-Host $_.IPAddress -ForegroundColor White
        Write-Host "    Interface    : " -NoNewline -ForegroundColor Cyan; Write-Host $_.InterfaceAlias -ForegroundColor Gray
        Write-Host "    --------------------------------------------------" -ForegroundColor Gray
    }
    $route = Get-NetRoute -DestinationPrefix 0.0.0.0/0 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($route) {
        Write-Host "    Default Gateway : " -NoNewline -ForegroundColor Cyan; Write-Host $route.NextHop -ForegroundColor White
    }
    Write-Host "  [DNS Servers]" -ForegroundColor Yellow
    Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | ForEach-Object {
        Write-Host "    DNS on $($_.InterfaceAlias) : " -NoNewline -ForegroundColor Cyan; Write-Host ($_.ServerAddresses -join ", ") -ForegroundColor White
    }
    Write-Host "    --------------------------------------------------" -ForegroundColor Gray
    Write-Host "  [Connection Status]" -ForegroundColor Yellow
    if (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Write-Host "    Internet Access : " -NoNewline -ForegroundColor Cyan; Write-Host "ONLINE (Ping to Google DNS Successful)" -ForegroundColor Green
    } else {
        Write-Host "    Internet Access : " -NoNewline -ForegroundColor Cyan; Write-Host "OFFLINE" -ForegroundColor Red
    }
    Write-Host "  [Public GeoIP Lookup]" -ForegroundColor Yellow
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Timeout = 3000
        $ip = $wc.DownloadString("https://api.ipify.org").Trim()
        $geo = $wc.DownloadString("https://ipinfo.io/$ip/json") | ConvertFrom-Json
        Write-Host "    Public IP       : " -NoNewline -ForegroundColor Cyan; Write-Host $ip -ForegroundColor Green
        Write-Host "    ISP Operator    : " -NoNewline -ForegroundColor Cyan; Write-Host $geo.org -ForegroundColor White
        Write-Host "    Geo Location    : " -NoNewline -ForegroundColor Cyan; Write-Host "$($geo.city), $($geo.region), $($geo.country)" -ForegroundColor White
    } catch {
        Write-Host "    Public IP       : " -NoNewline -ForegroundColor Cyan; Write-Host "Unavailable (Connection timeout)" -ForegroundColor Red
    }
}

function Show-BatteryHealth {
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if (-not $battery) {
        Write-Host "  [!] No battery detected. This system appears to be a Desktop PC." -ForegroundColor Red
        return
    }
    Write-Host "Generating official Windows Battery Report..." -ForegroundColor Yellow
    $reportPath = "$env:TEMP\battery-report.html"
    powercfg /batteryreport /output $reportPath | Out-Null
    Write-Host "Battery Report generated successfully at: $reportPath" -ForegroundColor Green
    Write-Host ""
    $wear = 100
    if ($battery.DesignCapacity -and $battery.FullChargeCapacity) {
        $wear = [math]::Round(($battery.FullChargeCapacity / $battery.DesignCapacity) * 100, 2)
    }
    Write-Host "  Device Name        : " -NoNewline -ForegroundColor Cyan; Write-Host $battery.Name -ForegroundColor White
    Write-Host "  Manufacturer       : " -NoNewline -ForegroundColor Cyan; Write-Host $battery.Manufacturer -ForegroundColor White
    Write-Host "  Chemistry          : " -NoNewline -ForegroundColor Cyan; Write-Host $battery.DeviceChemistry -ForegroundColor White
    Write-Host "  Design Capacity    : " -NoNewline -ForegroundColor Cyan; Write-Host "$($battery.DesignCapacity) mWh" -ForegroundColor White
    Write-Host "  Full Charge Cap    : " -NoNewline -ForegroundColor Cyan; Write-Host "$($battery.FullChargeCapacity) mWh" -ForegroundColor White
    Write-Host "  Battery Health     : " -NoNewline -ForegroundColor Cyan; 
    if ($wear -ge 80) {
        Write-Host "$wear% (Healthy)" -ForegroundColor Green
    } elseif ($wear -ge 50) {
        Write-Host "$wear% (Degraded/Fair)" -ForegroundColor Yellow
    } else {
        Write-Host "$wear% (Poor/Replace Recommended)" -ForegroundColor Red
    }
    Write-Host "  Current Status     : " -NoNewline -ForegroundColor Cyan; 
    if ($battery.BatteryStatus -eq 2) {
        Write-Host "Charging" -ForegroundColor Green
    } else {
        Write-Host "Discharging" -ForegroundColor Yellow
    }
    Write-Host "  Charge Percentage  : " -NoNewline -ForegroundColor Cyan; Write-Host "$($battery.EstimatedChargeRemaining)%" -ForegroundColor White
    if ($battery.EstimatedRunTime -and $battery.EstimatedRunTime -ne 71582788) {
        $hours = [math]::Floor($battery.EstimatedRunTime / 60)
        $mins = $battery.EstimatedRunTime % 60
        Write-Host "  Est. Life Remaining: " -NoNewline -ForegroundColor Cyan; Write-Host "$hours Hours, $mins Minutes" -ForegroundColor Green
    } else {
        Write-Host "  Est. Life Remaining: " -NoNewline -ForegroundColor Cyan; Write-Host "Calculating..." -ForegroundColor Gray
    }
    Write-Host ""
    $choice = Read-Host "Do you want to open the detailed battery report HTML page? (Y/N)"
    if ($choice -like 'y*') { Start-Process $reportPath }
}

function Show-TpmSecureBoot {
    Write-Host "  [Trusted Platform Module (TPM) Status]" -ForegroundColor Yellow
    try {
        $tpm = Get-Tpm
        Write-Host "    TPM Present   : " -NoNewline -ForegroundColor Cyan; Write-Host (if ($tpm.TpmPresent) { "YES" } else { "NO" }) -ForegroundColor (if ($tpm.TpmPresent) { "Green" } else { "Red" })
        Write-Host "    TPM Enabled   : " -NoNewline -ForegroundColor Cyan; Write-Host (if ($tpm.TpmEnabled) { "YES" } else { "NO" }) -ForegroundColor (if ($tpm.TpmEnabled) { "Green" } else { "Red" })
        Write-Host "    TPM Activated : " -NoNewline -ForegroundColor Cyan; Write-Host (if ($tpm.TpmActivated) { "YES" } else { "NO" }) -ForegroundColor (if ($tpm.TpmActivated) { "Green" } else { "Red" })
        Write-Host "    TPM Ready     : " -NoNewline -ForegroundColor Cyan; Write-Host (if ($tpm.TpmReady) { "YES" } else { "NO" }) -ForegroundColor (if ($tpm.TpmReady) { "Green" } else { "Red" })
        $tpmDevice = Get-CimInstance -Namespace root\cimv2\security\microsofttpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue
        if ($tpmDevice) {
            Write-Host "    TPM Version   : " -NoNewline -ForegroundColor Cyan; Write-Host $tpmDevice.SpecVersion -ForegroundColor White
        }
    } catch {
        Write-Host "    TPM Support   : " -NoNewline -ForegroundColor Cyan; Write-Host "TPM disabled, not present, or script lacks Admin rights." -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  [Secure Boot UEFI Status]" -ForegroundColor Yellow
    try {
        $sb = Confirm-SecureBootUEFI
        Write-Host "    Secure Boot   : " -NoNewline -ForegroundColor Cyan; Write-Host "ENABLED" -ForegroundColor Green
    } catch {
        Write-Host "    Secure Boot   : " -NoNewline -ForegroundColor Cyan; Write-Host "DISABLED or Unsupported by Hardware/Legacy BIOS Mode" -ForegroundColor Red
    }
}

function Show-RamCpuInfo {
    Write-Host "  [Processor (CPU) Specifications]" -ForegroundColor Yellow
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    Write-Host "    CPU Name      : " -NoNewline -ForegroundColor Cyan; Write-Host $cpu.Name -ForegroundColor White
    Write-Host "    Manufacturer  : " -NoNewline -ForegroundColor Cyan; Write-Host $cpu.Manufacturer -ForegroundColor White
    Write-Host "    Physical Cores: " -NoNewline -ForegroundColor Cyan; Write-Host $cpu.NumberOfCores -ForegroundColor White
    Write-Host "    Threads       : " -NoNewline -ForegroundColor Cyan; Write-Host $cpu.NumberOfLogicalProcessors -ForegroundColor White
    Write-Host "    Max Clock     : " -NoNewline -ForegroundColor Cyan; Write-Host "$($cpu.MaxClockSpeed) MHz" -ForegroundColor White
    Write-Host "    L2 Cache Size : " -NoNewline -ForegroundColor Cyan; Write-Host "$($cpu.L2CacheSize) KB" -ForegroundColor White
    Write-Host "    L3 Cache Size : " -NoNewline -ForegroundColor Cyan; Write-Host "$($cpu.L3CacheSize) KB" -ForegroundColor White
    Write-Host ""
    Write-Host "  [Physical Memory (RAM) Hardware]" -ForegroundColor Yellow
    $ram = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $total = 0
    $idx = 1
    $formFactorMap = @{0="Unknown"; 1="Other"; 2="SIP"; 3="DIP"; 4="ZIP"; 5="SOJ"; 6="Proprietary"; 7="SIMM"; 8="DIMM"; 9="TSOP"; 10="PGA"; 11="RIMM"; 12="SODIMM"; 13="SRIMM"; 14="SMD"; 15="SSMP"; 16="QFP"; 17="TQFP"; 18="SOIC"; 19="LCC"; 20="PLCC"; 21="BGA"; 22="FPBGA"; 23="LGA"; 24="FB-DIMM"}
    foreach ($r in $ram) {
        $ff = $formFactorMap[[int]$r.FormFactor]
        Write-Host "    Slot $idx Information:" -ForegroundColor Cyan
        Write-Host "      Manufacturer: $($r.Manufacturer)" -ForegroundColor White
        Write-Host "      Capacity    : $([math]::Round($r.Capacity / 1GB, 2)) GB" -ForegroundColor White
        Write-Host "      Speed       : $($r.Speed) MHz" -ForegroundColor White
        Write-Host "      Form Factor : $ff" -ForegroundColor White
        Write-Host "      Part Number : $($r.PartNumber.Trim())" -ForegroundColor Gray
        $total += $r.Capacity
        $idx++
    }
    Write-Host ""
    Write-Host "    Total Hardware Memory: $([math]::Round($total / 1GB, 2)) GB" -ForegroundColor Green
}

function Show-DiskSmart {
    $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if (-not $disks) {
        Write-Host "  [!] No physical disks found." -ForegroundColor Red
        return
    }
    foreach ($d in $disks) {
        $color = if ($d.HealthStatus -eq 'Healthy') { "Green" } else { "Red" }
        Write-Host "  Device Model  : " -NoNewline -ForegroundColor Cyan; Write-Host $d.FriendlyName -ForegroundColor White
        Write-Host "  Serial Number : " -NoNewline -ForegroundColor Cyan; Write-Host $d.SerialNumber -ForegroundColor White
        Write-Host "  Bus Type      : " -NoNewline -ForegroundColor Cyan; Write-Host $d.BusType -ForegroundColor White
        Write-Host "  Media Type    : " -NoNewline -ForegroundColor Cyan; Write-Host $d.MediaType -ForegroundColor White
        Write-Host "  Capacity      : " -NoNewline -ForegroundColor Cyan; Write-Host "$([math]::Round($d.Size/1GB, 2)) GB" -ForegroundColor White
        Write-Host "  SMART Status  : " -NoNewline -ForegroundColor Cyan; Write-Host $d.HealthStatus -ForegroundColor $color
        Write-Host "  Operational   : " -NoNewline -ForegroundColor Cyan; Write-Host ($d.OperationalStatus -join ", ") -ForegroundColor White
        Write-Host "  --------------------------------------------------" -ForegroundColor Gray
    }
}

function Show-GpuInfo {
    $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    if (-not $gpus) {
        Write-Host "  [!] No graphics processing unit detected." -ForegroundColor Red
        return
    }
    foreach ($gpu in $gpus) {
        Write-Host "  Graphics Card : " -NoNewline -ForegroundColor Cyan; Write-Host $gpu.Name -ForegroundColor White
        Write-Host "  Driver Version: " -NoNewline -ForegroundColor Cyan; Write-Host $gpu.DriverVersion -ForegroundColor White
        Write-Host "  Driver Date   : " -NoNewline -ForegroundColor Cyan; Write-Host $gpu.DriverDate -ForegroundColor White
        Write-Host "  Video Memory  : " -NoNewline -ForegroundColor Cyan; Write-Host "$([math]::Round($gpu.AdapterRAM / 1MB, 2)) MB" -ForegroundColor White
        Write-Host "  Resolution    : " -NoNewline -ForegroundColor Cyan; Write-Host $gpu.VideoModeDescription -ForegroundColor White
        Write-Host "  --------------------------------------------------" -ForegroundColor Gray
    }
}

function Show-WinActivation {
    Write-Host "  [Windows Product Key & Activation Status]" -ForegroundColor Yellow
    
    # Get Windows Product Keys
    $biosKey = (Get-WmiObject -query 'select * from SoftwareLicensingService' -ErrorAction SilentlyContinue).OA3xOriginalProductKey
    $regKey = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -ErrorAction SilentlyContinue).BackupProductKeyDefault
    
    if ($biosKey) {
        Write-Host "  BIOS OEM Product Key : " -NoNewline -ForegroundColor Cyan; Write-Host $biosKey -ForegroundColor Green
    } else {
        Write-Host "  BIOS OEM Product Key : " -NoNewline -ForegroundColor Cyan; Write-Host "Not Found (No OEM Key)" -ForegroundColor Gray
    }
    
    if ($regKey) {
        Write-Host "  Installed Product Key: " -NoNewline -ForegroundColor Cyan; Write-Host $regKey -ForegroundColor Green
    } else {
        Write-Host "  Installed Product Key: " -NoNewline -ForegroundColor Cyan; Write-Host "Not Found" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Get Activation Status via WMI
    $winLicense = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%' and PartialProductKey is not null" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($winLicense) {
        $statusStr = switch ($winLicense.LicenseStatus) {
            0 { "Unlicensed" }
            1 { "Licensed (Activated)" }
            2 { "OOB Grace (Initial Grace Period)" }
            3 { "OOT Grace (Out-of-Tolerance Grace Period)" }
            4 { "Non-Genuine Grace" }
            5 { "Notification (Activation Failed)" }
            6 { "Extended Grace" }
            default { "Unknown Status ($($winLicense.LicenseStatus))" }
        }
        $statusColor = if ($winLicense.LicenseStatus -eq 1) { "Green" } else { "Red" }
        Write-Host "  Activation Status    : " -NoNewline -ForegroundColor Cyan; Write-Host $statusStr -ForegroundColor $statusColor
        Write-Host "  Partial Product Key  : " -NoNewline -ForegroundColor Cyan; Write-Host $winLicense.PartialProductKey -ForegroundColor White
    }
    Write-Host ""
    
    Write-Host "  Running Software License Manager Script (slmgr.vbs)..." -ForegroundColor Yellow
    Write-Host ""
    cscript //nologo $env:SystemRoot\system32\slmgr.vbs /dli | Write-Host -ForegroundColor White
    Write-Host ""
    cscript //nologo $env:SystemRoot\system32\slmgr.vbs /xpr | Write-Host -ForegroundColor Green
}

function Show-OfficeActivation {
    Write-Host "  [Office Activation Status & Partial Key]" -ForegroundColor Yellow
    Write-Host "  Note: Modern Office versions do not store the full product key locally for security." -ForegroundColor Gray
    Write-Host ""
    
    $paths = @(
        "C:\Program Files\Microsoft Office\Office16\ospp.vbs",
        "C:\Program Files (x86)\Microsoft Office\Office16\ospp.vbs",
        "C:\Program Files\Microsoft Office\Office15\ospp.vbs",
        "C:\Program Files (x86)\Microsoft Office\Office15\ospp.vbs",
        "C:\Program Files\Microsoft Office\Office14\ospp.vbs",
        "C:\Program Files (x86)\Microsoft Office\Office14\ospp.vbs"
    )
    $found = $false
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Write-Host "  Found Office Licensing Script: $p" -ForegroundColor Green
            cscript //nologo $p /dstatus | Write-Host -ForegroundColor White
            $found = $true
            break
        }
    }
    if (-not $found) {
        $search = Get-ChildItem -Path "C:\Program Files\Microsoft Office", "C:\Program Files (x86)\Microsoft Office" -Filter "ospp.vbs" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($search) {
            Write-Host "  Found Office Licensing Script: $($search.FullName)" -ForegroundColor Green
            cscript //nologo $search.FullName /dstatus | Write-Host -ForegroundColor White
        } else {
            Write-Host "  [!] Microsoft Office Activation script (ospp.vbs) not found." -ForegroundColor Red
            Write-Host "  If Office is installed, it may be a Microsoft Store app or Microsoft 365 subscription edition, which manages licensing via account login." -ForegroundColor Gray
        }
    }
}

function Show-Partitions {
    $volumes = Get-Volume | Where-Object { $_.DriveLetter }
    foreach ($v in $volumes) {
        $percent = [math]::Round(($v.SizeRemaining / $v.Size) * 100, 1)
        $usedPercent = 100 - $percent
        Write-Host "  Drive Letter  : " -NoNewline -ForegroundColor Cyan; Write-Host "$($v.DriveLetter):" -ForegroundColor Green
        Write-Host "  Volume Label  : " -NoNewline -ForegroundColor Cyan; Write-Host $v.FileSystemLabel -ForegroundColor White
        Write-Host "  File System   : " -NoNewline -ForegroundColor Cyan; Write-Host $v.FileSystem -ForegroundColor White
        Write-Host "  Drive Size    : " -NoNewline -ForegroundColor Cyan; Write-Host "$([math]::Round($v.Size/1GB, 2)) GB" -ForegroundColor White
        Write-Host "  Free Space    : " -NoNewline -ForegroundColor Cyan; Write-Host "$([math]::Round($v.SizeRemaining/1GB, 2)) GB ($percent% Free)" -ForegroundColor Green
        $barLength = 20
        $filledLength = [math]::Round(($usedPercent / 100) * $barLength)
        $emptyLength = $barLength - $filledLength
        $barStr = "[" + ("#" * $filledLength) + ("-" * $emptyLength) + "]"
        Write-Host "  Usage Bar     : " -NoNewline -ForegroundColor Cyan; Write-Host "$barStr $usedPercent% Used" -ForegroundColor (if ($usedPercent -gt 85) { "Red" } else { "Yellow" })
        Write-Host "  --------------------------------------------------" -ForegroundColor Gray
    }
}

function Show-Processes {
    Write-Host "  [Top 10 Processes by Memory Consumption]" -ForegroundColor Yellow
    $mems = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10
    Write-Host "     PID | Process Name                  | Memory Usage (MB)" -ForegroundColor Cyan
    Write-Host "    --------------------------------------------------------" -ForegroundColor Gray
    foreach ($p in $mems) {
        $name = $p.ProcessName.PadRight(30)
        $pid = $p.Id.ToString().PadRight(7)
        $mem = [math]::Round($p.WorkingSet64 / 1MB, 2)
        Write-Host "    $pid | $name | $mem MB" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  [Top 10 Processes by Active CPU Usage]" -ForegroundColor Yellow
    $cpus = Get-Process | Where-Object { $_.CPU } | Sort-Object CPU -Descending | Select-Object -First 10
    Write-Host "     PID | Process Name                  | CPU Time (Sec)" -ForegroundColor Cyan
    Write-Host "    --------------------------------------------------------" -ForegroundColor Gray
    foreach ($p in $cpus) {
        $name = $p.ProcessName.PadRight(30)
        $pid = $p.Id.ToString().PadRight(7)
        $cpuSec = [math]::Round($p.CPU, 2)
        Write-Host "    $pid | $name | $cpuSec s" -ForegroundColor White
    }
}

function Show-StartupApps {
    $startups = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
    if (-not $startups) {
        Write-Host "  [!] No startup items registered in WMI." -ForegroundColor Red
        return
    }
    foreach ($s in $startups) {
        Write-Host "  App Name  : " -NoNewline -ForegroundColor Cyan; Write-Host $s.Name -ForegroundColor White
        Write-Host "  Command   : " -NoNewline -ForegroundColor Cyan; Write-Host $s.Command -ForegroundColor Gray
        Write-Host "  Location  : " -NoNewline -ForegroundColor Cyan; Write-Host $s.Location -ForegroundColor White
        Write-Host "  User      : " -NoNewline -ForegroundColor Cyan; Write-Host $s.User -ForegroundColor White
        Write-Host "  --------------------------------------------------" -ForegroundColor Gray
    }
}

function Show-Updates {
    Write-Host "Querying Quick Fix Engineering database..." -ForegroundColor Yellow
    $updates = Get-HotFix | Sort-Object InstalledOn -Descending -ErrorAction SilentlyContinue | Select-Object -First 15
    if (-not $updates) {
        Write-Host "  [!] No updates found or registry access restricted." -ForegroundColor Red
        return
    }
    foreach ($u in $updates) {
        Write-Host "  HotFix ID   : " -NoNewline -ForegroundColor Cyan; Write-Host $u.HotFixID -ForegroundColor Green
        Write-Host "  Description : " -NoNewline -ForegroundColor Cyan; Write-Host $u.Description -ForegroundColor White
        Write-Host "  Installed On: " -NoNewline -ForegroundColor Cyan; Write-Host $u.InstalledOn -ForegroundColor Yellow
        Write-Host "  Installed By: " -NoNewline -ForegroundColor Cyan; Write-Host $u.InstalledBy -ForegroundColor Gray
        Write-Host "  --------------------------------------------------" -ForegroundColor Gray
    }
}

function Test-InternetSpeed {
    Write-Host "Starting Speed Test..." -ForegroundColor Yellow
    Write-Host "Downloading a 5MB packet from Cloudflare CDN to calculate speed..." -ForegroundColor Gray
    $url = "https://speed.cloudflare.com/__down?bytes=5242880"
    $tempFile = "$env:TEMP\speedtest_bf.tmp"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($url, $tempFile)
        $stopwatch.Stop()
        $duration = $stopwatch.Elapsed.TotalSeconds
        $sizeInBits = 5242880 * 8
        $speedMbps = [math]::Round(($sizeInBits / $duration) / 1000000, 2)
        Write-Host ""
        Write-Host "  Download Speed: " -NoNewline -ForegroundColor Cyan; Write-Host "$speedMbps Mbps" -ForegroundColor Green
        Write-Host "  Time Taken    : " -NoNewline -ForegroundColor Cyan; Write-Host "$([math]::Round($duration, 2)) seconds" -ForegroundColor White
        Write-Host "  Packet Size   : " -NoNewline -ForegroundColor Cyan; Write-Host "5 Megabytes (MB)" -ForegroundColor White
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    } catch {
        Write-Host ""
        Write-Host "  [!] Speed test failed. Please check your internet connectivity." -ForegroundColor Red
        Write-Host "  Error Info: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Show-Uptime {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $lastBoot = $os.LastBootUpTime
    $diff = (Get-Date) - $lastBoot
    Write-Host "  System Last Booted  : " -NoNewline -ForegroundColor Cyan; Write-Host $lastBoot -ForegroundColor White
    Write-Host "  Uptime Duration     : " -NoNewline -ForegroundColor Cyan; 
    Write-Host "$($diff.Days) Days, $($diff.Hours) Hours, $($diff.Minutes) Minutes, $($diff.Seconds) Seconds" -ForegroundColor Green
}

function Export-ErrorLogs {
    $file = "$env:USERPROFILE\Desktop\Windows_Error_Logs.txt"
    Write-Host "Gathering last 50 System Errors and Warnings..." -ForegroundColor Yellow
    try {
        $logs = Get-EventLog -LogName System -EntryType Error, Warning -Newest 50
        $sb = New-Object System.Text.StringBuilder
        $sb.AppendLine("======================================================================") | Out-Null
        $sb.AppendLine("                 WINDOWS SYSTEM LOG EXPORT - LAST 50 ERRORS") | Out-Null
        $sb.AppendLine("                     Website: bluefix.in") | Out-Null
        $sb.AppendLine("                     Generated: $(Get-Date)") | Out-Null
        $sb.AppendLine("======================================================================") | Out-Null
        $sb.AppendLine() | Out-Null
        foreach ($l in $logs) {
            $sb.AppendLine("Time     : $($l.TimeGenerated)") | Out-Null
            $sb.AppendLine("Type     : $($l.EntryType)") | Out-Null
            $sb.AppendLine("Source   : $($l.Source)") | Out-Null
            $sb.AppendLine("Message  : $($l.Message)") | Out-Null
            $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
        }
        $sb.ToString() | Out-File -FilePath $file -Encoding utf8
        Write-Host "Event Logs exported successfully!" -ForegroundColor Green
        Write-Host "Saved to: $file" -ForegroundColor Yellow
        Start-Process "notepad.exe" $file
    } catch {
        Write-Host "  [!] Failed to extract event logs. Make sure you run this script as Admin." -ForegroundColor Red
        Write-Host "  Error Info: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

function Show-UsbDevices {
    $usb = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'USB' -and $_.FriendlyName }
    if (-not $usb) {
        Write-Host "  [!] No connected USB devices found." -ForegroundColor Red
        return
    }
    foreach ($u in $usb) {
        Write-Host "  Device Description: " -NoNewline -ForegroundColor Cyan; Write-Host $u.FriendlyName -ForegroundColor White
        Write-Host "  Hardware Class     : " -NoNewline -ForegroundColor Cyan; Write-Host $u.Class -ForegroundColor Gray
        Write-Host "  Operational Status : " -NoNewline -ForegroundColor Cyan; Write-Host $u.Status -ForegroundColor Green
        Write-Host "  --------------------------------------------------" -ForegroundColor Gray
    }
}

function Show-WifiPasswords {
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { $_.ToString().Split(":")[1].Trim() }
    if ($profiles.Count -eq 0) {
        Write-Host "  [!] No saved WiFi profiles found." -ForegroundColor Red
        return
    }
    Write-Host "   WiFi Network Name (SSID)       | Security Password Content" -ForegroundColor Cyan
    Write-Host "  ---------------------------------┼----------------------------------" -ForegroundColor Gray
    foreach ($p in $profiles) {
        $passInfo = netsh wlan show profile name="$p" key=clear | Select-String "Key Content"
        if ($passInfo) {
            $pass = $passInfo.ToString().Split(":")[1].Trim()
        } else {
            $pass = "[Open Network / No Password]"
        }
        $paddedProfile = $p.PadRight(31)
        Write-Host "  $paddedProfile | $pass" -ForegroundColor White
    }
}

function Show-Temperature {
    Write-Host "Attempting WMI thermal zone temperature sensor query..." -ForegroundColor Yellow
    $found = $false
    try {
        $temps = Get-CimInstance -Namespace root\wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
        foreach ($t in $temps) {
            $celsius = ($t.CurrentTemperature / 10) - 273.15
            Write-Host "  Thermal Zone ($($t.InstanceName)) : " -NoNewline -ForegroundColor Cyan
            Write-Host "$celsius °C" -ForegroundColor Green
            $found = $true
        }
    } catch {}
    if (-not $found) {
        Write-Host "  [Notice] Windows built-in WMI temperature sensors are disabled or unsupported by your BIOS." -ForegroundColor Yellow
        Write-Host "  This is typical on standard gaming and office motherboards to optimize CPU interrupts." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  For real-time hardware monitoring (CPU/GPU core temperatures), please download:" -ForegroundColor White
        Write-Host "    1. HWMonitor (https://www.cpuid.com/softwares/hwmonitor.html)" -ForegroundColor Cyan
        Write-Host "    2. HWiNFO (https://www.hwinfo.com)" -ForegroundColor Cyan
        Write-Host ""
        $open = Read-Host "Do you want to open HWMonitor official download page? (Y/N)"
        if ($open -like 'y*') { Start-Process "https://www.cpuid.com/softwares/hwmonitor.html" }
    }
}

function Create-RestorePoint {
    Write-Host "Configuring and enabling restore protection on C: Drive..." -ForegroundColor Yellow
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    Write-Host "Creating restore point..." -ForegroundColor Yellow
    try {
        Checkpoint-Computer -Description "BlueFIX IT Tool Kit Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "  [+] System Restore Point created successfully!" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Failed to create Restore Point." -ForegroundColor Red
        Write-Host "  Ensure you run this script as Admin." -ForegroundColor White
        Write-Host "  Note: Windows restricts restore point creation to once per 24-hour cycle by default." -ForegroundColor Gray
    }
}

function Export-FullDiagnostic {
    $report = "$env:USERPROFILE\Desktop\BlueFIX_Diagnostic_Report.txt"
    Write-Host "Compiling diagnostics... please wait (this takes a few seconds)..." -ForegroundColor Yellow
    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine("======================================================================") | Out-Null
    $sb.AppendLine("                  BLUEFIX IT TOOL KIT DIAGNOSTIC REPORT") | Out-Null
    $sb.AppendLine("                      Website: bluefix.in") | Out-Null
    $sb.AppendLine("                      Generated: $(Get-Date)") | Out-Null
    $sb.AppendLine("======================================================================") | Out-Null
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("1. SYSTEM HARDWARE & OS OVERVIEW") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_Bios -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $sb.AppendLine("  Computer Name      : $env:COMPUTERNAME") | Out-Null
    $sb.AppendLine("  System Manufacturer: $($cs.Manufacturer)") | Out-Null
    $sb.AppendLine("  System Model       : $($cs.Model)") | Out-Null
    $sb.AppendLine("  Motherboard        : $($bb.Manufacturer) $($bb.Product)") | Out-Null
    $sb.AppendLine("  CPU Model          : $($cpu.Name)") | Out-Null
    $sb.AppendLine("  RAM Capacity       : $([math]::Round($cs.TotalPhysicalMemory/1GB, 2)) GB") | Out-Null
    $sb.AppendLine("  Windows Edition    : $($os.Caption)") | Out-Null
    $sb.AppendLine("  Version/Build      : $($os.Version) (Build $($os.BuildNumber))") | Out-Null
    $sb.AppendLine("  BIOS Serial        : $($bios.SerialNumber)") | Out-Null
    $sb.AppendLine("  Boot Mode          : $(if (Test-Path 'HKLM:\System\CurrentControlSet\Control\SecureBoot\State') { 'UEFI' } else { 'Legacy' })") | Out-Null
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("2. DISK HEALTH & PARTITIONS") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if ($disks) {
        foreach ($d in $disks) {
            $sb.AppendLine("  Model: $($d.FriendlyName) | Serial: $($d.SerialNumber) | Type: $($d.MediaType) | Health: $($d.HealthStatus)") | Out-Null
        }
    }
    $vols = Get-Volume | Where-Object { $_.DriveLetter } -ErrorAction SilentlyContinue
    if ($vols) {
        foreach ($v in $vols) {
            $sb.AppendLine("  Drive $($v.DriveLetter): | FS: $($v.FileSystem) | Size: $([math]::Round($v.Size/1GB, 2)) GB | Free: $([math]::Round($v.SizeRemaining/1GB, 2)) GB") | Out-Null
        }
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("3. BATTERY DIAGNOSTICS") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $wear = [math]::Round(($battery.FullChargeCapacity / $battery.DesignCapacity) * 100, 2)
        $sb.AppendLine("  Battery Name    : $($battery.Name)") | Out-Null
        $sb.AppendLine("  Design Capacity : $($battery.DesignCapacity) mWh") | Out-Null
        $sb.AppendLine("  Full Charge Cap : $($battery.FullChargeCapacity) mWh") | Out-Null
        $sb.AppendLine("  Battery Health  : $wear%") | Out-Null
        $sb.AppendLine("  Charge Status   : $($battery.EstimatedChargeRemaining)% (Status Code: $($battery.BatteryStatus))") | Out-Null
    } else {
        $sb.AppendLine("  No battery detected (Desktop system).") | Out-Null
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("4. ACTIVE NETWORK CONFIGURATION") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } -ErrorAction SilentlyContinue
    if ($adapters) {
        foreach ($a in $adapters) {
            $sb.AppendLine("  Adapter: $($a.Name) | MAC: $($a.MacAddress) | Speed: $($a.LinkSpeed)") | Out-Null
        }
    }
    $ips = Get-NetIPAddress -InterfaceAddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } -ErrorAction SilentlyContinue
    if ($ips) {
        foreach ($ip in $ips) {
            $sb.AppendLine("  Local IPv4 Address: $($ip.IPAddress)") | Out-Null
        }
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("5. GRAPHICS PROCESSING UNITS (GPU)") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    if ($gpus) {
        foreach ($gpu in $gpus) {
            $sb.AppendLine("  GPU Model : $($gpu.Name) | Driver: $($gpu.DriverVersion) | VRAM: $([math]::Round($gpu.AdapterRAM / 1MB, 2)) MB") | Out-Null
        }
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("6. TOP 10 ACTIVE PROCESSES (BY MEMORY)") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $processes = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 -ErrorAction SilentlyContinue
    if ($processes) {
        foreach ($p in $processes) {
            $sb.AppendLine("  PID: $($p.Id.ToString().PadRight(6)) | Name: $($p.ProcessName.PadRight(25)) | RAM: $([math]::Round($p.WorkingSet64 / 1MB, 2)) MB") | Out-Null
        }
    }
    $sb.ToString() | Out-File -FilePath $report -Encoding utf8
    Write-Host "Diagnostic report compiled successfully!" -ForegroundColor Green
    Write-Host "Saved to: $report" -ForegroundColor Yellow
    Start-Process "notepad.exe" $report
}

# =========================================================================
# 5. INITIALIZATION & MAIN EXECUTION LOOP
# =========================================================================

Show-LoadingScreen
$overview = Get-SystemOverview

while ($true) {
    Show-MenuHeader $overview
    Show-MenuOptions
    Write-Host ""
    Write-Host "   Type " -NoNewline -ForegroundColor White
    Write-Host "[1-26]" -NoNewline -ForegroundColor Green
    Write-Host " to execute a tool, " -NoNewline -ForegroundColor White
    Write-Host "[R]" -NoNewline -ForegroundColor Green
    Write-Host " to Refresh Overview, or " -NoNewline -ForegroundColor White
    Write-Host "[Q]" -NoNewline -ForegroundColor Green
    Write-Host " to Exit." -ForegroundColor White
    Write-Host ""
    
    $opt = Read-Host "   >>> Enter selection"
    $opt = $opt.Trim()
    
    if ($opt -eq 'q' -or $opt -eq 'Q') {
        Clear-Host
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║                Thank you for using BlueFIX IT Tool Kit! - Website: bluefix.in          ║" -ForegroundColor Yellow
        Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Start-Sleep -Seconds 2
        break
    }
    
    if ($opt -eq 'r' -or $opt -eq 'R') {
        Show-LoadingScreen
        $overview = Get-SystemOverview
        continue
    }
    
    switch ($opt) {
        "1"  { Run-Tool "Full PC Information Viewer"          { Show-PCInfo } }
        "2"  { Run-Tool "Windows Version & Build Checker"     { Show-WinVersion } }
        "3"  { Run-Tool "BIOS Serial Number Viewer"           { Show-BiosSerial } }
        "4"  { Run-Tool "Installed Software List Exporter"     { Export-SoftwareList } }
        "5"  { Run-Tool "System Power On Date"                { Show-PowerOnDate } }
        "6"  { Run-Tool "Driver Information Viewer"            { Show-DriverInfo } }
        "7"  { Run-Tool "Network Information Tool"            { Show-NetworkInfo } }
        "8"  { Run-Tool "Battery Health Checker"              { Show-BatteryHealth } }
        "9"  { Run-Tool "TPM & Secure Boot Status Checker"    { Show-TpmSecureBoot } }
        "10" { Run-Tool "RAM & CPU Info Tool"                  { Show-RamCpuInfo } }
        "11" { Run-Tool "Disk Health SMART Checker"            { Show-DiskSmart } }
        "12" { Run-Tool "GPU Information Viewer"               { Show-GpuInfo } }
        "13" { Run-Tool "Windows Activation Status Checker"    { Show-WinActivation } }
        "14" { Run-Tool "Office Activation Status Checker"     { Show-OfficeActivation } }
        "15" { Run-Tool "Disk Partition Viewer"                { Show-Partitions } }
        "16" { Run-Tool "Running Process Viewer"               { Show-Processes } }
        "17" { Run-Tool "Startup Apps Viewer"                  { Show-StartupApps } }
        "18" { Run-Tool "Installed Windows Updates Viewer"     { Show-Updates } }
        "19" { Run-Tool "Internet Speed Quick Test"           { Test-InternetSpeed } }
        "20" { Run-Tool "System Uptime Checker"                { Show-Uptime } }
        "21" { Run-Tool "Windows Error Log Exporter"           { Export-ErrorLogs } }
        "22" { Run-Tool "USB Device Viewer"                    { Show-UsbDevices } }
        "23" { Run-Tool "WiFi Password Viewer"                 { Show-WifiPasswords } }
        "24" { Run-Tool "Temperature Monitoring Shortcut"      { Show-Temperature } }
        "25" { Run-Tool "Restore Point Creator"                { Create-RestorePoint } }
        "26" { Run-Tool "Export Full Diagnostic Report"        { Export-FullDiagnostic } }
        default {
            Write-Host "   [!] Invalid Selection. Please enter a valid number (1-26), R, or Q." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
