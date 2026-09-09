# Anatomy Ballistics (Codea / iPad)

Sandbox: a **soft-body human anatomy** figure you shoot with **real bullet velocity**, **fabric-like skin tear**, **elastic muscle**, **cracking bones**, and **circulating / gushing blood**. Cinematic cameras track each round from **side trail** → **overhead contact** → **slow-mo follow** into impact. **RESET** rebuilds the body.

## Install in Codea

1. Open **Codea** on your iPad.
2. Tap **+** → **New Project** → name it `AnatomyBallistics`.
3. Create buffers and paste from this folder:

| File | Buffer name |
|------|-------------|
| `Main.lua` | **Main** |
| `Vec3.lua` | **Vec3** |
| `Ballistics.lua` | **Ballistics** |
| `SoftBody.lua` | **SoftBody** |
| `Blood.lua` | **Blood** |
| `Anatomy.lua` | **Anatomy** |
| `Camera.lua` | **Camera** |

4. Project **Info** buffer order: **Main**, **Vec3**, **Ballistics**, **SoftBody**, **Blood**, **Anatomy**, **Camera** (or use the included `Info.plist`).
5. Tap **Play** (landscape).

### Files app shortcut

Copy the whole `AnatomyBallistics` folder (or a renamed `AnatomyBallistics.codea` package) into Codea’s Documents via the Files app / Working Copy.

## Controls

| Input | Action |
|--------|--------|
| **Drag finger** | Move the **red semi-opaque aim dot** |
| **Double-tap** | Fire one bullet from your view (**3 second** discharge cooldown) |
| **RESET** button / **R** | Rebuild anatomy + blood circulation |
| **Space** / **Tab** (keyboard Viewer) | Fire at current aim |
| Sidebar **Fire Test Shot** | Fire without double-tap |
| Sidebar **ShowBones / ShowOrgans / ShowBlood** | Layer toggles |
| Sidebar **GoreIntensity** | Tear radius / blood spray scale |

## What you get

- **3D perspective** aim camera with touch reticle
- **Bullet physics**: velocity, mild gravity, drag, kinetic energy on hit
- **One shot every 3 seconds**
- **Cinematic sequence** on each shot:
  1. **Side trail** — 2D-ish view with **red trajectory line**
  2. **Overhead** — contact approach
  3. **Slow-mo follow** — camera behind the round into impact
- **Skin** as tight fabric springs that stretch and rip
- **Muscle** as strong elastic binds holding tissue / organs
- **Bones** that crack and break under high strain / KE
- **Organs** (heart, lungs, liver, stomach) as soft clusters
- **Blood** particles circulating in vessels; ruptured vessels **gush** red liquid with cohesion / viscosity
- Sandbox loop: shoot until **RESET**

## Requirements

- Codea classic API (`setup` / `draw` / `touched`, `ellipse`, `line`, `triangle`, `parameter.*`)
- Landscape orientation recommended

## Files

- `Main.lua` — input, sim loop, drawing, HUD
- `Vec3.lua` — 3D math
- `Ballistics.lua` — bullet, cooldown, double-tap, cinematic phases
- `SoftBody.lua` — Verlet fabric / muscle / bone tearing
- `Blood.lua` — circulation + liquid gush
- `Anatomy.lua` — figure construction
- `Camera.lua` — perspective + shot cameras
- `tests/smoke_test.lua` — headless physics checks

## Note on fidelity

This is a **real-time mobile approximation** (Verlet soft body + particle liquid), not offline VFX film sim. It is tuned to stay playable on iPad while still showing stretch, tear, crack, and blood flow.
