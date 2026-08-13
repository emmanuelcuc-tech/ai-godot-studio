#!/usr/bin/env python3
"""
Surround downmix/upmix + open matrix expand/encode (generic approximation).

Layouts: stereo, 2.1, 5.1, 7.1
Applies per-speaker gain_db / volume / fill amount on export.
"""
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

SPEAKERS_71 = ["FL", "FR", "FC", "LFE", "BL", "BR", "SL", "SR"]
SPEAKERS_51 = ["FL", "FR", "FC", "LFE", "SL", "SR"]
SPEAKERS_21 = ["FL", "FR", "LFE"]
SPEAKERS_20 = ["FL", "FR"]


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


def db_to_lin(db: float) -> float:
    if db <= -60:
        return 0.0
    return 10.0 ** (db / 20.0)


def speaker_list(layout: str) -> list[str]:
    layout = layout.lower()
    if layout in ("7.1", "71"):
        return SPEAKERS_71
    if layout in ("5.1", "51"):
        return SPEAKERS_51
    if layout in ("2.1", "21"):
        return SPEAKERS_21
    return SPEAKERS_20


def parse_gains(json_str: str, layout: str) -> dict[str, float]:
    """JSON map speaker->gain_db plus optional volume 0-100 and amount/fill."""
    data = json.loads(json_str) if json_str else {}
    out = {}
    for sp in speaker_list(layout):
        entry = data.get(sp, {})
        if isinstance(entry, (int, float)):
            out[sp] = float(entry)
            continue
        gain = float(entry.get("gain_db", entry.get("level_db", 0.0)))
        vol = float(entry.get("volume", 100.0)) / 100.0
        amount = float(entry.get("amount", entry.get("fill", 100.0))) / 100.0
        out[sp] = gain + (20.0 * math.log10(max(1e-6, vol * amount)))
    # master
    master = float(data.get("master_gain_db", 0.0))
    for sp in out:
        out[sp] += master
    return out


def pan_expr(gains: dict[str, float], layout: str) -> str:
    """Build ffmpeg pan filter for layout using weighted FL/FR(/...) from stereo input."""
    g = {k: db_to_lin(v) for k, v in gains.items()}
    layout = layout.lower()
    if layout in ("stereo", "2.0", "20"):
        return (
            f"pan=stereo|"
            f"c0={g.get('FL', 1):.6f}*c0|"
            f"c1={g.get('FR', 1):.6f}*c1"
        )
    if layout in ("2.1", "21"):
        # FL FR LFE
        return (
            "pan=3.1|"
            f"FL={g.get('FL', 1):.6f}*c0|"
            f"FR={g.get('FR', 1):.6f}*c1|"
            f"LFE={g.get('LFE', 1):.6f}*0.5*(c0+c1)"
        ).replace("3.1", "2.1")
    if layout in ("5.1", "51"):
        # ITU-ish upmix from stereo + gains
        return (
            "pan=5.1|"
            f"FL={g.get('FL', 1):.6f}*c0|"
            f"FR={g.get('FR', 1):.6f}*c1|"
            f"FC={g.get('FC', 1):.6f}*0.5*(c0+c1)|"
            f"LFE={g.get('LFE', 1):.6f}*0.5*(c0+c1)|"
            f"SL={g.get('SL', 1):.6f}*c0|"
            f"SR={g.get('SR', 1):.6f}*c1"
        )
    # 7.1
    return (
        "pan=7.1|"
        f"FL={g.get('FL', 1):.6f}*c0|"
        f"FR={g.get('FR', 1):.6f}*c1|"
        f"FC={g.get('FC', 1):.6f}*0.5*(c0+c1)|"
        f"LFE={g.get('LFE', 1):.6f}*0.5*(c0+c1)|"
        f"BL={g.get('BL', 1):.6f}*c0|"
        f"BR={g.get('BR', 1):.6f}*c1|"
        f"SL={g.get('SL', 1):.6f}*0.7*c0|"
        f"SR={g.get('SR', 1):.6f}*0.7*c1"
    )


def downmix_filter(src_layout: str, dst_layout: str) -> str:
    """Standard-ish ffmpeg downmix chain labels."""
    src = src_layout.lower()
    dst = dst_layout.lower()
    if src == dst:
        return "anull"
    # Use pan downmix formulas (best-effort ITU)
    if dst in ("5.1", "51") and src in ("7.1", "71"):
        return (
            "pan=5.1|"
            "FL=c0|FR=c1|FC=c2|LFE=c3|"
            "SL=0.707*c4+0.707*c6|SR=0.707*c5+0.707*c7"
        )
    if dst in ("2.1", "21"):
        return "pan=2.1|FL=c0|FR=c1|LFE=c3"
    if dst in ("stereo", "2.0"):
        # LoRo-ish
        return (
            "pan=stereo|"
            "c0=0.707*c0+0.5*c2+0.5*c4+0.5*c6|"
            "c1=0.707*c1+0.5*c2+0.5*c5+0.5*c7"
        )
    return "anull"


