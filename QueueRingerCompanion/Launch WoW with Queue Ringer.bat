@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

if not exist "queue_ringer.py" (
    echo [BenTools Queue Ringer] queue_ringer.py was not found in:
    echo !cd!
    echo.
    pause
    exit /b 1
)

where py >nul 2>nul
if errorlevel 1 (
    echo [BenTools Queue Ringer] Python launcher "py" was not found.
    echo Install Python for Windows and make sure the Python launcher is available.
    echo.
    pause
    exit /b 1
)

start "" "%~dp0Start Queue Ringer.bat"
timeout /t 1 /nobreak >nul

py -3 "queue_ringer.py" --launch-wow
if errorlevel 1 (
    echo [BenTools Queue Ringer] Could not launch World of Warcraft or Battle.net.
    echo Configure the WoW / Battle.net path in the Queue Ringer companion if auto-detection does not find it.
    echo.
    pause
    exit /b 1
)

exit /b 0
