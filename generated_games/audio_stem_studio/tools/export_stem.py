#!/usr/bin/env python3
"""Export a stem or mix with format/bitrate, optional gain/pan/reverb bake via ffmpeg."""
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path


def find_ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    for candidate in (
        Path(__file__).resolve().parent / "ffmpeg" / "ffmpeg.exe",
        Path(__file__).resolve().parent.parent / "bin" / "ffmpeg.exe",
    ):
        if candidate.is_file():
            return str(candidate)
    return "ffmpeg"


def db_to_linear(db: float) -> float:
    return 10.0 ** (db / 20.0)


def build_af(gain_db: float, pan: float, reverb_amount: float, volume: float) -> str:
    """pan: -1 left .. 1 right; volume 0-100; reverb_amount 0-100 wet-ish via aecho."""
    vol_lin = max(0.0, volume / 100.0) * db_to_linear(gain_db)
    # Stereo pan approximation
    left = vol_lin * math.cos((pan + 1.0) * 0.25 * math.pi)
    right = vol_lin * math.sin((pan + 1.0) * 0.25 * math.pi)
    filters = [f"volume={vol_lin:.6f}", f"pan=stereo|c0={left:.6f}*c0|c1={right:.6f}*c1"]
    if reverb_amount > 1.0:
        # Lightweight echo as export-time reverb approximation (preview uses Godot reverb)
        wet = min(1.0, reverb_amount / 100.0) * 0.55
        filters.append(f"aecho=0.8:0.88:60:0.35")
        filters.append(f"volume={1.0 + wet * 0.15:.4f}")
    return ",".join(filters)


def export_one(
    input_path: str,
    output_path: str,
    fmt: str,
    bitrate_kbps: int,
    gain_db: float = 0.0,
    pan: float = 0.0,
    reverb_amount: float = 0.0,
    volume: float = 100.0,
) -> dict:
    ffmpeg = find_ffmpeg()
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    af = build_af(gain_db, pan, reverb_amount, volume)
    fmt = fmt.lower()
    cmd = [ffmpeg, "-y", "-i", input_path, "-af", af]

    if fmt in ("wav", "wave"):
        cmd += ["-acodec", "pcm_s16le", str(out)]
    elif fmt in ("mp3",):
        cmd += ["-acodec", "libmp3lame", "-b:a", f"{bitrate_kbps}k", str(out)]
    elif fmt in ("mpeg", "mp2"):
        cmd += ["-acodec", "mp2", "-b:a", f"{bitrate_kbps}k", str(out)]
    elif fmt in ("m4a", "aac", "mp4"):
        if not str(out).lower().endswith((".m4a", ".mp4", ".aac")):
            out = out.with_suffix(".m4a")
        cmd += ["-acodec", "aac", "-b:a", f"{bitrate_kbps}k", str(out)]
    elif fmt in ("ac3", "eac3"):
        codec = "ac3" if fmt == "ac3" else "eac3"
        cmd += ["-acodec", codec, "-b:a", f"{bitrate_kbps}k", str(out)]
    else:
        cmd += ["-acodec", "pcm_s16le", str(out.with_suffix(".wav"))]

    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        return {"ok": True, "path": str(out)}
    except FileNotFoundError:
        return {"ok": False, "error": "ffmpeg not found on PATH"}
    except subprocess.CalledProcessError as exc:
        return {"ok": False, "error": str(exc)}


def mix_files(
    inputs: list[str],
    output_path: str,
    fmt: str,
    bitrate_kbps: int,
    gains_db: list[float] | None = None,
) -> dict:
    ffmpeg = find_ffmpeg()
    if not inputs:
        return {"ok": False, "error": "No inputs"}
    n = len(inputs)
    cmd = [ffmpeg, "-y"]
    for p in inputs:
        cmd += ["-i", p]
    weights = []
    for i in range(n):
        g = 0.0 if not gains_db or i >= len(gains_db) else gains_db[i]
        weights.append(f"{db_to_linear(g):.6f}")
    # amix then normalize-ish
    filter_complex = f"amix=inputs={n}:duration=longest:dropout_transition=0,volume={n}"
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd += ["-filter_complex", filter_complex]
    fmt = fmt.lower()
    if fmt == "wav":
        cmd += ["-acodec", "pcm_s16le", str(out)]
    elif fmt == "mp3":
        cmd += ["-acodec", "libmp3lame", "-b:a", f"{bitrate_kbps}k", str(out)]
    elif fmt in ("mpeg", "mp2"):
        cmd += ["-acodec", "mp2", "-b:a", f"{bitrate_kbps}k", str(out)]
    else:
        cmd += ["-acodec", "pcm_s16le", str(out)]
    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        return {"ok": True, "path": str(out)}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--input", action="append", default=[], help="Input file (repeat for mix)")
    p.add_argument("--output", required=True)
    p.add_argument("--format", default="wav")
    p.add_argument("--bitrate", type=int, default=256)
    p.add_argument("--gain-db", type=float, default=0.0)
    p.add_argument("--volume", type=float, default=100.0)
    p.add_argument("--pan", type=float, default=0.0)
    p.add_argument("--reverb-amount", type=float, default=0.0)
    p.add_argument("--mix", action="store_true")
    args = p.parse_args()
    if args.mix and len(args.input) > 1:
        result = mix_files(args.input, args.output, args.format, args.bitrate)
    elif args.input:
        result = export_one(
            args.input[0],
            args.output,
            args.format,
            args.bitrate,
            args.gain_db,
            args.pan,
            args.reverb_amount,
            args.volume,
        )
    else:
        result = {"ok": False, "error": "No --input"}
    print(json.dumps(result, indent=2))
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
