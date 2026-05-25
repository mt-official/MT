# 2>nul & cls & set "SCRIPT_PATH=%~f0" & powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0' -Encoding UTF8) -join [char]10)" & exit /b

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =========================================================================
# BlueFIX IT Tool Kit - Professional Demo Checker & Diagnostics
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
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm bluefix.in/demo | iex`"" -Verb RunAs
    }
    exit
}

# 2. CONSOLE SETUP
$Host.UI.RawUI.WindowTitle = "BlueFIX Demo Checker"
try {
    $size = $Host.UI.RawUI.WindowSize
    $size.Width = 120
    $size.Height = 45
    $Host.UI.RawUI.WindowSize = $size
    $buf = $Host.UI.RawUI.BufferSize
    $buf.Width = 120
    $buf.Height = 3000
    $Host.UI.RawUI.BufferSize = $buf
} catch {}

# 3. INITIALIZE NATIVE TYPES FOR DIAGNOSTICS & BENCHMARKING
if (-not ([System.Management.Automation.PSTypeName]"Win32.MciWrapper").Type) {
    $memberDefinition = @'
    [DllImport("winmm.dll", EntryPoint="mciSendStringA", CharSet=CharSet.Ansi)]
    public static extern int mciSendString(string lpstrCommand, System.Text.StringBuilder lpstrReturnString, int uReturnLength, IntPtr hwndCallback);

    [DllImport("winmm.dll")]
    public static extern int waveOutSetVolume(IntPtr hwo, uint dwVolume);

    [DllImport("winmm.dll")]
    public static extern int waveOutGetVolume(IntPtr hwo, ref uint dwVolume);
'@
    [void](Add-Type -MemberDefinition $memberDefinition -Name "MciWrapper" -Namespace "Win32")
}

if (-not ([System.Management.Automation.PSTypeName]"CpuBenchmark").Type) {
    $benchmarkCode = @'
    using System;
    using System.Threading.Tasks;
    using System.Diagnostics;

    public class CpuBenchmark {
        public static long RunSingleCore(int durationMs) {
            Stopwatch sw = Stopwatch.StartNew();
            long count = 0;
            while (sw.ElapsedMilliseconds < durationMs) {
                double x = Math.Sin(count) * Math.Cos(count);
                double y = Math.Sqrt(Math.Abs(x));
                count++;
            }
            return count;
        }

        public static long RunMultiCore(int durationMs) {
            int cores = Environment.ProcessorCount;
            long[] counts = new long[cores];
            Parallel.For(0, cores, i => {
                Stopwatch sw = Stopwatch.StartNew();
                long count = 0;
                while (sw.ElapsedMilliseconds < durationMs) {
                    double x = Math.Sin(count) * Math.Cos(count);
                    double y = Math.Sqrt(Math.Abs(x));
                    count++;
                }
                counts[i] = count;
            });
            long total = 0;
            foreach (long c in counts) {
                total += c;
            }
            return total;
        }
    }
'@
    [void](Add-Type -TypeDefinition $benchmarkCode)
}

# 4. HELPER FUNCTIONS
function Show-LoadingScreen {
    Clear-Host
    Write-Host "╔═════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    BLUEFIX DEMO CHECKER - INITIALIZING                  ║" -ForegroundColor Yellow
    Write-Host "╚═════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Gathering system timeline heuristics and hardware diagnostics..." -ForegroundColor White
    Write-Host "  Please wait a moment..." -ForegroundColor Gray
    Write-Host ""
}

function Get-SystemOverview {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_Bios -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
    
    $diskHealth = "Healthy"
    $diskDetails = "Unknown"
    try {
        $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        if ($disks) {
            $diskModels = @()
            foreach ($d in $disks) {
                if ($d.HealthStatus -ne 'Healthy') { $diskHealth = "Warning ($($d.HealthStatus))" }
                $diskModels += "$($d.FriendlyName) ($([math]::Round($d.Size/1GB))GB)"
            }
            $diskDetails = $diskModels -join " | "
        }
    } catch {}
    
    $powerOnHoursText = "Unknown"
    try {
        $reliability = Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        if ($reliability) {
            $hoursList = @()
            foreach ($r in $reliability) {
                $hoursList += "$($r.PowerOnHours) Hrs"
            }
            $powerOnHoursText = $hoursList -join " / "
        }
    } catch {}
    
    $batStatus = "No Battery (Desktop)"
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $charge = $battery.EstimatedChargeRemaining
            $status = if ($battery.BatteryStatus -eq 2) { "Charging" } else { "Discharging" }
            $wear = 100
            if ($battery.DesignCapacity -and $battery.FullChargeCapacity) {
                $wear = [math]::Round(($battery.FullChargeCapacity / $battery.DesignCapacity) * 100, 1)
            }
            $batStatus = "$wear% Health ($status, $charge%)"
        }
    } catch {}
    
    $firstPowerOn = "Unknown"
    try {
        $firstPowerOn = $os.InstallDate.ToString("dd-MMM-yyyy hh:mm:ss tt")
    } catch {}
    
    $earliestBoot = "Unknown"
    try {
        $oldestBoot = Get-WinEvent -FilterHashtable @{LogName='System'; Id=6009} -ErrorAction SilentlyContinue | Sort-Object TimeCreated | Select-Object -First 1
        if ($oldestBoot) {
            $earliestBoot = $oldestBoot.TimeCreated.ToString("dd-MMM-yyyy hh:mm:ss tt")
        }
    } catch {}
    
    $biosDateText = "Unknown"
    try {
        if ($bios.ReleaseDate) {
            $biosDateText = (Get-Date $bios.ReleaseDate).ToString("dd-MMM-yyyy")
        }
    } catch {}
    
    $bb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $boardDetails = if ($bb) { "$($bb.Manufacturer) $($bb.Product)" } else { "Unknown" }
    $biosSerial = if ($bios) { $bios.SerialNumber } else { "Unknown" }

    return [PSCustomObject]@{
        WINVER = $os.Caption
        BIOS_VER = $bios.SMBIOSBIOSVersion
        BIOS_DATE = $biosDateText
        CPU = $cpu.Name
        RAM = "$([math]::Round($cs.TotalPhysicalMemory/1GB)) GB"
        GPU = $gpu.Name
        DISK = "$diskDetails ($diskHealth)"
        DISKPWRON = $powerOnHoursText
        BAT = $batStatus
        INSTALLDATE = $firstPowerOn
        FIRSTBOOT = $earliestBoot
        MODEL = "$($cs.Manufacturer) $($cs.Model)"
        BOARD = $boardDetails
        SERIAL = $biosSerial
    }
}

function Show-MenuHeader {
    param($overview)
    Clear-Host
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host "                            BlueFIX Demo Checker - Hardware Diagnostics & Timeline                           " -NoNewline -ForegroundColor Yellow
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║" -NoNewline -ForegroundColor Cyan
    Write-Host "                                              Website: bluefix.in                                            " -NoNewline -ForegroundColor Gray
    Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║ LAPTOP HARDWARE CONFIGURATION                                                                            ║" -ForegroundColor Yellow
    Write-Host "  ╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("LAPTOP MODEL      = " + $overview.MODEL).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("LAPTOP SERIAL     = " + $overview.SERIAL).PadRight(104) -NoNewline -ForegroundColor Green; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("MOTHERBOARD       = " + $overview.BOARD).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("CPU MODEL         = " + $overview.CPU).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("RAM CAPACITY      = " + $overview.RAM).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("GPU MODEL         = " + $overview.GPU).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("STORAGE DEVICES   = " + $overview.DISK).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("BATTERY DIAGNOSE  = " + $overview.BAT).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║ PURCHASE & USAGE TIMELINE HEURISTICS (CRITICAL CHECK)                                                    ║" -ForegroundColor Yellow
    Write-Host "  ╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("BIOS BUILD DATE   = " + $overview.BIOS_DATE + " (BIOS Version: " + $overview.BIOS_VER + ")").PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("OS INSTALL DATE   = " + $overview.INSTALLDATE).PadRight(104) -NoNewline -ForegroundColor White; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("EARLIEST BOOT LOG = " + $overview.FIRSTBOOT).PadRight(104) -NoNewline -ForegroundColor Green; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ║  " -NoNewline -ForegroundColor Cyan; Write-Host ("DISK POWER-ON HRS = " + $overview.DISKPWRON).PadRight(104) -NoNewline -ForegroundColor Green; Write-Host "║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Show-MenuOptions {
    Write-Host "  ╔═════════════════════════════════════════════════╦═════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║ A. HARDWARE INTERACTIVE TESTS                   ║ B. DIAGNOSTIC REPORTS & INFRASTRUCTURE          ║" -ForegroundColor Yellow
    Write-Host "  ╠═════════════════════════════════════════════════╬═════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║ 1. Display Dead Pixel Checker (Solid Colors)    ║ 7. CPU Single/Multi-Core Performance Benchmark  ║" -ForegroundColor White
    Write-Host "  ║ 2. Touchscreen & Digitizer Grid Test            ║ 8. Device Manager Diagnostics (Check Drivers)   ║" -ForegroundColor White
    Write-Host "  ║ 3. Stereo Speaker Channel Separation Test       ║ 9. Export Full Demo Checker Diagnostic Report    ║" -ForegroundColor White
    Write-Host "  ║ 4. Microphone & Audio Playback Loop Tester      ║                                                 ║" -ForegroundColor White
    Write-Host "  ║ 5. Keyboard & Touchpad Click Interactive Log    ║                                                 ║" -ForegroundColor White
    Write-Host "  ║ 6. Camera Diagnostics & Live Video Feed Check   ║                                                 ║" -ForegroundColor White
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

# 5. DIAGNOSTIC MODULE DEFINITIONS

# [1] Display Color Test (Dead Pixel Checker)
function Show-DisplayColorCycle {
    Write-Host "  Launching Fullscreen Display dead pixel checker..." -ForegroundColor Green
    Write-Host "  Click left-mouse-button or press SPACE to cycle colors (Red, Green, Blue, White, Black)." -ForegroundColor Gray
    Write-Host "  Press ESC at any time to exit the tester." -ForegroundColor Gray
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $displayColors = @(
        [System.Drawing.Color]::Red,
        [System.Drawing.Color]::Lime,
        [System.Drawing.Color]::Blue,
        [System.Drawing.Color]::White,
        [System.Drawing.Color]::Black
    )
    $colorNames = @("RED", "GREEN", "BLUE", "WHITE", "BLACK")
    
    $form = New-Object Windows.Forms.Form
    $form.FormBorderStyle = "None"
    $form.WindowState = "Maximized"
    $form.BackColor = $displayColors[0]
    $form.TopMost = $true

    $lbl = New-Object Windows.Forms.Label
    $lbl.Text = "Display Test: RED`nClick or Press Space to Cycle. Press ESC to Exit."
    $lbl.ForeColor = [System.Drawing.Color]::DarkGray
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lbl.Dock = "Bottom"
    $lbl.TextAlign = "MiddleCenter"
    $lbl.Height = 60
    $form.Controls.Add($lbl)

    $form.Tag = [PSCustomObject]@{
        ColorIdx = 0
        DisplayColors = $displayColors
        ColorNames = $colorNames
    }

    $cycleColor = {
        $state = $form.Tag
        $state.ColorIdx++
        if ($state.ColorIdx -ge $state.DisplayColors.Count) {
            $form.Close()
        } else {
            $form.BackColor = $state.DisplayColors[$state.ColorIdx]
            $lbl.Text = "Display Test: $($state.ColorNames[$state.ColorIdx])`nClick or Press Space to Cycle. Press ESC to Exit."
            if ($state.ColorNames[$state.ColorIdx] -eq "WHITE") {
                $lbl.ForeColor = [System.Drawing.Color]::DarkGray
            } else {
                $lbl.ForeColor = [System.Drawing.Color]::Gray
            }
        }
    }.GetNewClosure()

    $form.Add_Click($cycleColor)
    $lbl.Add_Click($cycleColor)

    $form.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq "Escape") {
            $form.Close()
        } elseif ($e.KeyCode -eq "Space" -or $e.KeyCode -eq "Enter") {
            &$cycleColor
        }
    }.GetNewClosure())

    $form.ShowDialog()
}

