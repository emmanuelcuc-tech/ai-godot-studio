# Demolition — Flash Game

HTML5 browser arcade in classic **Flash** style (no plugin).

## Play

```bash
python3 -m http.server 8785 --directory browser/DemolitionFlash
```

Open `http://localhost:8785/` or open `index.html` directly.

## Features

- Title / How To / Game Over / Mission Clear screens
- Wrecking-ball slingshot (drag & fling)
- **TNT** plant mode + **BOOM** with 0.1s delay between charges
- Brick / wood / glass / concrete / steel scoring
- Clear **62%** of each structure to advance (5 stages)
- High score via `localStorage`
- Beveled Flash UI + Web Audio blips

Based on the Codea Demolition material physics demo, wrapped as a score-attack arcade game.
