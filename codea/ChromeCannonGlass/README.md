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
2. Paste `Main.lua` → **Main**, `Glass.lua` → new buffer **Glass**.
3. Buffer order: **Main**, then **Glass** → Play.

## Controls (iPad)

| Input | Action |
|--------|--------|
| **Drag** near the cannon (left side) | Aim barrel |
| **FIRE** button | Shoot chrome ball |
| **Tab** or **Space** (hardware keyboard) | Shoot |
| **RESET** button or **R** | Reload panes + ball |
| Sidebar **InputGain** / **OutputVolume** | Tweaking either **resets** the main-screen glass |
| Sidebar **LoudnessBreak** | How loud is “too loud” |
| **Yell into mic** or **crank output + FIRE** | Main screen glass shatters and flies away |

## What you get

- Chrome ball launched from a wheeled cannon with **Box2D** physics
- **KE = ½mv²** decides whether a pane shatters; breaking costs energy
- **5 glass panes** in a row; each explodes into flying shards
- **Slow-mo** while the ball travels the glass corridor
- **Main-screen glass overlay** — shatters when **mic input** or **speaker output** is too loud
- Tweaking **InputGain** or **OutputVolume** always **resets** the screen glass
- Touch-friendly FIRE / RESET for iPad (no keyboard required)

## Requirements

- Codea with classic 2D `physics` API (`physics.body`, `CIRCLE`, `POLYGON`, `collide`)
- Landscape orientation

## Files

| Path | Purpose |
|------|---------|
| `codea/dist/ChromeCannonGlass.codea.zip` | **Download this** → unzip → drop into Codea |
| `codea/dist/ChromeCannonGlass.codea/` | Unzipped project package |
| `Main.lua` / `Glass.lua` | Source buffers |
| `Info.plist` | Buffer order + metadata |
| `tests/smoke_test.lua` | Headless math checks |
