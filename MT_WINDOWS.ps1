# Wrapper for HWID_Activation.cmd
$cmdUrl  = "https://raw.githubusercontent.com/mt-official/MT/refs/heads/main/MT_WINDOWS.cmd"
$cmdPath = "$env:TEMP\MT_WINDOWS.cmd"

Write-Host "`n📥 Downloading MT_WINDOWS.cmd ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cmdUrl -OutFile $cmdPath -UseBasicParsing

Write-Host "🚀 Running File..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/C `"$cmdPath`"" -NoNewWindow -Wait

Write-Host "`n✅ Done running MT_WINDOWS.cmd" -ForegroundColor Green