# [2] Touchscreen / Digitizer Grid Test
function Show-TouchscreenGrid {
    Write-Host "  Launching Interactive Touchscreen & Digitizer Grid Test..." -ForegroundColor Green
    Write-Host "  Move your finger/mouse across the display to fill the grid blocks." -ForegroundColor Gray
    Write-Host "  Press ESC at any time to exit." -ForegroundColor Gray
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object Windows.Forms.Form
    $form.Text = "Digitizer and Touchscreen Diagnostic Grid - ESC to Exit"
    $form.Width = 900
    $form.Height = 700
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::Black
    $form.TopMost = $true

    $rows = 8
    $cols = 12
    $totalBlocks = $rows * $cols
    $blocksTouched = 0
    $grid = New-Object 'System.Boolean[,]' $rows, $cols

    $topPanel = New-Object Windows.Forms.Panel
    $topPanel.Height = 60
    $topPanel.Dock = "Top"
    $topPanel.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 25)

    $statusLabel = New-Object Windows.Forms.Label
    $statusLabel.Text = "Touch/Hover progress: 0% (0/$totalBlocks)"
    $statusLabel.ForeColor = [System.Drawing.Color]::Cyan
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $statusLabel.Dock = "Fill"
    $statusLabel.TextAlign = "MiddleCenter"
    $topPanel.Controls.Add($statusLabel)
    $form.Controls.Add($topPanel)

    $canvas = New-Object Windows.Forms.Panel
    $canvas.Dock = "Fill"
    $canvas.BackColor = [System.Drawing.Color]::Black
    $form.Controls.Add($canvas)

    $blockWidth = 0
    $blockHeight = 0
    $timer = New-Object Windows.Forms.Timer

    $canvas.Add_Paint({
        param($sender, $e)
        $g = $e.Graphics
        $w = $canvas.Width
        $h = $canvas.Height
        $blockWidth = $w / $cols
        $blockHeight = $h / $rows
        
        for ($r = 0; $r -lt $rows; $r++) {
            for ($c = 0; $c -lt $cols; $c++) {
                $x = $c * $blockWidth
                $y = $r * $blockHeight
                
                $color = if ($grid[$r, $c]) { [System.Drawing.Color]::LimeGreen } else { [System.Drawing.Color]::FromArgb(45, 45, 45) }
                $brush = New-Object System.Drawing.SolidBrush($color)
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 2)
                
                $g.FillRectangle($brush, $x, $y, $blockWidth, $blockHeight)
                $g.DrawRectangle($pen, $x, $y, $blockWidth, $blockHeight)
                
                $brush.Dispose()
                $pen.Dispose()
            }
        }
    }.GetNewClosure())

    $updateTouch = {
        param($mouseX, $mouseY)
        if ($blockWidth -le 0 -or $blockHeight -le 0) { return }
        $c = [math]::Floor($mouseX / $blockWidth)
        $r = [math]::Floor($mouseY / $blockHeight)
        
        if ($c -ge 0 -and $c -lt $cols -and $r -ge 0 -and $r -lt $rows) {
            if (-not $grid[$r, $c]) {
                $grid[$r, $c] = $true
                $blocksTouched++
                $percent = [math]::Round(($blocksTouched / $totalBlocks) * 100)
                $statusLabel.Text = "Touch/Hover progress: $percent% ($blocksTouched/$totalBlocks)"
                $canvas.Invalidate()
                
                if ($blocksTouched -eq $totalBlocks) {
                    $statusLabel.Text = "TEST PASSED! All blocks verified. Closing..."
                    $statusLabel.ForeColor = [System.Drawing.Color]::Lime
                    $canvas.Invalidate()
                    
                    $timer.Interval = 1200
                    $timer.Add_Tick({
                        $this.Stop()
                        $form.Close()
                    }.GetNewClosure())
                    $timer.Start()
                }
            }
        }
    }.GetNewClosure()

    $canvas.Add_MouseMove({
        param($sender, $e)
        &$updateTouch $e.X $e.Y
    }.GetNewClosure())

    $canvas.Add_MouseDown({
        param($sender, $e)
        &$updateTouch $e.X $e.Y
    }.GetNewClosure())

    $form.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq "Escape") {
            $form.Close()
        }
    }.GetNewClosure())

    $canvas.Add_Resize({
        $canvas.Invalidate()
    }.GetNewClosure())

    $form.ShowDialog()
}

