# Wrapper for HWID_Activation.cmd
$cmdUrl  = "https://raw.githubusercontent.com/mt-official/MT/main/HWID_Activation.cmd"
$cmdPath = "$env:TEMP\HWID_Activation.cmd"

Write-Host "`n📥 Downloading HWID_Activation.cmd ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cmdUrl -OutFile $cmdPath -UseBasicParsing

Write-Host "🚀 Running script..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/C `"$cmdPath`"" -NoNewWindow -Wait

Write-Host "`n✅ Done running HWID_Activation.cmd" -ForegroundColor Green
