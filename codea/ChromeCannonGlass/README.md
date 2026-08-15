# Chrome Cannon Glass (Codea / iPad)

Aim a **cannon**, fire a **chrome ball**, and watch it punch through **five spaced glass panes** with real **kinetic energy**, **shard destruction**, and **slow-motion** flight.

## Install on iPad (Codea)

1. Open **Codea** on your iPad.
2. Tap **+** → **New Project** → name it `ChromeCannonGlass`.
3. Clear the default `Main` buffer.
4. Copy from this folder:
   - `Main.lua` → buffer **Main**
   - `Glass.lua` → add a new buffer named **Glass** (sidebar **+**) and paste
5. Project **Info** / `Info.plist` buffer order: **Main**, then **Glass**.
6. Tap **Play**. Use landscape.

### Files app / Working Copy

Copy the whole `ChromeCannonGlass` folder into Codea’s Documents if you sync projects that way.

## Controls (iPad)

| Input | Action |
|--------|--------|
| **Drag** near the cannon (left side) | Aim barrel |
| **FIRE** button | Shoot chrome ball |
| **Tab** or **Space** (hardware keyboard) | Shoot |
| **RESET** button or **R** | Reload panes + ball |
| Sidebar **MuzzleSpeed** / **Fire** / **Reset** | Tune & fire |

## What you get

- Chrome ball launched from a wheeled cannon with **Box2D** physics
- **KE = ½mv²** decides whether a pane shatters; breaking costs energy
- **5 glass panes** in a row; each explodes into flying shards
- **Slow-mo** while the ball travels the glass corridor
- Touch-friendly FIRE / RESET for iPad (no keyboard required)

## Requirements

- Codea with classic 2D `physics` API (`physics.body`, `CIRCLE`, `POLYGON`, `collide`)
- Landscape orientation

## Files

- `Main.lua` — cannon, aim, fire, slow-mo, drawing, HUD
- `Glass.lua` — kinetic energy, pane layout, shard velocities, slow-mo factor
- `Info.plist` — Codea project metadata / buffer order
- `tests/smoke_test.lua` — headless math checks (`lua5.4 tests/smoke_test.lua`)
