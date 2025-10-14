# Wrapper for CoralDraw
$cmdUrl  = "https://raw.githubusercontent.com/mt-official/MT/refs/heads/main/coral.bat"
$cmdPath = "$env:TEMP\mt_coral.cmd"

Write-Host "`n📥 Downloading Coral ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cmdUrl -OutFile $cmdPath -UseBasicParsing

Write-Host "🚀 Running script..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/C `"$cmdPath`"" -NoNewWindow -Wait

Write-Host "`n✅ Done running Coral" -ForegroundColor Green
