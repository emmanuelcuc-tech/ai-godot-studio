# FL Studio scripts (follows `flstudio/SKILL.md`)

Three **separate** contexts — do not mix modules across files.

| Context | Modules | This repo |
|---------|---------|-----------|
| MIDI controller | `general`, `mixer`, `device`, `transport`, … | `device_ChromeCannonGlass.py` |
| Piano roll | `flpianoroll`, `enveditor` | `Shared/Python/User Scripts/SetAllVelocities.py` |
| Edison | `enveditor` | `Shared/Python/User Scripts/EdisonReady.py` |

## MIDI — Master + all mixer volumes

Copy to:

`Documents/Image-Line/FL Studio/Settings/Hardware/Chrome Cannon Glass/device_ChromeCannonGlass.py`

Enable in **Options → MIDI**.

On start:

```text
API Version: …
Connected: …
```

| Control | Action |
|---------|--------|
| **CC7** | Volume of the **current** mixer track (`mixer.trackNumber()`) |
| **CC8** | **Master** volume (track `0`) |
| **CC64** | Set **all** tracks including Master to **0.8** (unity) |
| Note-on | `mixer.setActiveTrack(note % 8)` |
| `OnRefresh` | Echo Master volume back to the controller (CC7 ch1) |

## Piano roll — all note velocities 80%

Copy to:

`Shared\Python\User Scripts\SetAllVelocities.py`

Open a pattern in the piano roll, then run it from the **Scripts** menu.

```python
import flpianoroll
score = flpianoroll.score
for note in score.notes:
    note.velocity = 0.8
```

## Skill

Full API map: [`SKILL.md`](../SKILL.md) (FL Studio 20.8.4+, Python 3.6+).
