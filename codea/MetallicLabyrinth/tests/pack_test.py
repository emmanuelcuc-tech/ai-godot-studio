#!/usr/bin/env python3
"""Verify the iPad one-file Codea zip is complete and playable."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DIST = ROOT / "codea" / "dist"
ZIP_PATH = DIST / "MetallicLabyrinth.codea.zip"
SINGLE = DIST / "MetallicLabyrinth.lua"
BUNDLE = DIST / "MetallicLabyrinth.codea"

REQUIRED_ZIP = {
    "MetallicLabyrinth.codea/Main.lua",
    "MetallicLabyrinth.codea/Info.plist",
    "MetallicLabyrinth.codea/LOAD_ME.txt",
}

MARKERS = (
    "function setup()",
    "function draw()",
    "Levels = {}",
    "First Tilt",
    "Switchback",
    "Trap Nest",
    "Needle Eye",
    "GRAVITY_SCALE",
    "physics.body",
)


def check(name: str, cond: bool, detail: str = "") -> None:
    if cond:
        print("OK  " + name)
        return
    print("FAIL " + name + ((" — " + detail) if detail else ""))
    sys.exit(1)


def main() -> None:
    check("zip exists", ZIP_PATH.is_file(), str(ZIP_PATH))
    check("single lua exists", SINGLE.is_file(), str(SINGLE))
    check("bundle Main.lua exists", (BUNDLE / "Main.lua").is_file())

    with zipfile.ZipFile(ZIP_PATH) as zf:
        names = set(zf.namelist())
        for required in sorted(REQUIRED_ZIP):
            check("zip has " + required, required in names)
        check("zip has no extra parent folder", all(n.startswith("MetallicLabyrinth.codea/") for n in names))
        main_lua = zf.read("MetallicLabyrinth.codea/Main.lua").decode("utf-8")
        plist = zf.read("MetallicLabyrinth.codea/Info.plist").decode("utf-8")

    single = SINGLE.read_text(encoding="utf-8")
    check("zip Main.lua matches MetallicLabyrinth.lua", main_lua == single)
    check("Info.plist names the project", "MetallicLabyrinth" in plist)
    check("Info.plist is single-buffer", "<string>Main</string>" in plist)
    check("Info.plist has no Levels buffer", "Levels" not in plist)

    for marker in MARKERS:
        check("game contains " + marker, marker in single)

    check("zip is a real zip", zipfile.is_zipfile(ZIP_PATH))
    print("\nAll pack checks passed.")


if __name__ == "__main__":
    main()
