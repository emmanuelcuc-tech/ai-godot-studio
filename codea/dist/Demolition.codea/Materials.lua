-- Materials.lua
-- Real-world-inspired structural / blast response for Demolition blocks.
-- Sources summarized in-project (wood anisotropic, concrete brittle/spall,
-- glass tension-limited shatter, steel ductile energy sink).
-- TNT reference: 1 g TNT = 4184 J; 1 ton TNT = 4.184e9 J.

Materials = {}

-- Game energy unit ≈ joules * ENERGY_SCALE (keeps Codea velocities playable)
Materials.ENERGY_SCALE = 0.00035
Materials.TNT_J_PER_G = 4184
Materials.TNT_J_PER_TON = 4.184e9

--[[
  dens        relative density (physics.density)
  friction / restitution
  compressive  relative resistance to squeeze (high = hard to crush)
  tensile      relative resistance to pull/bend/shock tension (glass/concrete low)
  ductility    0 = brittle shatter, 1 = plastic bend (steel)
  grain        wood anisotropy: shear weakness parallel to grain (0–1)
  fractureJ    impact energy (game J) to initiate break under tension/shear
  crushJ       energy needed to crush under pure compression
  blastWeak    multiplier on blast overpressure damage (wood/glass high)
  shards       fragments spawned on catastrophic failure
  mode         primary failure visual: shatter | split | spall | bend | crumble
]]
Materials.TYPES = {
    wood = {
        label = "Wood",
        dens = 0.70,
        friction = 0.65,
        restitution = 0.12,
        compressive = 0.75,
        tensile = 0.55, -- along grain; shock still bad
        ductility = 0.15,
        grain = 0.85, -- splits along grain under shear/shock
        fractureJ = 420,
        crushJ = 900,
        blastWeak = 1.35,
        shards = 5,
        mode = "split",
        color = color(150, 105, 55),
        points = 45,
        meltC = nil, -- decomposes ~280–300 C (pyrolysis), no melt
        note = "Anisotropic; splits on shock; poor blast",
    },
    concrete = {
        label = "Concrete",
        dens = 1.60,
        friction = 0.78,
        restitution = 0.06,
        compressive = 1.45, -- strong in compression
        tensile = 0.18, -- nearly zero tensile → spall
        ductility = 0.05,
        grain = 0,
        fractureJ = 380, -- fails early in tension
        crushJ = 2200,
        blastWeak = 1.10,
        shards = 4,
        mode = "spall",
        color = color(160, 165, 175),
        points = 40,
        meltC = 1400,
        note = "Brittle; spalls on blast tension face",
    },
    glass = {
        label = "Glass",
        dens = 0.55,
        friction = 0.18,
        restitution = 0.04,
        compressive = 1.60, -- theoretical high compression
        tensile = 0.08, -- surface flaws → instant shatter
        ductility = 0.0,
        grain = 0,
        fractureJ = 140,
        crushJ = 1600,
        blastWeak = 1.80,
        shards = 9,
        mode = "shatter",
        color = color(140, 210, 230),
        points = 80,
        meltC = 1500, -- glass transition, not sharp MP
        note = "Tension/shatter; lethal shards; awful blast",
    },
    steel = {
        label = "Steel",
        dens = 2.40,
        friction = 0.42,
        restitution = 0.22,
        compressive = 1.35,
        tensile = 1.40,
        ductility = 0.92, -- plastic deformation absorbs blast KE
        grain = 0,
        fractureJ = 2800, -- rarely snaps; bends first
        crushJ = 3200,
        blastWeak = 0.35,
        shards = 2,
        mode = "bend",
        color = color(120, 130, 145),
        points = 30,
        meltC = 1450, -- strength loss ~500–600 C before melt
        note = "Ductile energy sink; excellent blast",
    },
    brick = {
        label = "Brick",
        dens = 1.20,
        friction = 0.75,
        restitution = 0.09,
        compressive = 0.95,
        tensile = 0.22,
        ductility = 0.05,
        grain = 0.1,
        fractureJ = 320,
        crushJ = 1100,
        blastWeak = 1.15,
        shards = 4,
        mode = "crumble",
        color = color(190, 85, 55),
        points = 55,
        meltC = 1200,
        note = "Masonry crumble; brittle joints",
    },
}

Materials.CHAR_MAP = {
    W = "wood",
    C = "concrete",
    G = "glass",
    S = "steel",
    B = "brick",
}

function Materials.get(id)
    return Materials.TYPES[id] or Materials.TYPES.brick
end

function Materials.fromChar(ch)
    return Materials.CHAR_MAP[ch] or "brick"
end

-- Relative impact kinetic energy from contact closing speed & mass proxy.
function Materials.impactEnergy(speed, densA, densB)
    local mu = (densA * densB) / math.max(0.05, densA + densB)
    local ke = 0.5 * mu * (speed * speed)
    return ke * Materials.ENERGY_SCALE * 1000 -- game joules
end

-- Tension/shear vs compression bias from relative velocity direction.
-- Higher tensionFactor → brittle materials fail sooner.
function Materials.failureStress(mat, energy, tensionFactor)
    local t = math.max(0, math.min(1, tensionFactor or 0.55))
    local c = 1 - t
    -- Effective resistance mixes tensile (shock) and compressive paths
    local resist = mat.tensile * (0.35 + 0.65 * t) * mat.fractureJ
        + mat.compressive * (0.25 + 0.75 * c) * mat.crushJ * 0.15
    -- Grain weakness (wood): shock raises effective load
    resist = resist * (1 - mat.grain * t * 0.45)
    return energy / math.max(1, resist)
end

function Materials.blastImpulseAt(distanceM, tntKg)
    -- Kinney–Graham scaled distance Z = R / W^(1/3), W in kg TNT
    local W = math.max(0.001, tntKg)
    local R = math.max(0.15, distanceM)
    local Z = R / (W ^ (1 / 3))
    -- Simplified peak overpressure (kPa) curve fit for game use
    local pKpa = 700 / (Z * Z + 0.4) + 40 / (Z + 0.15)
    return pKpa
end

function Materials.tntGramsToGameJoules(grams)
    return grams * Materials.TNT_J_PER_G * Materials.ENERGY_SCALE
end
