# Vintage Typewriter

Godot **4.7** photo-based Royal Quiet De Luxe simulator.

## Launch

```text
"C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\kortn\Projects\ai-godot-studio\generated_games\vintage_typewriter"
```

## What it does

- **Photo machine** — `royal_machine.png` body with kraft `paper.png` in the carriage
- **Keys** — printable characters, Space, Enter/Return, Backspace, Tab, Shift; click hotspots or type on the hardware keyboard; visual depress + typebar strike + ink blot
- **Carriage** — advances per character, returns/line-feeds on Enter, slides left as you type; **margin bell** near end of line (col 35/42)
- **SFX** — Freesound sliced clicks by default; optional TypingSimulator switch packs in Settings
- **Auto-type** — Start / Pause / End + Speed 1–30 (delay `max(0.03, 0.5/speed)`); Type From File (`.txt`)
- **Views** — Follow, Full, All Paper, Keys, Bottom Close
- **Settings** — ink color, font color/size/style, sound source (persisted)

## Controls

| Action | How |
|--------|-----|
| Type | Hardware keyboard or on-photo key hotspots |
| Start / Pause / End | Bottom control bar |
| Speed | Slider 1–30 |
| Type From File | Load `.txt` then auto-type |
| Views | Top bar buttons |
| Settings | Ink, font, sound pack |

## Assets

- Body: `assets/images/royal_machine.png`
- Paper: `assets/images/paper.png`
- Keys: UV hotspots in `scripts/photo_key_layout.gd`
- Typebars: `scripts/typebar_basket.gd`
