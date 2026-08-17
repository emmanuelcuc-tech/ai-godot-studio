@echo off
setlocal
set "GODOT=C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe"
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"
set "OUT=%PROJECT%\build\AudioStemStudio.exe"
if not exist "%GODOT%" (
  echo Godot not found at %GODOT%
  exit /b 1
)
mkdir "%PROJECT%\build" 2>nul
echo Exporting Windows Desktop release to:
echo   %OUT%
"%GODOT%" --headless --path "%PROJECT%" --export-release "Windows Desktop" "%OUT%"
if errorlevel 1 (
  echo.
  echo EXPORT FAILED - export templates may be missing.
  echo Install from Godot: Editor -^> Manage Export Templates
  echo Or download templates matching 4.7.1-stable.
  echo You can still run with run.bat
  exit /b 1
)
echo.
echo Build OK: %OUT%
endlocal
