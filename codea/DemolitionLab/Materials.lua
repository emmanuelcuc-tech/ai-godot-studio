-- Materials.lua
-- Structural / thermal / blast response grounded in the Direct Comparison Overview:
--   Wood  — no melt; pyrolysis ~280–300°C; anisotropic grain; poor blast (splits)
--   Concrete — brittle; high compression, ~0 tensile; spalls on blast back-face;
--              excellent blast only when steel-reinforced
--   Glass — amorphous glass-transition ~1400–1600°C; ~900 MPa theoretical compression
--           but surface flaws → tension shatter / shrapnel; very poor blast
--   Steel — melt ~1370–1540°C but ~50% strength loss by 500–600°C; ductile energy sink;
--           excellent blast (plastic deformation, not shatter)
-- TNT: 1 g = 4184 J; 1 ton = 4.184×10⁹ J. Blast uses Kinney–Graham Z = R / W^(1/3).

Materials = {}

Materials.ENERGY_SCALE = 0.00035
-- Synced with TNT.lua (loaded first). Exact standard equivalence:
Materials.TNT_J_PER_G = 4184
Materials.TNT_J_PER_TON = 4.184e9


--[[
  dens / friction / restitution — Codea body props
  compressiveMPa / tensileMPa — literature-scale references (relative use in-sim)
  compressive / tensile — normalized 0–2 game factors
  ductility — 0 brittle … 1 plastic bend
  grain — wood anisotropy (shear parallel to grain)
  fractureJ / crushJ — game energy thresholds
  blastWeak — overpressure damage multiplier
  pyroC — wood decomposition onset (°C); nil if N/A
  softenC — temp where structural strength collapses (steel ~550°C)
  meltC — melt / aggregate melt / glass transition midpoint
  shards / mode / color / points / note
]]
Materials.TYPES = {
    wood = {
        label = "Wood",
        dens = 0.70,
        friction = 0.65,
        restitution = 0.12,
        compressiveMPa = 40,  -- cross-grain compression is weak
        tensileMPa = 100,     -- along-grain tensile/flexural strong
        compressive = 0.55,   -- low cross-grain
        tensile = 0.70,       -- along grain; shock still catastrophic
        flexural = 1.15,      -- high flexural along grain
        ductility = 0.12,
        grain = 0.90,         -- splits if sheared parallel to grain
        fractureJ = 380,
        crushJ = 700,
        blastWeak = 1.45,     -- poor explosion resistance
        combustible = true,
        pyroC = 290,          -- pyrolysis / char — does NOT melt
        softenC = nil,
        meltC = nil,
        shards = 6,
        mode = "split",
        color = color(150, 105, 55),
        points = 45,
        note = "Anisotropic bio-polymer; pyrolysis ~280–300°C; blast splits & chars",
    },
    concrete = {
        label = "Concrete",
        dens = 1.60,
        friction = 0.78,
        restitution = 0.05,
        compressiveMPa = 40,  -- typical unreinforced (order-of-magnitude game scale)
        tensileMPa = 3,       -- nearly zero tensile
        compressive = 1.50,   -- massive compressive strength
        tensile = 0.12,       -- pulling/twisting snaps it
        flexural = 0.15,
        ductility = 0.04,
        grain = 0,
        fractureJ = 320,      -- fails early in tension
        crushJ = 2400,
        blastWeak = 1.15,     -- moderate–poor alone; front compresses, back spalls
        combustible = false,
        pyroC = nil,
        dehydrateC = 300,     -- loses structural water above ~300°C
        softenC = nil,
        meltC = 1375,         -- aggregates ~1200–1550°C
        shards = 5,
        mode = "spall",
        reinforced = false,
        color = color(160, 165, 175),
        points = 40,
        note = "Brittle composite; spalls on blast tension face unless rebar",
    },
    -- Steel-reinforced concrete: tensile steel carries blast tension → much better
    rebar = {
        label = "Rebar Concrete",
        dens = 1.85,
        friction = 0.75,
        restitution = 0.08,
        compressiveMPa = 45,
        tensileMPa = 35,      -- steel fibers/rebar supply tension capacity
        compressive = 1.55,
        tensile = 0.85,
        flexural = 0.80,
        ductility = 0.45,     -- some plastic give from steel
        grain = 0,
        fractureJ = 1600,
        crushJ = 2800,
        blastWeak = 0.45,     -- excellent when paired with steel
        combustible = false,
        pyroC = nil,
        dehydrateC = 300,
        softenC = 550,        -- embedded steel softens ~500–600°C
        meltC = 1375,
        shards = 3,
        mode = "bend",        -- yields before clean shatter
        reinforced = true,
        color = color(130, 140, 150),
        points = 35,
        note = "Reinforced: steel takes tensile/blast face; ductile composite",
    },
    glass = {
        label = "Glass",
        dens = 0.55,
        friction = 0.18,
        restitution = 0.03,
        compressiveMPa = 900, -- theoretical extreme compression
        tensileMPa = 30,      -- practical: surface micro-fractures dominate
        compressive = 1.70,
        tensile = 0.06,       -- stress at crack tips → sudden shatter
        flexural = 0.08,
        ductility = 0.0,
        grain = 0,
        fractureJ = 110,
        crushJ = 1800,
        blastWeak = 1.90,     -- very poor; lethal shrapnel
        combustible = false,
        pyroC = nil,
        softenC = nil,
        meltC = 1500,         -- glass transition ~1400–1600°C (no sharp MP)
        glassTransition = true,
        tempered = false,
        laminated = false,
        shards = 10,
        mode = "shatter",
        color = color(140, 210, 230),
        points = 80,
        note = "Amorphous; tension shatter from surface flaws; awful blast",
    },
    -- Tempered / laminated glass (optional blueprint char)
    glass_safe = {
        label = "Laminated Glass",
        dens = 0.62,
        friction = 0.2,
        restitution = 0.05,
        compressiveMPa = 900,
        tensileMPa = 80,
        compressive = 1.70,
        tensile = 0.35,       -- tempering + PVB interlayer
        flexural = 0.40,
        ductility = 0.2,      -- interlayer holds fragments
        grain = 0,
        fractureJ = 520,
        crushJ = 1800,
        blastWeak = 0.85,
        combustible = false,
        meltC = 1500,
        glassTransition = true,
        tempered = true,
        laminated = true,
        shards = 4,           -- held chunks, not razor spray
        mode = "crumble",
        color = color(160, 220, 235),
        points = 60,
        note = "Tempered + PVB: fragments held; better blast than annealed",
    },
    steel = {
        label = "Steel",
        dens = 2.40,
        friction = 0.42,
        restitution = 0.22,
        compressiveMPa = 250,
        tensileMPa = 400,     -- balanced high tension + compression
        compressive = 1.40,
        tensile = 1.45,
        flexural = 1.30,
        ductility = 0.95,     -- plastic deformation absorbs blast KE
        grain = 0,            -- isotropic
        fractureJ = 3200,     -- bends long before snap
        crushJ = 3400,
        blastWeak = 0.28,     -- excellent blast resistance
        combustible = false,
        pyroC = nil,
        softenC = 550,        -- ~50% strength loss ~500–600°C (buckles before melt)
        meltC = 1455,         -- ~1370–1540°C by alloy
        shards = 2,
        mode = "bend",
        color = color(120, 130, 145),
        points = 30,
        note = "Ductile isotropic alloy; bends under blast instead of collapsing",
    },
    brick = {
        label = "Brick",
        dens = 1.20,
        friction = 0.75,
        restitution = 0.08,
        compressiveMPa = 20,
        tensileMPa = 2.5,
        compressive = 0.95,
        tensile = 0.20,
        flexural = 0.18,
        ductility = 0.04,
        grain = 0.1,
        fractureJ = 300,
        crushJ = 1000,
        blastWeak = 1.20,
        combustible = false,
        meltC = 1200,
        shards = 4,
        mode = "crumble",
        color = color(190, 85, 55),
        points = 55,
        note = "Masonry units; independent bricks crumble at joints",
    },
}

