# Desktop shortcuts

Remake the Windows desktop icons so they point at **this** updated checkout (AI Godot Studio 2.0 + **Audio Studio** + Chrome Cannon Glass **1.0.0 final**).

## Remake (Windows)

Double-click:

`desktop/Make-DesktopShortcut.vbs`

or:

```powershell
powershell -ExecutionPolicy Bypass -File desktop\Make-DesktopShortcut.ps1
```

That deletes stale Desktop links and writes:

| Shortcut | Opens |
|----------|--------|
| **AI Godot Studio.lnk** | Godot 4.7 with `--path` to this repo (Create + Audio Studio tab) |
| **Audio Studio.lnk** | Godot 4.7 with `--path` + `res://scenes/audio_studio.tscn` |
| **Chrome Cannon Glass.lnk** | `codea/dist/ChromeCannonGlass.codea` (1.0.0 final) |
| `Launch-AIGodotStudio.bat` | Same studio launch (no `.lnk` needed) |
| `Launch-AudioStudio.bat` | Same Audio Studio scene |
| `Open-ChromeCannonGlass.bat` | Same Codea package |

Godot is resolved from `%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe` (or another `Godot_v4*.exe` there).

## Remake (Linux)

```bash
bash desktop/remake_linux_desktop_shortcuts.sh
```

Writes `~/Desktop/AI Godot Studio.desktop`, `~/Desktop/Audio Studio.desktop`, and `~/Desktop/Chrome Cannon Glass.desktop`.
