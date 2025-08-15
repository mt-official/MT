# Wrapper for HWID_Activation.cmd
$cmdUrl  = "https://raw.githubusercontent.com/mt-official/MT/refs/heads/main/MT_office.cmd"
$cmdPath = "$env:TEMP\MT_office.cmd"

Write-Host "`n📥 Downloading MT_Office.cmd ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cmdUrl -OutFile $cmdPath -UseBasicParsing

Write-Host "🚀 Running script..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/C `"$cmdPath`"" -NoNewWindow -Wait

Write-Host "`n✅ Done running MT_OFFICE.cmd" -ForegroundColor Green