Materials.CHAR_MAP = {
    W = "wood",
    C = "concrete",
    R = "rebar",       -- reinforced concrete
    G = "glass",
    L = "glass_safe",  -- laminated / tempered
    S = "steel",
    B = "brick",
}

function Materials.get(id)
    return Materials.TYPES[id] or Materials.TYPES.brick
end

function Materials.fromChar(ch)
    return Materials.CHAR_MAP[ch] or "brick"
end

-- Volume m³ × density factor → approximate kg for Craft rigidbody mass.
function Materials.estimateMass(kind, volumeM3)
    local mat = Materials.get(kind)
    local dens = mat.dens or 1.0
    -- dens is relative; scale to ~kg for game-sized 0.5 m cells
    return math.max(0.5, dens * (volumeM3 or 0.1) * 2200)
end

-- Blast response for Demolition Lab (Craft / sequenced TNT).
-- Uses Kinney–Graham intensity + Direct Comparison material failure.
function Materials.evaluateBlast(kind, opts)
    opts = opts or {}
    local mat = Materials.get(kind)
    local intensity = opts.intensity or 0
    local pKpa = opts.overpressure or 0
    local energy = intensity * Materials.ENERGY_SCALE * (0.35 + (opts.thickness or 0.2))
    -- Blast is tension/spall dominated on free faces
    local tensionFactor = 0.72
    if mat.mode == "shatter" or kind == "glass" or kind == "glass_safe" then
        tensionFactor = 0.95
    elseif mat.reinforced then
        tensionFactor = 0.45
    elseif mat.ductility and mat.ductility > 0.5 then
        tensionFactor = 0.35
    end
    local ratio = Materials.failureStress(mat, energy + pKpa * 8, tensionFactor, opts.heatC)
    local fail = ratio >= 1
    local dent = (not fail) and ratio >= 0.55 and (mat.ductility or 0) > 0.4
    local shatter = fail and (mat.mode == "shatter" or kind == "glass")
    local spall = fail and mat.mode == "spall"
    local crumble = fail and mat.mode == "crumble"
    local soften = mat.softenC and (opts.heatC or 20) >= mat.softenC
    return {
        fail = fail,
        fracture = fail and not shatter,
        shatter = shatter,
        spall = spall,
        crumble = crumble,
        dent = dent,
        soften = soften,
        shards = shatter and (mat.shards or 8) or 0,
        ratio = ratio,
        mode = mat.mode,
    }
