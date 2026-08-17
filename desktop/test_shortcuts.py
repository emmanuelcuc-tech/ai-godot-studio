# Desktop shortcut scripts must point at the updated 1.0.0 final package.
from pathlib import Path

here = Path(__file__).resolve().parent
fails = 0

def check(name, cond, detail=""):
    global fails
    if cond:
        print("OK  " + name)
    else:
        fails += 1
        print("FAIL " + name + ((" — " + detail) if detail else ""))

ps1 = (here / "Make-DesktopShortcut.ps1").read_text(encoding="utf-8")
vbs = (here / "Make-DesktopShortcut.vbs").read_text(encoding="utf-8")
launch = (here / "Launch-AIGodotStudio.bat").read_text(encoding="utf-8")
audio = (here / "Launch-AudioStudio.bat").read_text(encoding="utf-8")
open_pkg = (here / "Open-ChromeCannonGlass.bat").read_text(encoding="utf-8")
url = (here / "Chrome Cannon Glass 1.0.0 final.url").read_text(encoding="utf-8")
linux = (here / "remake_linux_desktop_shortcuts.sh").read_text(encoding="utf-8")
sh_launch = (here / "Launch-AudioStudio.sh").read_text(encoding="utf-8")

check("ps1 remakes AI Godot Studio.lnk", "AI Godot Studio.lnk" in ps1)
check("ps1 remakes Audio Studio.lnk", "Audio Studio.lnk" in ps1)
check("ps1 remakes Chrome Cannon Glass.lnk", "Chrome Cannon Glass.lnk" in ps1)
check("ps1 uses --path", "--path" in ps1)
check("ps1 labels 1.0.0 final", "1.0.0 final" in ps1)
check("ps1 launches audio_studio.tscn", "res://scenes/audio_studio.tscn" in ps1)
check("vbs deletes stale shortcuts", "ChromeCannonGlass.lnk" in vbs and "DeleteFile" in vbs)
check("vbs remakes Audio Studio.lnk", "Audio Studio.lnk" in vbs)
check("launch bat uses Godot --path", "--path" in launch and "Godot_v4" in launch)
check("audio bat launches audio_studio.tscn", "res://scenes/audio_studio.tscn" in audio)
check("open bat targets 1.0.0 zip or .codea", "ChromeCannonGlass-1.0.0-final.codea.zip" in open_pkg)
check("url points at final zip", "ChromeCannonGlass-1.0.0-final.codea.zip" in url)
check("linux remake writes Audio Studio.desktop", "Audio Studio" in linux and "audio_studio.tscn" in linux)
check("linux remake copies Launch Audio Studio.sh", "Launch Audio Studio.sh" in linux)
check("linux audio sh launches audio_studio.tscn", "res://scenes/audio_studio.tscn" in sh_launch)

if fails:
    raise SystemExit(fails)
print("\nAll shortcut checks passed.")
