# Chrome Cannon Glass (Codea / iPad)

Aim a **cannon**, fire a **chrome ball**, and watch it punch through **five spaced glass panes** with real **kinetic energy**, **shard destruction**, and **slow-motion** flight.

## Download & load (easiest)

1. Download **[`codea/dist/ChromeCannonGlass.codea.zip`](../dist/ChromeCannonGlass.codea.zip)** (also on the PR / release artifacts).
2. On your iPad, unzip so you get a folder named **`ChromeCannonGlass.codea`**.
3. Open the **Files** app → **On My iPad** → **Codea**.
4. Copy **`ChromeCannonGlass.codea`** into that Codea folder (Share → Save to Files, or drag).
5. Open **Codea** — the project shows on the home screen.
6. Tap it → **Play** (landscape).

> The `.codea` folder name matters — Codea treats folders ending in `.codea` as projects.

## Manual paste (alternate)

1. Open **Codea** → **+** → **New Project** → `ChromeCannonGlass`.
2. Paste:
   - `Main.lua` → **Main**
   - `Glass.lua` → **Glass**
   - `Mixer.lua` → **Mixer**
   - `GpuRam.lua` → **GpuRam**
3. Buffer order: **Main**, **Glass**, **Mixer**, **GpuRam** → Play.

## Controls (iPad)

| Input | Action |
|--------|--------|
| **Drag** near the cannon (left side) | Aim barrel |
| **FIRE** button | Shoot chrome ball |
| **Tab** or **Space** (hardware keyboard) | Shoot |
| **RESET** button or **R** | Reload panes + ball |
| **SETTINGS** tab | Opens audio settings |
| **INPUT AUDIO** tab (or **I**) | Mic / input gain — twist INPUT knob or fader |
| **OUTPUT AUDIO** tab (or **O**) | Speaker / output — twist OUTPUT and FX knobs |
| **SET ALL 80%** | All faders including Master → unity (0.8) |
| **Tab** | Shoot on PLAY · back to PLAY from MIXER |
| **RESET** button or **R** | Reload panes + ball |
| **Describe to song or audio** | Tap the field next to Record melody / Hum instrument, type a prompt |
| **RECORD MELODY** | Mic-capture ~3.6s of notes, then play them back |
| **HUM INSTRUMENT** | Hold a hummed tone to make a playback instrument |
| Sidebar **HighPerformance** | On = GPU/RAM pool + heavier physics (saved) |
| **Yell into mic** | Red MIC lamp flashes / stays lit; IN column height = volume |
| **FIRE / playback** | OUT column height = speaker volume |

## What you get

- Chrome ball launched from a wheeled cannon with **Box2D** physics
- **KE = ½mv²** decides whether a pane shatters; breaking costs energy
- **5 glass panes** in a row; each explodes into flying shards
- **Slow-mo** while the ball travels the glass corridor
- **Describe to song or audio** field next to **Record melody** and **Hum instrument** (mic capture → playback)
- **MIXER page** (Fruity Loops–style) — **Master** plus every bus volume
- **Main-screen glass overlay** — shatters when **mic input** or **speaker output** is too loud
- **Black leather** backdrop with pebble grain and stitching
- **Neon tube type** cycling bright blue → pink → red (**slow**, ~31s per cycle; sidebar **NeonSpeed**)
- **GPU/RAM pool** — 2× leather atlas, bloom ping-pong, glow, and scratch textures (tens of MB of VRAM)
- Tweaking **any mixer fader** always **resets** the screen glass
- **Save / Load** (sidebar + auto-save on mixer tweak / exit) — **Save** always stores **high performance mode**
- Touch-friendly FIRE / RESET for iPad (no keyboard required)

FL Studio scripts (repaired `import general` vs `flpianoroll`): `flstudio/ChromeCannonGlass/`

## Requirements

- Codea with classic 2D `physics` API (`physics.body`, `CIRCLE`, `POLYGON`, `collide`)
- Landscape orientation

## Files

| Path | Purpose |
|------|---------|
| `codea/dist/ChromeCannonGlass.codea.zip` | **Download this** → unzip → drop into Codea |
| `codea/dist/ChromeCannonGlass.codea/` | Unzipped project package |
| `Main.lua` / `Glass.lua` / `Mixer.lua` / `GpuRam.lua` | Source buffers |
| `Info.plist` | Buffer order + metadata |
| `tests/smoke_test.lua` | Headless math checks |
| `flstudio/ChromeCannonGlass/` | FL Studio MIDI mixer + piano-roll velocity scripts |