# [3] Stereo Speaker Channel Separation Test
function Test-SpeakersStereo {
    Write-Host "  Starting Stereo Balance and Speaker Channel Test..." -ForegroundColor Yellow
    [uint32]$originalVol = 0
    # Retrieve current volume
    [void][Win32.MciWrapper]::waveOutGetVolume([IntPtr]::Zero, [ref]$originalVol)
    
    try {
        Add-Type -AssemblyName System.Speech -ErrorAction Stop
        $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
        
        Write-Host "  Testing LEFT Speaker..." -ForegroundColor Cyan
        [void][Win32.MciWrapper]::waveOutSetVolume([IntPtr]::Zero, [uint32]65535)
        [System.Console]::Beep(440, 450)
        $synth.Speak("Testing left speaker.")
        Start-Sleep -Milliseconds 600
        
        Write-Host "  Testing RIGHT Speaker..." -ForegroundColor Cyan
        [void][Win32.MciWrapper]::waveOutSetVolume([IntPtr]::Zero, [uint32]4294901760)
        [System.Console]::Beep(880, 450)
        $synth.Speak("Testing right speaker.")
        Start-Sleep -Milliseconds 600
        
        Write-Host "  Testing BOTH Speakers..." -ForegroundColor Cyan
        [void][Win32.MciWrapper]::waveOutSetVolume([IntPtr]::Zero, [uint32]::MaxValue)
        [System.Console]::Beep(660, 450)
        $synth.Speak("Testing both speakers completed.")
    } catch {
        # Fallback if speech synthesis is not working
        Write-Host "  Testing LEFT Speaker (Beep)..." -ForegroundColor Cyan
        [void][Win32.MciWrapper]::waveOutSetVolume([IntPtr]::Zero, [uint32]65535)
        [System.Console]::Beep(440, 800)
        Start-Sleep -Milliseconds 600
        
        Write-Host "  Testing RIGHT Speaker (Beep)..." -ForegroundColor Cyan
        [void][Win32.MciWrapper]::waveOutSetVolume([IntPtr]::Zero, [uint32]4294901760)
        [System.Console]::Beep(880, 800)
        Start-Sleep -Milliseconds 600
        
        Write-Host "  Testing BOTH Speakers (Beep)..." -ForegroundColor Cyan
        [void][Win32.MciWrapper]::waveOutSetVolume([IntPtr]::Zero, [uint32]::MaxValue)
        [System.Console]::Beep(660, 800)
    } finally {
        # Restore original system volume setting
        [void][Win32.MciWrapper]::waveOutSetVolume([IntPtr]::Zero, $originalVol)
    }
    
    Write-Host "  [OK] Speaker channel test completed." -ForegroundColor Green
    Write-Host "  Did you notice sound separation clearly on Left vs Right channels?" -ForegroundColor White
}

