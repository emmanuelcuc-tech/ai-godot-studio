# Anatomy Ballistics (Codea / iPad) — **1.1.0**

Sandbox soft-body **human anatomy** shot with real **.22 LR** ballistics tables. Ranges start at **40 ft** and step closer by **5 ft** to **15 ft**, then a **house-wall** stage (½″ drywall + pine stud + ½″ drywall). Organs run with heartbeat, brain activity, blood / bile / gastric fluids; bones use density-based fracture thresholds.

## One-file download (iPad, no PC)

Download **[AnatomyBallistics.codea.zip](../dist/AnatomyBallistics.codea.zip)** — that is the only file you need.

1. On the iPad, tap the zip in Safari / Files to unzip it.
2. Copy `AnatomyBallistics.codea` into **Files → On My iPad → Codea**.
3. Open **Codea** → tap **AnatomyBallistics** → **Play** (landscape).
4. Drag to aim, double-tap to fire.

Paste fallback: [AnatomyBallistics.lua](../dist/AnatomyBallistics.lua) is the same game in one buffer. New Codea project → replace Main → Play.

Rebuild the zip after editing source:

```bash
python3 codea/pack_anatomy_ballistics.py
```

## Controls

| Input | Action |
|--------|--------|
| **Drag** | Red semi-opaque aim reticle |
| **Double-tap** | Fire .22 LR (3s cooldown) |
| **RESET** / **R** | Rebuild body; restart at 40 ft |
| **NEXT** / **N** | Advance range stage manually |
| Sidebar **AutoAdvance** | After impact, step 5 ft closer (default on) |

## Stages (.22 LR HV 40 gr reference)

Open air (Thunderbolt-class ~1255 fps / 140 ft·lbf muzzle, interpolated):

| Stage | Range | Typical impact |
|-------|-------|----------------|
| 1–6 | 40 → 15 ft (step 5) | ~1220–1250 fps · ~133–140 ft·lbf |
| 7 | Wall @ 12 ft | Barrier **−270 fps** (2×45 drywall + 180 stud) → ~975 fps |

**Sources (engineering tables in `TwentyTwo.lua`):**
- ShootersCalculator G1 BC 0.122 standard-velocity 40 gr chart
- Remington Thunderbolt-class HV 40 gr (~1255 fps / 140 ft·lbf)
- Haag-scale drywall loss ≈ 12–15 m/s (≈39–49 fps) per ½″ sheet

## Systems

- **Organs:** brain, heart, lungs, liver, gallbladder, stomach, kidneys, spleen — integrity drives HR, BP, SpO₂, bile flow, renal/filtration
- **Bones:** skull / rib / vertebra / long / pelvis density & fracture energy (`.22` crush wounding; minimal temporary cavity)
- **Fluids:** circulating blood; bile / gastric gush when those organs tear
- **Cameras:** side trail → overhead → slow-mo follow → impact

## Files

| Buffer | Role |
|--------|------|
| `Main` | Input, stages, vitals HUD, wall FX |
| `TwentyTwo` | Real .22 LR tables + wall Δv |
| `Bones` / `Organs` / `Stages` | Anatomy physiology + progression |
| `Ballistics` / `SoftBody` / `Blood` / `Anatomy` / `Camera` | Sim core |

## Tests

```bash
lua5.4 codea/AnatomyBallistics/tests/smoke_test.lua
```
