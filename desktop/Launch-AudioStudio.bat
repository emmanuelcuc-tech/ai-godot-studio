@echo off
setlocal EnableExtensions
rem Launch desktop Audio Studio (mixer, IN/OUT, describe / record / hum).
set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

set "GODOT="
if exist "%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe" set "GODOT=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe"
if not defined GODOT if exist "C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe" set "GODOT=C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe"
if not defined GODOT for %%G in ("%USERPROFILE%\Downloads\Godot_v4*.exe") do (
  echo %%~nxG | findstr /i "console" >nul || set "GODOT=%%~fG"
)

if not defined GODOT (
  echo Godot 4 exe not found. Put Godot_v4.7.1-stable_win64.exe in Downloads.
  pause
  exit /b 1
)

if not exist "%ROOT%\project.godot" (
  echo project.godot missing at "%ROOT%"
  pause
  exit /b 1
)

start "" "%GODOT%" --path "%ROOT%" res://scenes/audio_studio.tscn
endlocal
