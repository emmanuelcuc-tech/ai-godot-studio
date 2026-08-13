# Audio Stem Studio

Windows **Godot 4.7** app: open any audio file, separate up to **8 stems** with **audio-separator**, mix with generic surround presets, tweak per-speaker **Gain (dB) / Volume / Pan / Amount / Latency**, and export in a chosen codec.

| | |
|---|---|
| **Project** | `C:\Users\kortn\Projects\ai-godot-studio\generated_games\audio_stem_studio` |
| **Godot** | `C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe` |
| **Main scene** | `res://scenes/main.tscn` |
| **Exe (after export)** | `build\AudioStemStudio.exe` |

## Run (Editor / no templates needed)

Double-click or run:

```bat
run.bat
```

Or:

```bat
"C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\kortn\Projects\ai-godot-studio\generated_games\audio_stem_studio"
```

## Dependencies

### Python + audio-separator

```bat
cd C:\Users\kortn\Projects\ai-godot-studio\generated_games\audio_stem_studio
pip install -r tools\requirements.txt
pip install audio-separator
:: optional NVIDIA CUDA acceleration:
pip install "audio-separator[gpu]"
```

Set `AUDIO_STEM_PYTHON` to a full `python.exe` path if `python` is not on PATH.

### ffmpeg

Install **ffmpeg** and **ffprobe** on PATH (decode any codec → WAV, export MP3/WAV/MPEG/FLAC/M4A/OGG, surround downmix). AC3 encode only if your ffmpeg build supports it.

## How Open Media + separation works

1. **Open Media…** → native file dialog (WAV, MP3, FLAC, OGG, M4A, MPEG, AC3, video containers, etc.).
2. Supported files **probe** then **auto-separate** into channel strips (no extra click). Unsupported extensions show a clear status error.
3. Probe shows **codec**, **bitrate**, **bit depth**, and **file type/container** for the opened media; each stem strip shows the same for its WAV/stem file.
4. Godot runs `tools/separate_tracks.py` via `OS.execute`.
5. Script uses `audio_separator.separator.Separator`:
   - `htdemucs_6s.yaml` (6 stems) when available
   - else `htdemucs.yaml` (4 stems)
   - else `UVR_MDXNET_KARA_2.onnx` (vocals / instrumental)
6. Results fill up to **8** labeled channel strips (waveform, spectrum, play/pause, format/bitrate, save).
7. Use **Re-Separate** to run separation again on the current file.
8. If audio-separator is missing, an **ffmpeg band-split fallback** still fills channels.

## Surround presets

Generic layout presets (not branded encoders):

- Stereo  
- 2.1 Surround  
- 5.1 Surround  
- 7.1 Surround  
- Matrix Surround (stereo → 5.1-style open matrix expand)  
- Cinema Wide 7.1  
- Headphones  

Source AC-3/E-AC-3/TrueHD/DTS decode is best-effort via ffmpeg.

## Default codec

**Default codec** dropdown sets the format/bitrate used for Save All / stem export:

- WAV (PCM)  
- MP3 128 / 256 / 512 kbps  
- MPEG  
- FLAC  
- M4A / AAC  
- OGG Vorbis  
- AC3 (if ffmpeg)

Export bitrate can still be overridden in Options / Mixer.

## Options / Mixer

- **Gain (dB)** — master, per-stem, per-speaker (−60…+12)  
- **Speaker volumes** — FL / FR / C / LFE / SL / SR / BL / BR  
- **Panning** — per stem / speaker  
- **Amount** — fill / send  
- **Latency** — target ms + AudioServer readout  
- Per-stem **Level / Volume / Pan / Reverb**  
- Downmix monitor: **7.1 → 5.1 → 2.1 → stereo**

## Build Windows .exe

1. Open the project once in Godot 4.7.1 (imports assets).  
2. **Editor → Manage Export Templates** → install **4.7.1-stable**.  
3. Run:

```bat
build_exe.bat
```

Or:

```bat
"C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe" --headless --path "C:\Users\kortn\Projects\ai-godot-studio\generated_games\audio_stem_studio" --export-release "Windows Desktop" "C:\Users\kortn\Projects\ai-godot-studio\generated_games\audio_stem_studio\build\AudioStemStudio.exe"
```

Preset file: `export_presets.cfg` → output `build/AudioStemStudio.exe`.

If templates are missing, export fails; use `run.bat` until templates are installed. The exported exe still needs **Python + audio-separator + ffmpeg** on the machine for ML separation and format convert.

## Project layout

```
audio_stem_studio/
  project.godot
  export_presets.cfg
  icon.svg
  README.md
  run.bat
  build_exe.bat
  scenes/main.tscn
  scripts/          # UI + backend glue
  tools/            # separate_tracks.py, export_stem.py, surround_mix.py, probe_media.py
```
