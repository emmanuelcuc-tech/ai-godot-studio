# FL Studio scripts — Chrome Cannon Glass mixer

The snippets that mixed `import general` (MIDI) with `import flpianoroll` (piano roll) cannot run in one file. FL Studio loads them in **different sandboxes**. They are split and repaired here.

## 1. MIDI script — Master + all mixer volumes

Copy the folder into:

`Documents/Image-Line/FL Studio/Settings/Hardware/Chrome Cannon Glass/`

Files:

- `device_ChromeCannonGlass.py`
- `mixer_util.py`

Then in FL Studio: **Options → MIDI** → enable the device / assign this script.

| Control | Action |
|---------|--------|
| **CC7** channel 1 | **Master** volume |
| **CC7** other channels | Mixer tracks 1… |
| **CC64** (sustain down) | Set **all** tracks including Master to **80%** (unity) |
| Note-on | Select mixer track |

On start it prints `API Version: …` via `general.getVersion()`.

## 2. Piano roll script — all note velocities 80%

Copy `SetAllVelocities.py` into FL’s piano-roll scripts folder (Scripts menu in the piano roll).

Open a pattern, run the script. Every note is set to `velocity = 0.8`.

This file **must not** `import general` or define `OnInit` — those only exist in MIDI scripts.
