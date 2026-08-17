@echo off
setlocal EnableExtensions
rem Open the updated Chrome Cannon Glass 1.0.0 final Codea package.
set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

set "PKG=%ROOT%\codea\dist\ChromeCannonGlass.codea"
set "ZIP=%ROOT%\codea\dist\ChromeCannonGlass-1.0.0-final.codea.zip"
set "ALT=%ROOT%\codea\dist\ChromeCannonGlass.codea.zip"

if exist "%PKG%\Main.lua" (
  explorer "%PKG%"
  exit /b 0
)
if exist "%ZIP%" (
  explorer /select,"%ZIP%"
  exit /b 0
)
if exist "%ALT%" (
  explorer /select,"%ALT%"
  exit /b 0
)

echo Chrome Cannon Glass 1.0.0 final package not found under codea\dist
pause
exit /b 1
