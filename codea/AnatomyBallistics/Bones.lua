-- Bones.lua
-- Cortical density / strength reference values driving break thresholds.
-- Densities approx. g/cm³; ultimate compressive strength MPa (compact bone literature ranges).

Bones = {}

Bones.TYPES = {
    skull = {
        density = 1.85,
        compressiveMPa = 150,
        toughness = 1.15, -- relative energy needed to crack in-sim
        breakStrain = 1.12,
        label = "Cranial vault",
    },
    rib = {
        density = 1.55,
        compressiveMPa = 100,
        toughness = 0.55,
        breakStrain = 1.18,
        label = "Rib",
    },
    vertebra = {
        density = 1.35, -- more trabecular
        compressiveMPa = 45,
        toughness = 0.7,
        breakStrain = 1.16,
        label = "Vertebra",
    },
    long = {
        density = 1.90, -- femur/humerus cortex
        compressiveMPa = 170,
        toughness = 1.35,
        breakStrain = 1.14,
        label = "Long bone cortex",
    },
    pelvis = {
        density = 1.50,
        compressiveMPa = 90,
        toughness = 0.95,
        breakStrain = 1.15,
        label = "Pelvis",
    },
}

-- Approximate ft·lbf local transfer to initiate cortical crack for .22 crush path.
function Bones.fractureEnergyFtlb(boneType)
    local t = Bones.TYPES[boneType or "long"] or Bones.TYPES.long
    -- Scaled from toughness × density (game units grounded in relative strength)
    return 28 * t.toughness * (t.density / 1.8)
end

function Bones.canFracture(boneType, transferredFtlb)
    return (transferredFtlb or 0) >= Bones.fractureEnergyFtlb(boneType) * 0.85
end

function Bones.applyToNode(node, boneType)
    local t = Bones.TYPES[boneType or "long"] or Bones.TYPES.long
    node.boneType = boneType
    node.density = t.density
    node.toughness = t.toughness
    node.kind = "bone"
    return node
end

function Bones.breakStrainFor(boneType)
    local t = Bones.TYPES[boneType or "long"] or Bones.TYPES.long
    return t.breakStrain
end
