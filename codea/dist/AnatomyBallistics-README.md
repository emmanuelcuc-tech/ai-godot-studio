# Anatomy Ballistics (Codea / iPad) — **1.1.0**

Sandbox soft-body **human anatomy** shot with real **.22 LR** ballistics tables. Ranges start at **40 ft** and step closer by **5 ft** to **15 ft**, then a **house-wall** stage (½″ drywall + pine stud + ½″ drywall). Organs run with heartbeat, brain activity, blood / bile / gastric fluids; bones use density-based fracture thresholds.

## Install

1. Download [`codea/dist/AnatomyBallistics.codea.zip`](../dist/AnatomyBallistics.codea.zip)
2. Unzip → copy `AnatomyBallistics.codea` into **On My iPad → Codea**
3. Open Codea → Play (landscape)

Or paste buffers from `codea/AnatomyBallistics/` (see `Info.plist` buffer order).

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

## Anatomy model (demo)

Soft-body humanoid (skin / muscle / bone / organs / vessels). Demo builds use a **denser cage** so the figure reads clearly on camera.

## Tests / campaign demo

```bash
lua codea/AnatomyBallistics/tests/smoke_test.lua
lua codea/AnatomyBallistics/tests/full_campaign_demo.lua
python3 codea/AnatomyBallistics/tests/render_model_demo.py
```

Full campaign runs **all** stages (40 → 35 → 30 → 25 → 20 → 15 → wall) with a short model intro, bright bullet marker, and organ labels.
