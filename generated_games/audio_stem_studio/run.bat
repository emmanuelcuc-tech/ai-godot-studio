@echo off
setlocal
set GODOT="C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe"
set PROJECT=%~dp0
if not exist %GODOT% (
  echo Godot not found at %GODOT%
  echo Edit run.bat to point at your Godot 4 executable.
  exit /b 1
)
echo Launching Audio Stem Studio...
%GODOT% --path "%PROJECT%"
endlocal