end

function Materials.impactEnergy(speed, densA, densB)
    local mu = (densA * densB) / math.max(0.05, densA + densB)
    local ke = 0.5 * mu * (speed * speed)
    return ke * Materials.ENERGY_SCALE * 1000
end

-- Heat softens steel / rebar long before melt (game: optional ambientHeatC).
function Materials.heatFactor(mat, ambientHeatC)
    local T = ambientHeatC or 20
    if mat.softenC and T >= mat.softenC then
        -- ~50% strength loss near softenC, worse as T rises toward melt
        local melt = mat.meltC or (mat.softenC + 900)
        local u = math.min(1, (T - mat.softenC) / math.max(1, melt - mat.softenC))
        return 0.5 * (1 - 0.7 * u) -- 0.5 → ~0.15
    end
    if mat.pyroC and T >= mat.pyroC then
        -- Wood chars / decomposes — loses section capacity
        return 0.25
    end
    if mat.dehydrateC and T >= mat.dehydrateC and not mat.reinforced then
        return 0.7
    end
    return 1
end

-- Tension/shear vs compression. Blast uses high tensionFactor (spall back-face).
function Materials.failureStress(mat, energy, tensionFactor, ambientHeatC)
    local t = math.max(0, math.min(1, tensionFactor or 0.55))
    local c = 1 - t
    local heat = Materials.heatFactor(mat, ambientHeatC)
    local tensile = mat.tensile * heat
    local compressive = mat.compressive * heat
    -- Along-grain wood resists flex better when load is not shock-dominated
    if mat.flexural and t < 0.4 then
        tensile = tensile * (0.7 + 0.3 * mat.flexural)
    end
    local resist = tensile * (0.35 + 0.65 * t) * mat.fractureJ
        + compressive * (0.25 + 0.75 * c) * mat.crushJ * 0.15
    -- Grain: shear parallel to fibers (shock) collapses resistance
    resist = resist * (1 - mat.grain * t * 0.55)
    return energy / math.max(1, resist)
end

-- Bridge Materials blast helpers to TNT module (single source of truth).
function Materials.blastImpulseAt(distanceM, tntKg)
    return TNT.peakOverpressureKpa(distanceM, tntKg)
end

function Materials.blastSurfaceIntensity(yieldJ, radiusM)
    return TNT.surfaceIntensity(yieldJ, radiusM)
end

function Materials.tntGramsToJoules(grams)
    return TNT.gramsToJoules(grams)
end

function Materials.tntTonsToJoules(tons)
    return TNT.tonsToJoules(tons)
end

function Materials.tntGramsToGameJoules(grams)
    return TNT.gramsToJoules(grams) * Materials.ENERGY_SCALE
end

-- Keep legacy constants equal to TNT module
Materials.TNT_J_PER_G = TNT.J_PER_G
Materials.TNT_J_PER_TON = TNT.J_PER_TON

-- HUD / encyclopedia rows
function Materials.comparisonRows()
    return {
        { "Wood", "No melt (pyrolysis ~290°C)", "Flex/tensile along grain", "Poor — splits on shock" },
        { "Concrete", "~1200–1550°C aggregates", "High compression / ~0 tensile", "Poor alone — spalls" },
        { "Rebar Conc.", "Same + steel soften ~550°C", "Steel carries tension", "Good–excellent" },
        { "Glass", "Transition ~1400–1600°C", "High crush / flaw tension", "Very poor — shrapnel" },
        { "Steel", "Melt ~1370–1540°C", "Ductile tension+compression", "Excellent — bends" },
        { "Brick", "~1200°C", "Masonry compression", "Poor — crumbles" },
    }
end
