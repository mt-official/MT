@echo off
setlocal enabledelayedexpansion
cls
title 🔒 CorelDRAW Activation

:: --- Configuration ---
set "BASE_PATH=C:\Program Files\Corel"
set "EXECUTABLE_NAME=CorelDRW.exe"
set "BLOCKING_RULE_PREFIX=BLOCK_Corel"
set "errorFlag=0"

:menu
cls
echo 🔹 CorelDRAW Activation Manager 🔹
echo.
echo 1: Connect CorelDRAW (32-bit + 64-bit)
echo 2: Delete CorelDRAW  (32-bit + 64-bit)
echo 0: Exit
echo.
set /p choice=Enter your choice (0-2): 

if "%choice%"=="1" goto block_all
if "%choice%"=="2" goto delete_all
if "%choice%"=="0" goto end

echo Invalid choice.
pause
goto menu

:: ------------------------------
:block_all
cls
echo 🔹 Working CorelDRAW (32-bit + 64-bit)...
echo.

for /D %%F in ("%BASE_PATH%\*") do (
    :: 64-bit
    if exist "%%F\Programs64" (
        set "exePath64=%%F\Programs64\%EXECUTABLE_NAME%"
        if exist "!exePath64!" (
            set "rule_name=%BLOCKING_RULE_PREFIX%_64_%%~nF"
            
            :: Delete existing rule if exists
            netsh advfirewall firewall show rule name="!rule_name!" >nul 2>&1
            if !errorlevel! == 0 (
                netsh advfirewall firewall delete rule name="!rule_name!" dir=in >nul 2>&1
                netsh advfirewall firewall delete rule name="!rule_name!" dir=out >nul 2>&1
            )

            :: Add block rules and check for errors
            netsh advfirewall firewall add rule name="!rule_name!" dir=out program="!exePath64!" action=block >nul 2>&1
            if !errorlevel! neq 0 (
                echo ❌ Failed to block 64-bit: !exePath64!
                set errorFlag=1
            )
            netsh advfirewall firewall add rule name="!rule_name!" dir=in program="!exePath64!" action=block >nul 2>&1
            if !errorlevel! neq 0 (
                echo ❌ Failed to block 64-bit: !exePath64!
                set errorFlag=1
            )
        )
    )

    :: 32-bit
    if exist "%%F\Programs" (
        set "exePath32=%%F\Programs\%EXECUTABLE_NAME%"
        if exist "!exePath32!" (
            set "rule_name=%BLOCKING_RULE_PREFIX%_32_%%~nF"
            
            :: Delete existing rule if exists
            netsh advfirewall firewall show rule name="!rule_name!" >nul 2>&1
            if !errorlevel! == 0 (
                netsh advfirewall firewall delete rule name="!rule_name!" dir=in >nul 2>&1
                netsh advfirewall firewall delete rule name="!rule_name!" dir=out >nul 2>&1
            )

            :: Add block rules and check for errors
            netsh advfirewall firewall add rule name="!rule_name!" dir=out program="!exePath32!" action=block >nul 2>&1
            if !errorlevel! neq 0 (
                echo ❌ Failed to block 32-bit: !exePath32!
                set errorFlag=1
            )
            netsh advfirewall firewall add rule name="!rule_name!" dir=in program="!exePath32!" action=block >nul 2>&1
            if !errorlevel! neq 0 (
                echo ❌ Failed to block 32-bit: !exePath32!
                set errorFlag=1
            )
        )
    )
)

echo.
echo 🔹 Connection Completed
if !errorFlag! == 0 (
    echo ✅ Success! Window will close in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto end
) else (
    echo ⚠ Some operations failed. Press any key to close.
    pause >nul
    goto end
)

:: ------------------------------
:delete_all
cls
echo 🔹 Deleting CorelDRAW (32-bit + 64-bit)...
echo.

for /D %%F in ("%BASE_PATH%\*") do (
    :: 64-bit
    set "rule_name=%BLOCKING_RULE_PREFIX%_64_%%~nF"
    netsh advfirewall firewall show rule name="!rule_name!" >nul 2>&1
    if !errorlevel! == 0 (
        netsh advfirewall firewall delete rule name="!rule_name!" dir=in >nul 2>&1
        netsh advfirewall firewall delete rule name="!rule_name!" dir=out >nul 2>&1
    ) else (
        echo ❌ OK
        set errorFlag=1
    )

    :: 32-bit
    set "rule_name=%BLOCKING_RULE_PREFIX%_32_%%~nF"
    netsh advfirewall firewall show rule name="!rule_name!" >nul 2>&1
    if !errorlevel! == 0 (
        netsh advfirewall firewall delete rule name="!rule_name!" dir=in >nul 2>&1
        netsh advfirewall firewall delete rule name="!rule_name!" dir=out >nul 2>&1
    ) else (
        echo ❌ OK
        set errorFlag=1
    )
)

echo.
echo 🔹 Deletion complete
if !errorFlag! == 0 (
    echo ✅ Success! Window will close in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto end
) else (
    echo ⚠ Some operations failed. Press any key to close.
    pause >nul
    goto end
)

:end
exit /b
