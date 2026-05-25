# Wrapper for CoralDraw
$cmdUrl  = "https://raw.githubusercontent.com/mt-official/MT/refs/heads/main/CheckActivationStatus.cmd"
$cmdPath = "$env:TEMP\checkactivationstatus.cmd"

Write-Host "`n📥 Downloading BlueFix Check Activation Status ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cmdUrl -OutFile $cmdPath -UseBasicParsing

Write-Host "🚀 Running script..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/C `"$cmdPath`"" -NoNewWindow -Wait

Write-Host "`n✅ Done running Check Activation Status" -ForegroundColor Green