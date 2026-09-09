# Demolition Lab (Codea Craft 3D)

Brick-by-brick demolition sandbox with real material physics, blueprint buildings, orbit camera, and sequenced TNT.

## Features

- **2.5D / 3D Craft scene** of real-ish buildings (shed, glass office, brick highrise)
- **Photo textures** for wood, concrete, brick, steel, glass (`Textures/`)
- **Blueprints** drive every cell — brick-by-brick walls, independent glass panes
- **360° orbit + zoom** camera (drag / pinch / `+` `-`)
- **Unlimited TNT** — double-tap to place; placement position drives blast physics
- **Delay charges** — `0.0`–`0.9` seconds in `0.1` steps per charge
- **Pattern mode** — auto-space charges `0.1` s apart
- **Floor cascade** — whole floors sequence first → later
- **BOOM → outside cam → flashing ARM** — buzz + boom SFX scaled to yield
- **TNT standard** — `4184 J/g`, Kinney–Graham `Z = R / W^(1/3)` (`TNT.lua`)
- **Direct Comparison materials** — wood pyrolysis, concrete spall, glass shatter, steel bend (`Materials.lua`)

## Controls (iPad / Codea)

| Input | Action |
|--------|--------|
| Drag | Orbit camera 360° |
| Pinch / `+` `-` | Zoom |
| Double-tap | Place TNT (unlimited) |
| `[` `]` | Delay − / + (0.0–0.9 s) |
| `P` | Toggle pattern spacing |
| `F` | Floor cascade |
| `B` or **BOOM** | Pull exterior camera |
| Tap red **ARM** | Fire sequenced charges |
| `1` `2` `3` | Shed / Office / Highrise |
| `R` | Reset |

## Buffer order

1. `TNT`
2. `Materials`
3. `Blueprints`
4. `CameraOrbit`
5. `Building`
6. `Charges`
7. `Main`

## Install

See `HOW_TO_INSTALL.md` or use `codea/dist/DemolitionLab-COPY-PASTE.zip`.

## Browser preview

Open `browser/Demolition3D/index.html` (orbit, textures, double-tap TNT, delays, BOOM/ARM) — same design as the Craft project for quick testing without an iPad.
