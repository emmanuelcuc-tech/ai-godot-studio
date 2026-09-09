# Metallic Labyrinth (Codea)

Tilt your **iPad** to roll a **metallic ball** through a labyrinth. The **green goal** sits next to **red trap pits** — lean carefully.

## One-file download (iPad, no PC)

Download **[MetallicLabyrinth.codea.zip](../dist/MetallicLabyrinth.codea.zip)** — that is the only file you need.

1. On the iPad, tap the zip in Safari / Files to unzip it.
2. Copy `MetallicLabyrinth.codea` into **Files → On My iPad → Codea**.
3. Open **Codea** → tap **MetallicLabyrinth** → **Play**.
4. Hold the iPad almost flat, then tilt to roll.

Paste fallback: [MetallicLabyrinth.lua](../dist/MetallicLabyrinth.lua) is the same game in one buffer. New Codea project → replace Main → Play.

Rebuild the zip after editing source:

```bash
python3 codea/pack_metallic_labyrinth.py
```

## Controls

| Input | Action |
|--------|--------|
| **Tilt iPad** | Rolls the chrome ball (`Gravity`) |
| **Drag finger** | Push assist when the device is flat or in the Mac Viewer |
| **Tap** after win | Next maze |
| **Tap** after lives gone | Retry level |
| Sidebar **Level** / **Restart** / **Next** | Jump levels |

## Gameplay

- **4 mazes** — walls, chrome ball, green cup, red pits
- **3 lives** — falling in a trap costs one; ball respawns at start
- **Bumpers** (orange) bounce hard on later levels
- Goal is intentionally placed **beside traps** so precision tilting matters

## Requirements

- Codea with classic 2D `physics` API (`physics.body`, `Gravity`, `CIRCLE`, `POLYGON`)
- Landscape orientation recommended

## Source files

- `Main.lua` — tilt physics, metallic drawing, HUD, win/lose
- `Levels.lua` — maze maps (`#` wall, `S` start, `G` goal, `T` trap, `B` bumper)
- `Info.plist` — Codea project metadata / buffer order
- `../dist/MetallicLabyrinth.codea.zip` — packed one-file install
