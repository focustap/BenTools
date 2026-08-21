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

for /f "usebackq delims=" %%P in (`py -3 -c "import sys; print(sys.executable)"`) do set "PYTHON_EXE=%%P"
if not defined PYTHON_EXE (
    echo [BenTools Queue Ringer] Could not locate the Python executable.
    echo.
    pause
    exit /b 1
)

for %%P in ("!PYTHON_EXE!") do set "PYTHONW_EXE=%%~dpPpythonw.exe"
if not exist "!PYTHONW_EXE!" (
    echo [BenTools Queue Ringer] pythonw.exe was not found next to the Python executable.
    echo Reinstall Python for Windows, including the standard library and launcher.
    echo.
    pause
    exit /b 1
)

start "" "!PYTHONW_EXE!" "%~dp0queue_ringer.py"
if errorlevel 1 (
    echo [BenTools Queue Ringer] Queue Ringer could not be started.
    echo.
    pause
    exit /b 1
)

exit /b 0
