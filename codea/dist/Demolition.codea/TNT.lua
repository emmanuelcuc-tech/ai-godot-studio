-- TNT.lua
-- Standard TNT energy equivalence (historical convention):
--   1 gram TNT = 4,184 J  (4.184 kJ/g)
--   1 ton  TNT = 4.184 × 10⁹ J  (= 4.184 GJ)
-- Blast overpressure uses Kinney–Graham scaled distance:
--   Z = R / W^(1/3)   R in meters, W = TNT mass in kilograms
-- Alternate isotropic intensity (VS / sphere surface):
--   I = P / (4 π r²)  with P = yield in joules

TNT = {}

TNT.J_PER_G = 4184
TNT.J_PER_KG = 4184 * 1000
TNT.J_PER_TON = 4.184e9 -- exactly 4184 J/g × 1e6 g/ton
TNT.KJ_PER_G = 4.184
TNT.GJ_PER_TON = 4.184

-- Sanity: 1 ton = 1e6 grams
assert(math.abs(TNT.J_PER_TON - TNT.J_PER_G * 1e6) < 1e-3)

function TNT.gramsToJoules(grams)
    return (grams or 0) * TNT.J_PER_G
end

function TNT.kgToJoules(kg)
    return (kg or 0) * TNT.J_PER_KG
end

function TNT.tonsToJoules(tons)
    return (tons or 0) * TNT.J_PER_TON
end

function TNT.joulesToTons(joules)
    return (joules or 0) / TNT.J_PER_TON
end

function TNT.gramsToTons(grams)
    return (grams or 0) / 1e6
end

function TNT.gramsToKg(grams)
    return (grams or 0) / 1000
end

-- Kinney–Graham scaled distance Z = R / W^(1/3)
function TNT.scaledDistance(distanceM, tntKg)
    local W = math.max(1e-9, tntKg or 0)
    local R = math.max(1e-6, distanceM or 0)
    return R / (W ^ (1 / 3))
end

-- Peak side-on overpressure estimate (kPa) vs Z (game fit of KG-style curve).
function TNT.peakOverpressureKpa(distanceM, tntKg)
    local Z = TNT.scaledDistance(distanceM, tntKg)
    -- Compact fit: high near-field, ~1/Z² mid-field
    local pKpa = 808.0 * (1 + (Z / 4.5) ^ 2) / math.sqrt(1 + (Z / 0.048) ^ 2)
        / math.sqrt(1 + (Z / 0.32) ^ 2) / math.sqrt(1 + (Z / 1.35) ^ 2)
    -- Fallback blend keeps older simple curve available for tiny W
    local simple = 700 / (Z * Z + 0.4) + 40 / (Z + 0.15)
    return 0.65 * pKpa + 0.35 * simple, Z
end

-- Surface blast intensity I = P / (4 π r²)  [J/m²]
function TNT.surfaceIntensity(yieldJ, radiusM)
    local r = math.max(0.05, radiusM or 0)
    return (yieldJ or 0) / (4 * math.pi * r * r)
end

-- Combined charge evaluation for Demolition.detonate
function TNT.evaluate(grams, distanceM)
    local g = grams or 0
    local yieldJ = TNT.gramsToJoules(g)
    local tntKg = TNT.gramsToKg(g)
    local tons = TNT.gramsToTons(g)
    local pKpa, Z = TNT.peakOverpressureKpa(distanceM or 1, tntKg)
    local intensity = TNT.surfaceIntensity(yieldJ, distanceM or 1)
    return {
        grams = g,
        kg = tntKg,
        tons = tons,
        joules = yieldJ,
        kilojoules = yieldJ / 1000,
        megajoules = yieldJ / 1e6,
        gigajoules = yieldJ / 1e9,
        pKpa = pKpa,
        Z = Z,
        intensity = intensity, -- J/m²
    }
end

function TNT.formatYield(grams)
    local y = TNT.evaluate(grams, 1)
    if y.tons >= 0.001 then
        return string.format("%.3f t TNT (%.3f GJ)", y.tons, y.gigajoules)
    end
    if y.megajoules >= 1 then
        return string.format("%.2f MJ (%.0f g TNT)", y.megajoules, y.grams)
    end
    return string.format("%.1f kJ (%.0f g TNT · 4184 J/g)", y.kilojoules, y.grams)
end
