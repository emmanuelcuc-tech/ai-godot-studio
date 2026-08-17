#!/usr/bin/env python3
"""
Separate audio into labeled stems using audio-separator (UVR / Demucs models).

Primary path: audio_separator.separator.Separator
Fallback: ffmpeg stereo L/R + band splits when audio-separator is missing.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import traceback
from pathlib import Path

# Prefer 6-stem Demucs, then 4-stem, then karaoke vocal/instrumental.
MODEL_PIPELINE = [
    ("htdemucs_6s.yaml", ["vocals", "drums", "bass", "guitar", "piano", "other"]),
    ("htdemucs.yaml", ["vocals", "drums", "bass", "other"]),
    ("UVR_MDXNET_KARA_2.onnx", ["vocals", "instrumental"]),
]


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


def ensure_wav(input_path: Path, work_dir: Path) -> Path:
    """Decode any ffmpeg-readable codec to PCM wav."""
    out = work_dir / "source_decoded.wav"
    if input_path.suffix.lower() == ".wav":
        return input_path
    ffmpeg = find_ffmpeg()
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(input_path),
        "-acodec",
        "pcm_s16le",
        "-ar",
        "44100",
        str(out),
    ]
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    return out


def analyze_stem_label(path: Path, suggested: str) -> str:
    """Best-effort spectral label tweak using numpy FFT energy bands."""
    try:
        import numpy as np
        import soundfile as sf
    except Exception:
        return suggested

    try:
        data, sr = sf.read(str(path), always_2d=True)
    except Exception:
        return suggested
    if data.size == 0:
        return suggested
    mono = data.mean(axis=1)
    if mono.size < 1024:
        return suggested
    # Short window near start
    chunk = mono[: min(len(mono), sr * 4)]
    window = np.hanning(len(chunk))
    spec = np.abs(np.fft.rfft(chunk * window))
    freqs = np.fft.rfftfreq(len(chunk), 1.0 / sr)
    total = float(spec.sum()) + 1e-9

    def band(lo: float, hi: float) -> float:
        mask = (freqs >= lo) & (freqs < hi)
        return float(spec[mask].sum()) / total

    low = band(20, 180)
    low_mid = band(180, 500)
    mid = band(500, 2500)
    high = band(2500, 8000)
    centroid = float((freqs * spec).sum() / (spec.sum() + 1e-9))

    label = suggested
    base = suggested.lower()
    if base in ("", "other", "instrumental", "instrument"):
        if low > 0.45 and centroid < 250:
            label = "Bass"
        elif low > 0.25 and high > 0.2 and mid < 0.35:
            label = "Drums"
        elif mid > 0.4 and 200 < centroid < 1200:
            label = "Vocal"
        elif mid > 0.35 and high > 0.2:
            label = "Guitar"
        elif low_mid > 0.3:
            label = "Instrument"
        else:
            label = suggested.title() if suggested else "Other"
    elif "vocal" in base and high > 0.35 and mid > 0.3:
        label = "Background Vocals" if "back" in base or "bg" in base else "Vocals"
    return label


def guess_label_from_filename(path: Path) -> str:
    name = path.stem.lower()
    mapping = [
        ("vocals", "Vocals"),
        ("vocal", "Vocals"),
        ("karaoke", "Vocals"),
        ("drums", "Drums"),
        ("drum", "Drums"),
        ("bass", "Bass"),
        ("guitar", "Guitar"),
        ("piano", "Piano"),
        ("other", "Other"),
        ("instrumental", "Instrumental"),
        ("instrum", "Instrumental"),
    ]
    for key, label in mapping:
        if key in name:
            return label
    return path.stem.replace("_", " ").title()


def run_audio_separator(wav_path: Path, out_dir: Path, model: str | None) -> list[Path]:
    from audio_separator.separator import Separator

    models = [model] if model else [m[0] for m in MODEL_PIPELINE]
    last_err = None
    for model_name in models:
        try:
            separator = Separator(
                output_dir=str(out_dir),
                output_format="WAV",
                sample_rate=44100,
            )
            # API accepts model_filename=...
            separator.load_model(model_filename=model_name)
            print(json.dumps({"progress": f"Loaded model {model_name}"}), flush=True)
            outputs = separator.separate(str(wav_path))
            files: list[Path] = []
            if isinstance(outputs, dict):
                files = [Path(v) for v in outputs.values()]
            elif isinstance(outputs, (list, tuple)):
                files = [Path(p) for p in outputs]
            else:
                files = list(out_dir.glob("*.wav"))
            files = [p if p.is_absolute() else out_dir / p for p in files]
            files = [p for p in files if p.is_file()]
            if files:
                return files
        except Exception as exc:
            last_err = exc
            print(json.dumps({"warn": f"Model {model_name} failed: {exc}"}), flush=True)
            continue
    if last_err:
        raise last_err
    raise RuntimeError("audio-separator produced no output files")


def ffmpeg_fallback_split(wav_path: Path, out_dir: Path) -> list[dict]:
    """Usable without ML: L/R + FFT-ish band splits via ffmpeg filters."""
    ffmpeg = find_ffmpeg()
    stems = []
    plans = [
        ("01_left", "Left", "pan=mono|c0=c0"),
        ("02_right", "Right", "pan=mono|c0=c1"),
        ("03_low", "Bass Band", "pan=mono|c0=0.5*c0+0.5*c1,lowpass=f=180"),
        ("04_lowmid", "Low Mid", "pan=mono|c0=0.5*c0+0.5*c1,highpass=f=180,lowpass=f=500"),
        ("05_mid", "Vocal Band", "pan=mono|c0=0.5*c0+0.5*c1,highpass=f=300,lowpass=f=3400"),
        ("06_highmid", "Guitar Band", "pan=mono|c0=0.5*c0+0.5*c1,highpass=f=500,lowpass=f=4000"),
        ("07_high", "High Band", "pan=mono|c0=0.5*c0+0.5*c1,highpass=f=4000"),
        ("08_center", "Center", "pan=mono|c0=0.5*c0+0.5*c1"),
    ]
    for stem_id, label, filt in plans:
        out = out_dir / f"{stem_id}.wav"
        cmd = [
            ffmpeg,
            "-y",
            "-i",
            str(wav_path),
            "-af",
            filt,
            "-ac",
            "2",
            str(out),
        ]
        try:
            subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
            stems.append({"id": stem_id, "label": label, "path": str(out), "enabled": True})
        except Exception:
            stems.append({"id": stem_id, "label": label, "path": "", "enabled": False})
    return stems


def map_files_to_channels(files: list[Path]) -> list[dict]:
    """One stem file → one channel. Label from filename / spectral guess."""
    # Stable role order when labels are known; otherwise keep discovery order.
    priority = [
        "Vocals",
        "Background Vocals",
        "Drums",
        "Bass",
        "Guitar",
        "Piano",
        "Instrumental",
        "Other",
    ]
    labeled: list[dict] = []
    for f in files:
        if not f.is_file():
            continue
        suggested = guess_label_from_filename(f)
        label = analyze_stem_label(f, suggested)
        labeled.append({"path": f, "label": label})

    def sort_key(item: dict) -> tuple:
        label = str(item["label"])
        for i, want in enumerate(priority):
            if label.lower() == want.lower() or want.lower() in label.lower():
                return (i, label.lower())
        return (len(priority), label.lower())

    labeled.sort(key=sort_key)
    channels: list[dict] = []
    for i, item in enumerate(labeled):
        path = item["path"]
        label = str(item["label"]).strip() or path.stem.replace("_", " ").title()
        channels.append(
            {
                "index": i + 1,
                "label": label,
                "path": str(path),
                "enabled": True,
            }
        )
    return channels


def main() -> int:
    parser = argparse.ArgumentParser(description="Separate stems with audio-separator")
    parser.add_argument("input", help="Input audio path")
    parser.add_argument("--out-dir", required=True, help="Output directory")
    parser.add_argument("--model", default="", help="Force model filename")
    parser.add_argument("--json-out", default="", help="Manifest JSON path")
    parser.add_argument("--fallback-only", action="store_true")
    args = parser.parse_args()

    input_path = Path(args.input)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "ok": False,
        "engine": "",
        "input": str(input_path),
        "channels": [],
        "error": "",
        "install_hint": "pip install audio-separator\n# optional GPU: pip install \"audio-separator[gpu]\"",
    }

    try:
        print(json.dumps({"progress": "Decoding source…"}), flush=True)
        wav = ensure_wav(input_path, out_dir)
        channels: list[dict] = []
        engine = ""

        if not args.fallback_only:
            try:
                print(json.dumps({"progress": "Running audio-separator…"}), flush=True)
                files = run_audio_separator(wav, out_dir, args.model or None)
                channels = map_files_to_channels(files)
                engine = "audio-separator"
            except ImportError:
                print(json.dumps({"progress": "audio-separator missing; ffmpeg fallback…"}), flush=True)
                channels = ffmpeg_fallback_split(wav, out_dir)
                for i, c in enumerate(channels):
                    c["index"] = i + 1
                engine = "ffmpeg-fallback"
                manifest["error"] = "audio-separator not installed; used ffmpeg band-split fallback"
            except Exception as exc:
                print(json.dumps({"progress": f"ML failed ({exc}); ffmpeg fallback…"}), flush=True)
                channels = ffmpeg_fallback_split(wav, out_dir)
                for i, c in enumerate(channels):
                    c["index"] = i + 1
                engine = "ffmpeg-fallback"
                manifest["error"] = f"audio-separator failed: {exc}"
        else:
            channels = ffmpeg_fallback_split(wav, out_dir)
            for i, c in enumerate(channels):
                c["index"] = i + 1
            engine = "ffmpeg-fallback"

        # Keep only real stem files; one channel per path (no empty padding).
        real_channels: list[dict] = []
        for i, c in enumerate(channels):
            path = str(c.get("path", "") or "").strip()
            if not path or not Path(path).is_file():
                continue
            label = str(c.get("label", "")).strip()
            if not label:
                label = Path(path).stem.replace("_", " ").title()
            real_channels.append(
                {
                    "index": len(real_channels) + 1,
                    "label": label,
                    "path": path,
                    "enabled": True,
                    "level_db": float(c.get("level_db", 0.0)),
                    "volume": float(c.get("volume", 100.0)),
                    "pan": float(c.get("pan", 0.0)),
                    "reverb": float(c.get("reverb", 0.0)),
                }
            )
        channels = real_channels

        if not channels:
            raise RuntimeError("Separation produced no stem files")

        manifest["ok"] = True
        manifest["engine"] = engine
        manifest["channels"] = channels
        print(json.dumps({"progress": "Done", "engine": engine, "stems": len(channels)}), flush=True)
    except Exception as exc:
        manifest["ok"] = False
        manifest["error"] = str(exc)
        manifest["traceback"] = traceback.format_exc()
        print(json.dumps({"error": str(exc)}), flush=True)

    text = json.dumps(manifest, indent=2)
    json_path = Path(args.json_out) if args.json_out else out_dir / "manifest.json"
    json_path.write_text(text, encoding="utf-8")
    print(text)
    return 0 if manifest.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
