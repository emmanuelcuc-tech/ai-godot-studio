# Anatomy Ballistics — Flash Game

HTML5 browser game in classic **Flash arcade** style (no Flash plugin — works in Safari / Chrome / iPad).

## Play

Open `index.html`, or serve:

```bash
python3 -m http.server 8780 --directory browser/AnatomyFlash
```

Then visit `http://localhost:8780/`.

## Features

- Title / How To / Game Over / Mission Clear screens
- Score, combo multipliers, high score (`localStorage`)
- 3 rounds of .22 LR per stage (40→15 ft, then house wall)
- Soft-body anatomy + organ hit scoring
- Beveled Flash-era UI, Bangers/VT323 fonts, Web Audio blips
- Drag aim · **FIRE** / Space / double-tap

Same ballistics tables as the Codea / Safari sandbox, wrapped as a score-attack arcade game.