def matrix_encode(input_path: str, output_path: str) -> dict:
    """Open Lt/Rt-style matrix widen from stereo (generic approximation)."""
    ffmpeg = find_ffmpeg()
    af = (
        "pan=stereo|"
        "c0=c0+0.707*c0|"
        "c1=c1+0.707*c1,"
        "extrastereo=m=1.5"
    )
    cmd = [ffmpeg, "-y", "-i", input_path, "-af", af, "-acodec", "pcm_s16le", output_path]
    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        return {"ok": True, "path": output_path, "mode": "matrix_encode"}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def matrix_expand(input_path: str, output_path: str, gains: dict[str, float], style: str = "matrix") -> dict:
    """Expand stereo to 5.1 using open matrix / Pro Logic–style approximations."""
    ffmpeg = find_ffmpeg()
    g = {k: db_to_lin(v) for k, v in gains.items()}
    style = (style or "matrix").lower()
    if style in ("prologic", "prologic_expand", "pl"):
        # Classic Pro Logic–ish: strong center, mono surround split L/R.
        af = (
            "pan=5.1|"
            f"FL={g.get('FL', 1):.4f}*c0|"
            f"FR={g.get('FR', 1):.4f}*c1|"
            f"FC={g.get('FC', 1):.4f}*0.707*(c0+c1)|"
            f"LFE={g.get('LFE', 1):.4f}*0.25*(c0+c1)|"
            f"SL={g.get('SL', 1):.4f}*0.707*(c0-c1)|"
            f"SR={g.get('SR', 1):.4f}*0.707*(c1-c0)"
        )
        mode_name = "prologic_expand"
    elif style in ("pl2", "pl2_expand", "dolby_pro"):
        # Pro Logic II–ish: wider stereo surrounds + softer center bleed.
        af = (
            "pan=5.1|"
            f"FL={g.get('FL', 1):.4f}*c0|"
            f"FR={g.get('FR', 1):.4f}*c1|"
            f"FC={g.get('FC', 1):.4f}*0.5*(c0+c1)|"
            f"LFE={g.get('LFE', 1):.4f}*0.35*(c0+c1)|"
            f"SL={g.get('SL', 1):.4f}*(0.9*c0-0.4*c1)|"
            f"SR={g.get('SR', 1):.4f}*(0.9*c1-0.4*c0)"
        )
        mode_name = "pl2_expand"
    else:
        af = (
            "pan=5.1|"
            f"FL={g.get('FL', 1):.4f}*c0|"
            f"FR={g.get('FR', 1):.4f}*c1|"
            f"FC={g.get('FC', 1):.4f}*0.5*(c0+c1)|"
            f"LFE={g.get('LFE', 1):.4f}*0.3*(c0+c1)|"
            f"SL={g.get('SL', 1):.4f}*(c0-0.5*c1)|"
            f"SR={g.get('SR', 1):.4f}*(c1-0.5*c0)"
        )
        mode_name = "matrix_expand"
    cmd = [ffmpeg, "-y", "-i", input_path, "-af", af, "-acodec", "pcm_s16le", output_path]
    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        return {"ok": True, "path": output_path, "mode": mode_name}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def export_layout(
    input_path: str,
    output_path: str,
    layout: str,
    gains_json: str,
    fmt: str = "wav",
    bitrate: int = 256,
    mode: str = "direct",
) -> dict:
    ffmpeg = find_ffmpeg()
    gains = parse_gains(gains_json, layout)
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)

    if mode in ("matrix_encode", "pl2_encode", "prologic_encode"):
        return matrix_encode(input_path, str(out))
    if mode in ("matrix_expand", "pl2_expand", "prologic_expand"):
        return matrix_expand(input_path, str(out), gains, style=mode)

    af = pan_expr(gains, layout)
    cmd = [ffmpeg, "-y", "-i", input_path, "-af", af]
    fmt = fmt.lower()
    if fmt == "wav":
        cmd += ["-acodec", "pcm_s16le", str(out)]
    elif fmt == "mp3":
        cmd += ["-ac", "2", "-acodec", "libmp3lame", "-b:a", f"{bitrate}k", str(out)]
    elif fmt in ("ac3", "eac3"):
        cmd += ["-acodec", fmt, "-b:a", f"{bitrate}k", str(out)]
    else:
        cmd += ["-acodec", "pcm_s16le", str(out)]
    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        return {
            "ok": True,
            "path": str(out),
            "layout": layout,
            "note": "Generic surround / matrix mix via ffmpeg.",
        }
    except FileNotFoundError:
        return {"ok": False, "error": "ffmpeg not found"}
    except subprocess.CalledProcessError as exc:
        return {"ok": False, "error": str(exc)}


def main() -> int:
    p = argparse.ArgumentParser(description="Surround mix / open matrix expand")
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--layout", default="stereo", help="stereo|2.1|5.1|7.1")
    p.add_argument("--gains-json", default="{}")
    p.add_argument("--format", default="wav")
    p.add_argument("--bitrate", type=int, default=256)
    p.add_argument(
        "--mode",
        default="direct",
        choices=[
            "direct",
            "matrix_expand",
            "matrix_encode",
            "pl2_encode",
            "pl2_expand",
            "prologic_expand",
            "prologic_encode",
            "downmix",
        ],
    )
    p.add_argument("--from-layout", default="")
    args = p.parse_args()

    if args.mode == "downmix" and args.from_layout:
        ffmpeg = find_ffmpeg()
        af = downmix_filter(args.from_layout, args.layout)
        gains = parse_gains(args.gains_json, args.layout)
        # apply master-ish volume after downmix
        master = db_to_lin(gains.get("FL", 0) * 0 + float(json.loads(args.gains_json or "{}").get("master_gain_db", 0)))
        cmd = [
            find_ffmpeg(),
            "-y",
            "-i",
            args.input,
            "-af",
            f"{af},volume={max(master, 0.001):.6f}",
            "-acodec",
            "pcm_s16le",
            args.output,
        ]
        try:
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
            result = {"ok": True, "path": args.output, "layout": args.layout}
        except Exception as exc:
            result = {"ok": False, "error": str(exc)}
    else:
        result = export_layout(
            args.input,
            args.output,
            args.layout,
            args.gains_json,
            args.format,
            args.bitrate,
            args.mode,
        )
    print(json.dumps(result, indent=2))
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
