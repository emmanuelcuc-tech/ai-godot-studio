# Demolition Lab 3D (Browser)

Playable Three.js preview of the Codea Craft **Demolition Lab**:

- Brick-by-brick blueprints (shed / office / highrise)
- Wood, concrete, brick, steel, glass photo textures
- Orbit camera 360° + zoom
- Double-tap/click to place unlimited TNT
- Delay 0.0–0.9 s, pattern spacing, floor cascade
- BOOM → exterior camera → flashing ARM → sequenced blasts

Open `index.html` in a desktop browser (needs network for Three.js CDN) or serve the folder:

```bash
python3 -m http.server 8765 -d browser/Demolition3D
```

Then visit `http://localhost:8765/`.