# [4] Microphone & Audio Playback Loop Tester
function Test-AudioRecordingLoop {
    $tempWav = "$env:TEMP\demo_mic_test.wav"
    if (Test-Path $tempWav) { Remove-Item $tempWav -Force }

    Write-Host "  Starting 5-second microphone recording loop..." -ForegroundColor Yellow
    Write-Host "  Please speak into your microphone clearly..." -ForegroundColor Cyan
    
    [void][Win32.MciWrapper]::mciSendString("open new type waveaudio alias recsound", $null, 0, [IntPtr]::Zero)
    [void][Win32.MciWrapper]::mciSendString("record recsound", $null, 0, [IntPtr]::Zero)

    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "  Recording active... $i seconds remaining" -ForegroundColor White
        Start-Sleep -Seconds 1
    }

    Write-Host "  Stopping recording and saving sample..." -ForegroundColor Yellow
    [void][Win32.MciWrapper]::mciSendString("save recsound `"$tempWav`"", $null, 0, [IntPtr]::Zero)
    [void][Win32.MciWrapper]::mciSendString("close recsound", $null, 0, [IntPtr]::Zero)

    if (Test-Path $tempWav) {
        Write-Host "  Playing back recorded audio..." -ForegroundColor Green
        [void][Win32.MciWrapper]::mciSendString("open `"$tempWav`" alias playsound", $null, 0, [IntPtr]::Zero)
        [void][Win32.MciWrapper]::mciSendString("play playsound wait", $null, 0, [IntPtr]::Zero)
        [void][Win32.MciWrapper]::mciSendString("close playsound", $null, 0, [IntPtr]::Zero)
        Remove-Item $tempWav -Force
        Write-Host "  [OK] Audio Loop test completed successfully." -ForegroundColor Green
    } else {
        Write-Host "  [!] Recording failed. Check if a microphone is connected and enabled." -ForegroundColor Red
    }
}

