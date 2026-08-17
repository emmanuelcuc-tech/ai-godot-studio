#!/usr/bin/env python3
"""Probe audio file with ffprobe: codec, channels, bit depth, layout."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


def find_ffprobe() -> str:
    exe = shutil.which("ffprobe")
    if exe:
        return exe
    for candidate in (
        Path(__file__).resolve().parent / "ffmpeg" / "ffprobe.exe",
        Path(__file__).resolve().parent.parent / "bin" / "ffprobe.exe",
    ):
        if candidate.is_file():
            return str(candidate)
    return "ffprobe"


def probe(path: str) -> dict:
    ffprobe = find_ffprobe()
    cmd = [
        ffprobe,
        "-v",
        "quiet",
        "-print_format",
        "json",
        "-show_format",
        "-show_streams",
        path,
    ]
    try:
        raw = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
    except FileNotFoundError:
        return {
            "ok": False,
            "error": "ffprobe not found. Install ffmpeg and add it to PATH.",
            "path": path,
        }
    except subprocess.CalledProcessError as exc:
        return {"ok": False, "error": exc.output or str(exc), "path": path}

    data = json.loads(raw)
    streams = data.get("streams") or []
    audio = next((s for s in streams if s.get("codec_type") == "audio"), None)
    fmt = data.get("format") or {}
    if not audio:
        return {"ok": False, "error": "No audio stream found", "path": path}

    channels = int(audio.get("channels") or 0)
    layout = (audio.get("channel_layout") or "").lower()
    codec = audio.get("codec_name") or "unknown"
    codec_long = audio.get("codec_long_name") or codec
    bits = audio.get("bits_per_raw_sample") or audio.get("bits_per_sample")
    sample_fmt = audio.get("sample_fmt") or ""
    if not bits:
        # Infer from sample format
        mapping = {
            "u8": 8,
            "s16": 16,
            "s16p": 16,
            "s32": 32,
            "s32p": 32,
            "flt": 32,
            "fltp": 32,
            "dbl": 64,
            "dblp": 64,
        }
        bits = mapping.get(sample_fmt, None)

    surround = "stereo"
    if channels >= 8 or "7.1" in layout:
        surround = "7.1"
    elif channels >= 6 or "5.1" in layout:
        surround = "5.1"
    elif channels == 3 or "2.1" in layout:
        surround = "2.1"
    elif channels == 1:
        surround = "mono"
    elif channels == 2:
        surround = "stereo"

    cinema_codec = codec in {
        "ac3",
        "eac3",
        "truehd",
        "dts",
        "dca",
        "mlp",
        "atmos",
    }

    ext = Path(path).suffix.lower().lstrip(".")
    format_name = fmt.get("format_name") or ""
    format_long = fmt.get("format_long_name") or ""
    # ffprobe often returns comma-separated containers (e.g. "mov,mp4,m4a,…")
    container = format_name.split(",")[0].strip() if format_name else ext
    if not container:
        container = ext or "unknown"
    file_type = ext or container

    bitrate_raw = int(fmt.get("bit_rate") or audio.get("bit_rate") or 0) or None
    bitrate_kbps = int(round(bitrate_raw / 1000.0)) if bitrate_raw else None
    # PCM WAV often omits bit_rate — estimate from sample params
    sample_rate = int(audio.get("sample_rate") or 0)
    if bitrate_kbps is None and bits and sample_rate and channels:
        bitrate_kbps = int(round(sample_rate * channels * int(bits) / 1000.0))
        bitrate_raw = bitrate_kbps * 1000

    return {
        "ok": True,
        "path": path,
        "filename": Path(path).name,
        "codec": codec,
        "codec_long": codec_long,
        "sample_rate": sample_rate,
        "channels": channels,
        "channel_layout": audio.get("channel_layout") or "",
        "bit_depth": int(bits) if bits else None,
        "sample_fmt": sample_fmt,
        "bitrate": bitrate_raw,
        "bitrate_kbps": bitrate_kbps,
        "duration": float(fmt.get("duration") or audio.get("duration") or 0) or None,
        "surround_hint": surround,
        "cinema_codec": cinema_codec,
        "format_name": format_name,
        "format_long_name": format_long,
        "container": container,
        "file_type": file_type,
        "extension": ext,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe media with ffprobe")
    parser.add_argument("input", help="Audio/video file path")
    parser.add_argument("--json-out", default="", help="Write JSON to file")
    args = parser.parse_args()
    result = probe(args.input)
    text = json.dumps(result, indent=2)
    if args.json_out:
        Path(args.json_out).write_text(text, encoding="utf-8")
    print(text)
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
