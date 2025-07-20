# Wrapper for HWID_Activation.cmd
$cmdUrl  = "https://raw.githubusercontent.com/mt-official/MT/refs/heads/main/Ohook_Activation_AIO_office.bat"
$cmdPath = "$env:TEMP\Ohook_Activation_AIO_office.bat"

Write-Host "`n📥 Downloading Ohook_Activation_AIO_office.bat ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $cmdUrl -OutFile $cmdPath -UseBasicParsing

Write-Host "🚀 Running script..." -ForegroundColor Yellow
Start-Process "cmd.exe" -ArgumentList "/C `"$cmdPath`"" -NoNewWindow -Wait

Write-Host "`n✅ Done running Ohook_Activation_AIO_office.bat" -ForegroundColor Green
