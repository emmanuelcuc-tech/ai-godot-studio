#!/usr/bin/env python3
"""Build the one-file iPad download for Metallic Labyrinth.

Writes:
  codea/dist/MetallicLabyrinth.lua          — paste-into-Codea single buffer
  codea/dist/MetallicLabyrinth.codea/       — Codea project folder
  codea/dist/MetallicLabyrinth.codea.zip    — download this on iPad
"""

from __future__ import annotations

import hashlib
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "MetallicLabyrinth"
DIST = ROOT / "dist"
BUNDLE = DIST / "MetallicLabyrinth.codea"
ZIP_PATH = DIST / "MetallicLabyrinth.codea.zip"
SINGLE_LUA = DIST / "MetallicLabyrinth.lua"

HEADER = """-- Metallic Labyrinth
-- Single-file Codea project. Download MetallicLabyrinth.codea.zip on iPad,
-- unzip, copy MetallicLabyrinth.codea into Files → On My iPad → Codea, tap Play.
-- Tilt the iPad to roll the chrome ball. Green cup = goal. Red pits = traps.

"""

INFO_PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Buffer Order</key>
	<array>
		<string>Main</string>
	</array>
	<key>Version</key>
	<string>1.0.0</string>
	<key>Name</key>
	<string>MetallicLabyrinth</string>
	<key>Description</key>
	<string>Tilt the iPad to roll a metallic ball through a labyrinth. Reach the green goal — traps sit right beside it.</string>
	<key>Author</key>
	<string>AI Godot Studio / Codea</string>
</dict>
</plist>
"""

LOAD_ME = """Metallic Labyrinth — one-file Codea game

On iPad:
1. Download MetallicLabyrinth.codea.zip
2. Unzip it (tap the zip in Files)
3. Copy the MetallicLabyrinth.codea folder into Files → On My iPad → Codea
4. Open Codea → tap MetallicLabyrinth → Play
5. Hold the iPad almost flat, then tilt to roll

Tilt = move ball · green cup = win · red pits = lose a life
"""


def md5(data: bytes) -> str:
    return hashlib.md5(data).hexdigest()


def merged_lua() -> str:
    levels = (SRC / "Levels.lua").read_text(encoding="utf-8")
    main = (SRC / "Main.lua").read_text(encoding="utf-8")
    return HEADER + levels.rstrip() + "\n\n-- Game ---------------------------------------------------------------\n\n" + main


def write_text(path: Path, text: str) -> bytes:
    data = text.encode("utf-8")
    if not text.endswith("\n"):
        data += b"\n"
        text += "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def pack() -> None:
    lua = merged_lua()
    write_text(SINGLE_LUA, lua)
    write_text(BUNDLE / "Main.lua", lua)
    write_text(BUNDLE / "Info.plist", INFO_PLIST)
    write_text(BUNDLE / "LOAD_ME.txt", LOAD_ME)

    files = sorted(p for p in BUNDLE.iterdir() if p.is_file() and p.name != "MANIFEST.txt")
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")
    lines = [
        "Metallic Labyrinth 1.0.0 — single-file Codea package",
        f"Saved: {stamp}",
        "",
    ]
    for path in files:
        data = path.read_bytes()
        lines.append(f"{path.name:<20} {len(data):6d} bytes  {md5(data)}")
    write_text(BUNDLE / "MANIFEST.txt", "\n".join(lines) + "\n")

    if ZIP_PATH.exists():
        ZIP_PATH.unlink()
    with zipfile.ZipFile(ZIP_PATH, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(BUNDLE.iterdir()):
            if path.is_file():
                zf.write(path, arcname=f"MetallicLabyrinth.codea/{path.name}")

    print(f"Wrote {SINGLE_LUA.relative_to(ROOT.parent)}")
    print(f"Wrote {BUNDLE.relative_to(ROOT.parent)}")
    print(f"Wrote {ZIP_PATH.relative_to(ROOT.parent)} ({ZIP_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    pack()
