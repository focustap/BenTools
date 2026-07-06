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

if not exist "requirements.txt" (
    echo [BenTools Queue Ringer] requirements.txt was not found.
    echo.
    pause
    exit /b 1
)

py -3 -c "import cv2, numpy, PIL, pystray" >nul 2>nul
if errorlevel 1 (
    echo [BenTools Queue Ringer] Missing Python packages detected.
    echo [BenTools Queue Ringer] Trying to install requirements...
    py -3 -m pip install -r "requirements.txt"
    if errorlevel 1 (
        echo [BenTools Queue Ringer] Could not install the required Python packages.
        echo Try this manually:
        echo py -3 -m pip install -r requirements.txt
        echo.
        pause
        exit /b 1
    )
)

py -3 "queue_ringer.py"
if errorlevel 1 (
    echo [BenTools Queue Ringer] Queue Ringer did not start cleanly.
    echo.
    pause
    exit /b 1
)

exit /b 0
