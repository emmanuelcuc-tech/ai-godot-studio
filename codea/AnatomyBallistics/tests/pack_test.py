#!/usr/bin/env python3
"""Verify the iPad Anatomy Ballistics Codea zip is complete."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "codea" / "AnatomyBallistics"
DIST = ROOT / "codea" / "dist"
ZIP_PATH = DIST / "AnatomyBallistics.codea.zip"
SINGLE = DIST / "AnatomyBallistics.lua"
BUNDLE = DIST / "AnatomyBallistics.codea"

BUFFERS = (
    "Main",
    "Vec3",
    "TwentyTwo",
    "Bones",
    "Organs",
    "Stages",
    "Ballistics",
    "SoftBody",
    "Blood",
    "Anatomy",
    "Camera",
)

ALIASES = (
    "AnatomyBallistics-1.1.0.codea.zip",
    "AnatomyBallistics-1.1.0-complete.codea.zip",
)

MARKERS = (
    "function setup()",
    "function draw()",
    "TwentyTwo",
    "Anatomy.build",
    "Double-tap",
    "RANGE_FEET",
    "gallbladder",
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
    check("zip is a real zip", zipfile.is_zipfile(ZIP_PATH))

    with zipfile.ZipFile(ZIP_PATH) as zf:
        names = set(zf.namelist())
        check("zip has Info.plist", "AnatomyBallistics.codea/Info.plist" in names)
        check("zip has LOAD_ME.txt", "AnatomyBallistics.codea/LOAD_ME.txt" in names)
        check("zip has no extra parent", all(n.startswith("AnatomyBallistics.codea/") for n in names))
        plist = zf.read("AnatomyBallistics.codea/Info.plist").decode("utf-8")
        for buf in BUFFERS:
            member = f"AnatomyBallistics.codea/{buf}.lua"
            check("zip has " + buf + ".lua", member in names)
            src = (SRC / f"{buf}.lua").read_bytes()
            packed = zf.read(member)
            if packed.endswith(b"\n") and not src.endswith(b"\n"):
                packed = packed[:-1]
            check(buf + ".lua matches source", packed == src or packed == src + b"\n")
            check("Info.plist lists " + buf, f"<string>{buf}</string>" in plist)

    single = SINGLE.read_text(encoding="utf-8")
    for marker in MARKERS:
        check("merged lua contains " + marker, marker in single)
    for buf in BUFFERS:
        check("merged lua has buffer " + buf, f"-- Buffer: {buf} " in single)

    zip_bytes = ZIP_PATH.read_bytes()
    for alias in ALIASES:
        path = DIST / alias
        check("alias exists " + alias, path.is_file())
        check("alias matches " + alias, path.read_bytes() == zip_bytes)

    print("\nAll anatomy pack checks passed.")


if __name__ == "__main__":
    main()