# [5] Keyboard & Touchpad Click Interactive Log
function Show-KeyboardMouseTest {
    Write-Host "  Launching Interactive Keyboard and Touchpad Tester..." -ForegroundColor Green
    Write-Host "  Press keys and click/move mouse/touchpad to test. Press ESC when done." -ForegroundColor Gray
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $form = New-Object Windows.Forms.Form
    $form.Text = "Interactive Keyboard & Touchpad Diagnostic"
    $form.Size = New-Object System.Drawing.Size(820, 560)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
    $form.KeyPreview = $true
    $form.TopMost = $true
    
    # Touchpad/Mouse test panels
    $mousePanel = New-Object Windows.Forms.Panel
    $mousePanel.Size = New-Object System.Drawing.Size(370, 90)
    $mousePanel.Location = New-Object System.Drawing.Point(20, 15)
    $mousePanel.BorderStyle = "FixedSingle"
    $mousePanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
    $form.Controls.Add($mousePanel)
    
    $leftClickLbl = New-Object Windows.Forms.Label
    $leftClickLbl.Text = "LEFT CLICK"
    $leftClickLbl.Size = New-Object System.Drawing.Size(184, 88)
    $leftClickLbl.Location = New-Object System.Drawing.Point(1, 1)
    $leftClickLbl.TextAlign = "MiddleCenter"
    $leftClickLbl.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $leftClickLbl.ForeColor = [System.Drawing.Color]::White
    $leftClickLbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $mousePanel.Controls.Add($leftClickLbl)
    
    $rightClickLbl = New-Object Windows.Forms.Label
    $rightClickLbl.Text = "RIGHT CLICK"
    $rightClickLbl.Size = New-Object System.Drawing.Size(184, 88)
    $rightClickLbl.Location = New-Object System.Drawing.Point(185, 1)
    $rightClickLbl.TextAlign = "MiddleCenter"
    $rightClickLbl.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $rightClickLbl.ForeColor = [System.Drawing.Color]::White
    $rightClickLbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $mousePanel.Controls.Add($rightClickLbl)
    
    $trackBox = New-Object Windows.Forms.Panel
    $trackBox.Size = New-Object System.Drawing.Size(390, 90)
    $trackBox.Location = New-Object System.Drawing.Point(400, 15)
    $trackBox.BorderStyle = "FixedSingle"
    $trackBox.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
    $form.Controls.Add($trackBox)
    
    $trackLbl = New-Object Windows.Forms.Label
    $trackLbl.Text = "TOUCHPAD / MOUSE TRACK AREA`n(Move finger here to test touchpad)"
    $trackLbl.Size = New-Object System.Drawing.Size(388, 88)
    $trackLbl.Location = New-Object System.Drawing.Point(1, 1)
    $trackLbl.TextAlign = "MiddleCenter"
    $trackLbl.ForeColor = [System.Drawing.Color]::LightGray
    $trackLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $trackBox.Controls.Add($trackLbl)
    
    $pressedLabel = New-Object Windows.Forms.Label
    $pressedLabel.Text = "Press keys to test. Click 'EXIT TEST' or the [X] to finish."
    $pressedLabel.Size = New-Object System.Drawing.Size(500, 30)
    $pressedLabel.Location = New-Object System.Drawing.Point(150, 115)
    $pressedLabel.ForeColor = [System.Drawing.Color]::Yellow
    $pressedLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $pressedLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($pressedLabel)

    $exitBtn = New-Object Windows.Forms.Button
    $exitBtn.Text = "EXIT TEST"
    $exitBtn.Size = New-Object System.Drawing.Size(120, 30)
    $exitBtn.Location = New-Object System.Drawing.Point(670, 115)
    $exitBtn.BackColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
    $exitBtn.ForeColor = [System.Drawing.Color]::White
    $exitBtn.FlatStyle = "Flat"
    $exitBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $exitBtn.Add_Click({
        $form.Close()
    })
    $form.Controls.Add($exitBtn)
    
    $previewKeyDown = {
        param($sender, $e)
        if ($e.KeyCode -in @('Tab', 'Left', 'Right', 'Up', 'Down', 'Return', 'Escape', 'Space')) {
            $e.IsInputKey = $true
        }
    }.GetNewClosure()
    $form.Add_PreviewKeyDown($previewKeyDown)
    $exitBtn.Add_PreviewKeyDown($previewKeyDown)
    
    $rowsData = @(
        # Row 0
        @( @("Esc", "Escape", 45), @("F1", "F1", 45), @("F2", "F2", 45), @("F3", "F3", 45), @("F4", "F4", 45), @("F5", "F5", 45), @("F6", "F6", 45), @("F7", "F7", 45), @("F8", "F8", 45), @("F9", "F9", 45), @("F10", "F10", 45), @("F11", "F11", 45), @("F12", "F12", 45) ),
        # Row 1
        @( @("~", "Oemtilde", 45), @("1", "D1", 45), @("2", "D2", 45), @("3", "D3", 45), @("4", "D4", 45), @("5", "D5", 45), @("6", "D6", 45), @("7", "D7", 45), @("8", "D8", 45), @("9", "D9", 45), @("0", "D0", 45), @("-", "OemMinus", 45), @("=", "Oemplus", 45), @("Backspace", "Back", 90) ),
        # Row 2
        @( @("Tab", "Tab", 65), @("Q", "Q", 45), @("W", "W", 45), @("E", "E", 45), @("R", "R", 45), @("T", "T", 45), @("Y", "Y", 45), @("U", "U", 45), @("I", "I", 45), @("O", "O", 45), @("P", "P", 45), @("[", "OemOpenBrackets", 45), @("]", "Oem6", 45), @("\", "Oem5", 55) ),
        # Row 3
        @( @("Caps", "Capital", 75), @("A", "A", 45), @("S", "S", 45), @("D", "D", 45), @("F", "F", 45), @("G", "G", 45), @("H", "H", 45), @("J", "J", 45), @("K", "K", 45), @("L", "L", 45), @(";", "Oem1", 45), @("'", "Oem7", 45), @("Enter", "Return", 95) ),
        # Row 4
        @( @("LShift", "ShiftKey", 95), @("Z", "Z", 45), @("X", "X", 45), @("C", "C", 45), @("V", "V", 45), @("B", "B", 45), @("N", "N", 45), @("M", "M", 45), @(",", "Oemcomma", 45), @(".", "OemPeriod", 45), @("/", "OemQuestion", 45), @("RShift", "ShiftKey", 115) ),
        # Row 5
        @( @("LCtrl", "ControlKey", 70), @("Win", "LWin", 45), @("LAlt", "Menu", 45), @("Space", "Space", 255), @("RAlt", "Menu", 45), @("RCtrl", "ControlKey", 70), @("←", "Left", 45), @("↑", "Up", 45), @("↓", "Down", 45), @("→", "Right", 45) )
    )
    
    $keyControls = @{}
    $yOffset = 160
    
    for ($rIdx = 0; $rIdx -lt $rowsData.Count; $rIdx++) {
        $row = $rowsData[$rIdx]
        $xOffset = 20
        foreach ($k in $row) {
            $name = $k[0]
            $code = $k[1]
            $width = $k[2]
            
            $lbl = New-Object Windows.Forms.Label
            $lbl.Text = $name
            $lbl.Size = New-Object System.Drawing.Size($width, 38)
            $lbl.Location = New-Object System.Drawing.Point($xOffset, $yOffset)
            $lbl.TextAlign = "MiddleCenter"
            $lbl.BorderStyle = "FixedSingle"
            $lbl.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
            $lbl.ForeColor = [System.Drawing.Color]::White
            $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
            
            $form.Controls.Add($lbl)
            
            if (-not $keyControls.ContainsKey($code)) {
                $keyControls[$code] = New-Object System.Collections.ArrayList
            }
            [void]$keyControls[$code].Add($lbl)
            
            $xOffset += $width + 6
        }
        $yOffset += 44
    }
    
    $registerClick = {
        param($button)
        if ($button -eq "Left") {
            $leftClickLbl.BackColor = [System.Drawing.Color]::LimeGreen
            $leftClickLbl.ForeColor = [System.Drawing.Color]::Black
        } elseif ($button -eq "Right") {
            $rightClickLbl.BackColor = [System.Drawing.Color]::LimeGreen
            $rightClickLbl.ForeColor = [System.Drawing.Color]::Black
        }
    }.GetNewClosure()
    
    $trackLbl.Add_MouseMove({
        param($sender, $e)
        $trackLbl.BackColor = [System.Drawing.Color]::FromArgb(10, 40, 90)
        $trackLbl.ForeColor = [System.Drawing.Color]::Lime
        $trackLbl.Text = "Touchpad Movement: X=$($e.X), Y=$($e.Y)"
    }.GetNewClosure())
    
    $trackLbl.Add_MouseDown({ param($sender, $e) &$registerClick $e.Button.ToString() }.GetNewClosure())
    $form.Add_MouseDown({ param($sender, $e) &$registerClick $e.Button.ToString() }.GetNewClosure())
    $mousePanel.Add_MouseDown({ param($sender, $e) &$registerClick $e.Button.ToString() }.GetNewClosure())
    $leftClickLbl.Add_MouseDown({ param($sender, $e) &$registerClick $e.Button.ToString() }.GetNewClosure())
    $rightClickLbl.Add_MouseDown({ param($sender, $e) &$registerClick $e.Button.ToString() }.GetNewClosure())
    
    $form.Add_KeyDown({
        param($sender, $e)
        $e.Handled = $true
        $e.SuppressKeyPress = $true
        $codeStr = $e.KeyCode.ToString()
        $pressedLabel.Text = "Last Key Pressed: $codeStr (Code: $($e.KeyValue))"
        
        if ($keyControls.ContainsKey($codeStr)) {
            foreach ($ctrl in $keyControls[$codeStr]) {
                $ctrl.BackColor = [System.Drawing.Color]::LimeGreen
                $ctrl.ForeColor = [System.Drawing.Color]::Black
            }
        }
    }.GetNewClosure())
    
    $form.ShowDialog()
    
    Write-Host ""
    Write-Host "  Press ENTER for working, or SPACE for not working..." -ForegroundColor Yellow
    
    while ($true) {
        $keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($keyInfo.VirtualKeyCode -eq 13) {
            Write-Host "  [RESULT] Keyboard and Touchpad marked as Working." -ForegroundColor Green
            break
        } elseif ($keyInfo.VirtualKeyCode -eq 32) {
            Write-Host "  [RESULT] Keyboard or Touchpad marked as Not Working." -ForegroundColor Red
            break
        }
    }
}

# [6] Camera Diagnostic and Launch
function Show-CameraDiagnostics {
    Write-Host "  Scanning for connected Camera Devices..." -ForegroundColor Yellow
    $cameras = Get-PnpDevice -Class Camera, Image -ErrorAction SilentlyContinue
    if ($cameras) {
        Write-Host "  Found $($cameras.Count) camera/imaging hardware device(s):" -ForegroundColor Green
        Write-Host ""
        foreach ($c in $cameras) {
            $statusColor = if ($c.Status -eq "OK") { "Green" } else { "Red" }
            Write-Host "    Device Name   : $($c.FriendlyName)" -ForegroundColor White
            Write-Host "    Status        : " -NoNewline -ForegroundColor Cyan; Write-Host $c.Status -ForegroundColor $statusColor
            Write-Host "    Manufacturer  : $($c.Manufacturer)" -ForegroundColor Gray
            Write-Host "    --------------------------------------------------" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "  Launching Windows Camera app to test live video capture stream..." -ForegroundColor Green
        Start-Process "microsoft.windows.camera:"
    } else {
        Write-Host "  [!] No Camera hardware interface found in Device Manager." -ForegroundColor Red
        Write-Host "  If the laptop has a physical shutter or Fn-key toggle, please enable it first." -ForegroundColor Yellow
    }
}

# [7] CPU Single-Core & Multi-Core Performance Test
function Show-CpuBenchmark {
    Write-Host "  [CPU Single-Core & Multi-Core Performance Test]" -ForegroundColor Yellow
    Write-Host "  This test will put the CPU under full load for a few seconds to run complex math operations." -ForegroundColor Gray
    Write-Host "  Testing... please keep the laptop still and connected to power." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "  Running Single-Core Benchmark (2 seconds)..." -NoNewline -ForegroundColor White
    $singleOps = [CpuBenchmark]::RunSingleCore(2000)
    Write-Host " Completed." -ForegroundColor Green
    
    Write-Host "  Running Multi-Core Benchmark (2 seconds)..." -NoNewline -ForegroundColor White
    $multiOps = [CpuBenchmark]::RunMultiCore(2000)
    Write-Host " Completed." -ForegroundColor Green
    
    # Calculate scores normalized
    $singleScore = [math]::Round($singleOps / 20000)
    $multiScore = [math]::Round($multiOps / 20000)
    $ratio = [math]::Round($multiOps / $singleOps, 2)
    
    Write-Host ""
    Write-Host "  BENCHMARK RESULTS:" -ForegroundColor Yellow
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host "  Single-Core Score : " -NoNewline -ForegroundColor Cyan; Write-Host "$singleScore pts" -ForegroundColor White
    Write-Host "  Multi-Core Score  : " -NoNewline -ForegroundColor Cyan; Write-Host "$multiScore pts" -ForegroundColor White
    Write-Host "  Multi-Core Ratio  : " -NoNewline -ForegroundColor Cyan; Write-Host "$($ratio)x speedup" -ForegroundColor Green
    Write-Host "  Logical Cores     : " -NoNewline -ForegroundColor Cyan; Write-Host $env:NUMBER_OF_PROCESSORS -ForegroundColor White
    Write-Host "  ==================================================" -ForegroundColor Cyan
}

# [8] Device Manager Status
function Show-DeviceManagerCheck {
    Write-Host "  Scanning Device Manager for warning or missing driver flags..." -ForegroundColor Yellow
    $badDevices = Get-PnpDevice | Where-Object { $_.Status -ne 'OK' -and $_.Status -ne 'Unknown' } -ErrorAction SilentlyContinue
    if ($badDevices) {
        Write-Host "  [!] Found $($badDevices.Count) devices with error/warning codes:" -ForegroundColor Red
        Write-Host ""
        foreach ($d in $badDevices) {
            Write-Host "    - Device: " -NoNewline -ForegroundColor White; Write-Host $d.FriendlyName -ForegroundColor Yellow
            Write-Host "      Status: $($d.Status) | Class: $($d.Class)" -ForegroundColor Gray
            Write-Host "      InstanceId: $($d.InstanceId)" -ForegroundColor DarkGray
            Write-Host "      --------------------------------------------------" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [OK] Device Manager is clean. All active devices reported OK." -ForegroundColor Green
    }
}

# [9] Export Diagnostic Report
function Export-FullDemoReport {
    $report = "$env:USERPROFILE\Desktop\Demo_Checker_Diagnostic_Report.txt"
    Write-Host "Compiling Demo Checker diagnostic report... please wait..." -ForegroundColor Yellow
    $overview = Get-SystemOverview
    
    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine("======================================================================") | Out-Null
    $sb.AppendLine("                  BLUEFIX DEMO CHECKER DIAGNOSTIC REPORT") | Out-Null
    $sb.AppendLine("                      Website: bluefix.in") | Out-Null
    $sb.AppendLine("                      Generated: $(Get-Date)") | Out-Null
    $sb.AppendLine("======================================================================") | Out-Null
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("1. SYSTEM HARDWARE & BIOS CONFIGURATION") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $sb.AppendLine("  Laptop Model       : $($overview.MODEL)") | Out-Null
    $sb.AppendLine("  Laptop Serial      : $($overview.SERIAL)") | Out-Null
    $sb.AppendLine("  Motherboard        : $($overview.BOARD)") | Out-Null
    $sb.AppendLine("  CPU Model          : $($overview.CPU)") | Out-Null
    $sb.AppendLine("  RAM Capacity       : $($overview.RAM)") | Out-Null
    $sb.AppendLine("  GPU Model          : $($overview.GPU)") | Out-Null
    $sb.AppendLine("  BIOS Version       : $($overview.BIOS_VER)") | Out-Null
    $sb.AppendLine("  BIOS Date          : $($overview.BIOS_DATE)") | Out-Null
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("2. PURCHASE & USAGE TIMELINE HEURISTICS") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $sb.AppendLine("  BIOS Manufacture Date         : $($overview.BIOS_DATE)") | Out-Null
    $sb.AppendLine("  Windows Installation Date     : $($overview.INSTALLDATE)") | Out-Null
    $sb.AppendLine("  Earliest Recorded Windows Boot : $($overview.FIRSTBOOT)") | Out-Null
    $sb.AppendLine("  Hard Drive Power-On Hours     : $($overview.DISKPWRON)") | Out-Null
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("3. STORAGE DEVICES STATUS") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if ($disks) {
        foreach ($d in $disks) {
            $sb.AppendLine("  Model: $($d.FriendlyName) | Serial: $($d.SerialNumber) | Type: $($d.MediaType) | Health: $($d.HealthStatus)") | Out-Null
        }
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("4. BATTERY STATUS") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $sb.AppendLine("  Battery Diagnosis  : $($overview.BAT)") | Out-Null
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $sb.AppendLine("  Battery Name       : $($battery.Name)") | Out-Null
        $sb.AppendLine("  Design Capacity    : $($battery.DesignCapacity) mWh") | Out-Null
        $sb.AppendLine("  Full Charge Cap    : $($battery.FullChargeCapacity) mWh") | Out-Null
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("5. DEVICE MANAGER ERRORS / WARNINGS") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    $badDevices = Get-PnpDevice | Where-Object { $_.Status -ne 'OK' -and $_.Status -ne 'Unknown' } -ErrorAction SilentlyContinue
    if ($badDevices) {
        foreach ($d in $badDevices) {
            $sb.AppendLine("  Device: $($d.FriendlyName) | Class: $($d.Class) | Status: $($d.Status)") | Out-Null
        }
    } else {
        $sb.AppendLine("  No errors or warnings found. All devices functioning normally.") | Out-Null
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("6. PROCESSOR PERFORMANCE BENCHMARK") | Out-Null
    $sb.AppendLine("----------------------------------------------------------------------") | Out-Null
    try {
        $singleOps = [CpuBenchmark]::RunSingleCore(1000)
        $multiOps = [CpuBenchmark]::RunMultiCore(1000)
        $singleScore = [math]::Round($singleOps / 10000)
        $multiScore = [math]::Round($multiOps / 10000)
        $ratio = [math]::Round($multiOps / $singleOps, 2)
        $sb.AppendLine("  Single-Core Score : $singleScore pts") | Out-Null
        $sb.AppendLine("  Multi-Core Score  : $multiScore pts") | Out-Null
        $sb.AppendLine("  Multi-Core Ratio  : $($ratio)x speedup") | Out-Null
    } catch {
        $sb.AppendLine("  Benchmark failed to run during report generation.") | Out-Null
    }
    
    $sb.ToString() | Out-File -FilePath $report -Encoding utf8
    Write-Host "Demo Checker diagnostic report compiled successfully!" -ForegroundColor Green
    Write-Host "Saved to: $report" -ForegroundColor Yellow
    Start-Process "notepad.exe" $report
}

# =========================================================================
# 6. INITIALIZATION & MAIN EXECUTION LOOP
# =========================================================================

Show-LoadingScreen
$overview = Get-SystemOverview

while ($true) {
    Show-MenuHeader $overview
    Show-MenuOptions
    Write-Host ""
    Write-Host "   Type " -NoNewline -ForegroundColor White
    Write-Host "[1-9]" -NoNewline -ForegroundColor Green
    Write-Host " to execute a test module, " -NoNewline -ForegroundColor White
    Write-Host "[R]" -NoNewline -ForegroundColor Green
    Write-Host " to Refresh heuristics, or " -NoNewline -ForegroundColor White
    Write-Host "[Q]" -NoNewline -ForegroundColor Green
    Write-Host " to Exit." -ForegroundColor White
    Write-Host ""
    
    $opt = Read-Host "   >>> Enter selection"
    $opt = $opt.Trim()
    
    if ($opt -eq 'q' -or $opt -eq 'Q') {
        Clear-Host
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║                 Thank you for using BlueFIX Demo Checker! - Website: bluefix.in      ║" -ForegroundColor Yellow
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
        "1"  { Run-Tool "Display Dead Pixel Checker"          { Show-DisplayColorCycle } }
        "2"  { Run-Tool "Touchscreen & Digitizer Grid Test"   { Show-TouchscreenGrid } }
        "3"  { Run-Tool "Speaker Channel Stereo Audio Test"   { Test-SpeakersStereo } }
        "4"  { Run-Tool "Microphone & Speaker Record-Loop"    { Test-AudioRecordingLoop } }
        "5"  { Run-Tool "Keyboard & Touchpad Key Logger"      { Show-KeyboardMouseTest } }
        "6"  { Run-Tool "Camera Diagnostics & Feed Test"      { Show-CameraDiagnostics } }
        "7"  { Run-Tool "CPU Performance Benchmark"           { Show-CpuBenchmark } }
        "8"  { Run-Tool "Device Manager Warnings & Drivers"   { Show-DeviceManagerCheck } }
        "9"  { Run-Tool "Export Demo Checker Diagnostic Report"{ Export-FullDemoReport } }
        default {
            Write-Host "   [!] Invalid Selection. Please enter a valid number (1-9), R, or Q." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
