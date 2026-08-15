# Metallic Labyrinth (Codea)

Tilt your **iPad** to roll a **metallic ball** through a labyrinth. The **green goal** sits next to **red trap pits** — lean carefully.

## Install in Codea

1. Open **Codea** on your iPad.
2. Tap **+** → **New Project** → name it `MetallicLabyrinth`.
3. Delete the default `Main` buffer contents.
4. Copy these files from this folder into the project:
   - `Main.lua` → buffer **Main**
   - `Levels.lua` → add a new buffer named **Levels** (sidebar **+**) and paste
5. In project **Info** (or keep the included `Info.plist`), set buffer order: **Main**, then **Levels**.
6. Tap **Play** (triangle). Hold the iPad flat-ish, then tilt to roll.

### AirDrop / Files app shortcut

You can also copy the whole `MetallicLabyrinth` folder into Codea’s Documents via the Files app / Working Copy if you sync projects that way. Codea expects a project folder with `Info.plist` and `.lua` buffers.

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

## Files

- `Main.lua` — tilt physics, metallic drawing, HUD, win/lose
- `Levels.lua` — maze maps (`#` wall, `S` start, `G` goal, `T` trap, `B` bumper)
- `Info.plist` — Codea project metadata / buffer order
