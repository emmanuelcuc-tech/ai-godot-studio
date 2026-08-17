# Remake Windows desktop shortcuts to this updated checkout.
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File desktop/Make-DesktopShortcut.ps1

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Resolve-Path (Join-Path $here "..")).Path
$desktop = [Environment]::GetFolderPath("Desktop")
$downloads = Join-Path $env:USERPROFILE "Downloads"

if (-not (Test-Path (Join-Path $repo "project.godot"))) {
    throw "project.godot not found at $repo"
}

$godot = @(
    (Join-Path $downloads "Godot_v4.7.1-stable_win64.exe"),
    "C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $godot -and (Test-Path $downloads)) {
    $godot = Get-ChildItem -Path $downloads -Filter "Godot_v4*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "console" } |
        Select-Object -First 1 -ExpandProperty FullName
}

$stale = @(
    "AI Godot Studio.lnk",
    "Audio Studio.lnk",
    "Chrome Cannon Glass.lnk",
    "ChromeCannonGlass.lnk",
    "ai-godot-studio.lnk",
    "Launch-AIGodotStudio.bat",
    "Launch-AudioStudio.bat",
    "Open-ChromeCannonGlass.bat"
)
foreach ($name in $stale) {
    $p = Join-Path $desktop $name
    if (Test-Path $p) { Remove-Item $p -Force }
}

Copy-Item (Join-Path $here "Launch-AIGodotStudio.bat") (Join-Path $desktop "Launch-AIGodotStudio.bat") -Force
Copy-Item (Join-Path $here "Launch-AudioStudio.bat") (Join-Path $desktop "Launch-AudioStudio.bat") -Force
Copy-Item (Join-Path $here "Open-ChromeCannonGlass.bat") (Join-Path $desktop "Open-ChromeCannonGlass.bat") -Force
Copy-Item (Join-Path $here "Chrome Cannon Glass 1.0.0 final.url") (Join-Path $desktop "Chrome Cannon Glass 1.0.0 final.url") -Force

$w = New-Object -ComObject WScript.Shell

if ($godot) {
    $sc = $w.CreateShortcut((Join-Path $desktop "AI Godot Studio.lnk"))
    $sc.TargetPath = $godot
    $sc.Arguments = "--path `"$repo`""
    $sc.WorkingDirectory = $repo
    $sc.WindowStyle = 1
    $sc.Description = "AI Godot Studio 2.0 — Create + desktop Audio Studio"
    $sc.IconLocation = "$godot,0"
    $sc.Save()

    $scA = $w.CreateShortcut((Join-Path $desktop "Audio Studio.lnk"))
    $scA.TargetPath = $godot
    $scA.Arguments = "--path `"$repo`" res://scenes/audio_studio.tscn"
    $scA.WorkingDirectory = $repo
    $scA.WindowStyle = 1
    $scA.Description = "Desktop Audio Studio 1.0.0 final — mixer, IN/OUT, describe / record / hum"
    $scA.IconLocation = "$godot,0"
    $scA.Save()
}

$pkg = Join-Path $repo "codea\dist\ChromeCannonGlass.codea"
$sc2 = $w.CreateShortcut((Join-Path $desktop "Chrome Cannon Glass.lnk"))
if (Test-Path $pkg) {
    $sc2.TargetPath = "explorer.exe"
    $sc2.Arguments = "`"$pkg`""
} else {
    $sc2.TargetPath = Join-Path $desktop "Open-ChromeCannonGlass.bat"
}
$sc2.WorkingDirectory = Join-Path $repo "codea\dist"
$sc2.WindowStyle = 1
$sc2.Description = "Chrome Cannon Glass 1.0.0 final — Codea package"
$sc2.Save()

Write-Host "Desktop shortcuts remade on $desktop"
Write-Host "  AI Godot Studio.lnk -> $godot --path $repo"
Write-Host "  Audio Studio.lnk -> $godot --path $repo res://scenes/audio_studio.tscn"
Write-Host "  Chrome Cannon Glass.lnk -> 1.0.0 final package"
