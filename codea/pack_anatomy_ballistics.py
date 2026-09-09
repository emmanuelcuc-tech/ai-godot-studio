#!/usr/bin/env python3
"""Build the iPad download for Anatomy Ballistics.

Writes:
  codea/dist/AnatomyBallistics.lua                 — paste-into-Codea single buffer
  codea/dist/AnatomyBallistics.codea/              — Codea project folder
  codea/dist/AnatomyBallistics.codea.zip           — download this on iPad
  versioned zip aliases listed in dist/README.md
"""

from __future__ import annotations

import hashlib
import re
import shutil
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "AnatomyBallistics"
DIST = ROOT / "dist"
BUNDLE = DIST / "AnatomyBallistics.codea"
ZIP_PATH = DIST / "AnatomyBallistics.codea.zip"
SINGLE_LUA = DIST / "AnatomyBallistics.lua"
VERSION = "1.1.0"
ALIASES = (
    f"AnatomyBallistics-{VERSION}.codea.zip",
    f"AnatomyBallistics-{VERSION}-complete.codea.zip",
)

HEADER = """-- Anatomy Ballistics 1.1.0
-- Single-file Codea project. Download AnatomyBallistics.codea.zip on iPad,
-- unzip, copy AnatomyBallistics.codea into Files → On My iPad → Codea, tap Play.
-- Drag to aim. Double-tap to fire .22 LR. RESET rebuilds. NEXT advances range.

"""

LOAD_ME = """Anatomy Ballistics — 1.1.0

On iPad:
1. Download AnatomyBallistics.codea.zip
2. Unzip it (tap the zip in Files)
3. Copy the AnatomyBallistics.codea folder into Files → On My iPad → Codea
4. Open Codea → tap AnatomyBallistics → Play (landscape)
5. Drag to aim, double-tap to fire

RESET rebuilds the body · NEXT steps 40→15 ft, then the house wall
"""


def md5(data: bytes) -> str:
    return hashlib.md5(data).hexdigest()


def buffer_order() -> list[str]:
    text = (SRC / "Info.plist").read_text(encoding="utf-8")
    block = re.search(r"<key>Buffer Order</key>\s*<array>(.*?)</array>", text, re.S)
    if not block:
        raise SystemExit("Info.plist is missing Buffer Order")
    names = re.findall(r"<string>(.*?)</string>", block.group(1))
    if "Main" not in names:
        raise SystemExit("Buffer Order must include Main")
    return names


def write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not data.endswith(b"\n"):
        data += b"\n"
    path.write_bytes(data)


def write_text(path: Path, text: str) -> bytes:
    data = text.encode("utf-8")
    if not text.endswith("\n"):
        data += b"\n"
    write_bytes(path, data)
    return path.read_bytes()


def merged_lua(order: list[str]) -> str:
    # Dependencies first so a one-buffer paste defines tables before Main.
    deps = [name for name in order if name != "Main"] + ["Main"]
    parts = [HEADER.rstrip(), ""]
    for name in deps:
        parts.append(f"-- Buffer: {name} ------------------------------------------------")
        parts.append((SRC / f"{name}.lua").read_text(encoding="utf-8").rstrip())
        parts.append("")
    return "\n".join(parts) + "\n"


def pack() -> None:
    order = buffer_order()
    BUNDLE.mkdir(parents=True, exist_ok=True)

    for stale in BUNDLE.glob("*.lua"):
        stale.unlink()

    for name in order:
        src = SRC / f"{name}.lua"
        if not src.is_file():
            raise SystemExit(f"missing buffer {src}")
        write_bytes(BUNDLE / f"{name}.lua", src.read_bytes())

    write_bytes(BUNDLE / "Info.plist", (SRC / "Info.plist").read_bytes())
    write_text(BUNDLE / "LOAD_ME.txt", LOAD_ME)
    write_text(BUNDLE / "README.md", (SRC / "README.md").read_text(encoding="utf-8"))
    write_text(SINGLE_LUA, merged_lua(order))
    write_text(DIST / "AnatomyBallistics-README.md", (SRC / "README.md").read_text(encoding="utf-8"))

    files = sorted(p for p in BUNDLE.iterdir() if p.is_file() and p.name != "MANIFEST.txt")
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")
    lines = [
        f"Anatomy Ballistics {VERSION} — Codea package",
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
                zf.write(path, arcname=f"AnatomyBallistics.codea/{path.name}")

    for alias in ALIASES:
        shutil.copy2(ZIP_PATH, DIST / alias)

    print(f"Wrote {SINGLE_LUA.relative_to(ROOT.parent)}")
    print(f"Wrote {BUNDLE.relative_to(ROOT.parent)}")
    print(f"Wrote {ZIP_PATH.relative_to(ROOT.parent)} ({ZIP_PATH.stat().st_size} bytes)")
    for alias in ALIASES:
        print(f"Wrote codea/dist/{alias}")


if __name__ == "__main__":
    pack()
