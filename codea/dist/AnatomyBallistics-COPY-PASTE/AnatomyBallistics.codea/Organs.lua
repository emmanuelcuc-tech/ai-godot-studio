-- Organs.lua
-- Functional organ / fluid physiology + .22 crush-wound damage model.
-- Wounding basis: low-velocity crush/laceration dominant; minimal temporary cavity
-- (Emergency War Surgery wound profiles; Brassfetcher radial KE notes for .22 LR).

Organs = {}

-- Vulnerability: how readily parenchyma fails under crush KE (relative).
-- Liver/brain high (inelastic); muscle lower (elastic recovery).
Organs.DEFS = {
    brain = {
        label = "Brain",
        massKg = 1.4,
        vulnerability = 1.85,
        fluid = "blood",
        functionKey = "brainActivity",
        rgb = { 0.75, 0.55, 0.65 },
        critical = true,
    },
    heart = {
        label = "Heart",
        massKg = 0.3,
        vulnerability = 1.65,
        fluid = "blood",
        functionKey = "cardiacOutput",
        rgb = { 0.75, 0.12, 0.18 },
        critical = true,
    },
    lungL = {
        label = "Left lung",
        massKg = 0.5,
        vulnerability = 1.05,
        fluid = "blood",
        functionKey = "oxygenation",
        rgb = { 0.85, 0.55, 0.55 },
    },
    lungR = {
        label = "Right lung",
        massKg = 0.55,
        vulnerability = 1.05,
        fluid = "blood",
        functionKey = "oxygenation",
        rgb = { 0.85, 0.55, 0.55 },
    },
    liver = {
        label = "Liver",
        massKg = 1.5,
        vulnerability = 1.55,
        fluid = "blood",
        functionKey = "filtration",
        rgb = { 0.55, 0.2, 0.15 },
    },
    gallbladder = {
        label = "Gallbladder",
        massKg = 0.05,
        vulnerability = 1.4,
        fluid = "bile",
        functionKey = "bileFlow",
        rgb = { 0.55, 0.7, 0.25 },
    },
    stomach = {
        label = "Stomach",
        massKg = 0.25,
        vulnerability = 1.15,
        fluid = "gastric",
        functionKey = "digestion",
        rgb = { 0.7, 0.45, 0.35 },
    },
    kidneyL = {
        label = "Left kidney",
        massKg = 0.15,
        vulnerability = 1.35,
        fluid = "blood",
        functionKey = "renal",
        rgb = { 0.65, 0.25, 0.3 },
    },
    kidneyR = {
        label = "Right kidney",
        massKg = 0.15,
        vulnerability = 1.35,
        fluid = "blood",
        functionKey = "renal",
        rgb = { 0.65, 0.25, 0.3 },
    },
    spleen = {
        label = "Spleen",
        massKg = 0.18,
        vulnerability = 1.5,
        fluid = "blood",
        functionKey = "filtration",
        rgb = { 0.5, 0.15, 0.2 },
    },
}

function Organs.newState()
    local st = {
        integrity = {}, -- 1 = intact
        leak = {}, -- fluid leak rate 0..1
        vitals = {
            heartRate = 72,      -- bpm
            systolic = 118,
            diastolic = 76,
            cardiacOutput = 1, -- fraction
            brainActivity = 1,
            oxygenation = 0.98,
            bileFlow = 1,
            digestion = 1,
            renal = 1,
            filtration = 1,
            bloodPressureMean = 90,
            pulseWave = 0,
        },
        lastHit = nil,
        log = {},
    }
    for name, _ in pairs(Organs.DEFS) do
        st.integrity[name] = 1
        st.leak[name] = 0
    end
    return st
end

-- Permanent crush damage fraction from impact energy (ft·lbf) and organ vulnerability.
-- .22 LR ~90–140 ft·lbf open air at these ranges → meaningful but not explosive cavity.
function Organs.crushDamageFraction(impactFtlb, organName, hitQuality)
    hitQuality = hitQuality or 1 -- 0..1 how centered the hit is
    local def = Organs.DEFS[organName]
    if not def then
        return 0
    end
    local base = (impactFtlb or 0) / 140 -- normalize to HV muzzle class
    local dmg = base * def.vulnerability * (0.35 + 0.65 * hitQuality)
    -- Soft floor: glancing hits still bruise
    return math.max(0, math.min(1, dmg * 0.55))
end

function Organs.applyHit(state, organName, impactFtlb, hitQuality, boneBlocked)
    if not state or not Organs.DEFS[organName] then
        return 0
    end
    local scale = boneBlocked and 0.45 or 1 -- skull/rib can shed energy
    local dmg = Organs.crushDamageFraction(impactFtlb, organName, hitQuality) * scale
    local before = state.integrity[organName] or 1
    state.integrity[organName] = math.max(0, before - dmg)
    state.leak[organName] = math.min(1, (state.leak[organName] or 0) + dmg * 0.9)
    state.lastHit = {
        organ = organName,
        ftlb = impactFtlb,
        damage = dmg,
        remaining = state.integrity[organName],
    }
    state.log[#state.log + 1] = state.lastHit
    return dmg
end

function Organs.nearestOrgan(metaOrgans, hitPos)
    if not metaOrgans or not hitPos then
        return nil, 1e9
    end
    local best, bestD = nil, 1e9
    for _, org in ipairs(metaOrgans) do
        local cx, cy, cz, n = 0, 0, 0, 0
        -- org.center preferred if present
        if org.center then
            cx, cy, cz = org.center.x, org.center.y, org.center.z
            n = 1
        elseif org.ids then
            -- centers filled by Anatomy with soft-body refs later; skip if only ids
        end
        if org.cx then
            cx, cy, cz, n = org.cx, org.cy, org.cz, 1
        end
        if n > 0 then
            local dx, dy, dz = hitPos.x - cx, hitPos.y - cy, hitPos.z - cz
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d < bestD then
                bestD = d
                best = org.name
            end
        end
    end
    return best, bestD
end

function Organs.hitQualityFromDistance(dist, radius)
    radius = radius or 0.28
    if dist >= radius then
        return 0
    end
    local t = 1 - dist / radius
    return t * t
end

-- Tick vital signs from organ integrity (simple physiology model).
function Organs.step(state, dt)
    dt = dt or 1 / 60
    local v = state.vitals
    local heart = state.integrity.heart or 1
    local brain = state.integrity.brain or 1
    local lung = ((state.integrity.lungL or 1) + (state.integrity.lungR or 1)) * 0.5
    local liver = state.integrity.liver or 1
    local gall = state.integrity.gallbladder or 1
    local kidney = ((state.integrity.kidneyL or 1) + (state.integrity.kidneyR or 1)) * 0.5
    local stomach = state.integrity.stomach or 1
    local spleen = state.integrity.spleen or 1

    -- Compensatory tachycardia as blood loss / cardiac damage rises
    local bleed = 0
    for name, leak in pairs(state.leak) do
        bleed = bleed + leak * (Organs.DEFS[name] and Organs.DEFS[name].massKg or 0.2)
    end
    bleed = math.min(1.5, bleed)

    local targetHR = 72 + bleed * 55 + (1 - heart) * 40
    if heart < 0.25 then
        targetHR = targetHR * heart * 2 -- failing pump
    end
    if brain < 0.2 then
        targetHR = targetHR * 0.5
    end
    v.heartRate = v.heartRate + (targetHR - v.heartRate) * math.min(1, dt * 2)

    v.cardiacOutput = math.max(0, heart * (1 - bleed * 0.35))
    v.systolic = 118 * v.cardiacOutput * (0.7 + 0.3 * brain)
    v.diastolic = 76 * v.cardiacOutput
    v.bloodPressureMean = (v.systolic + 2 * v.diastolic) / 3

    v.brainActivity = math.max(0, brain * (0.4 + 0.6 * (v.oxygenation or 0.98)))
    v.oxygenation = math.max(0.5, 0.55 + 0.45 * lung) * (0.6 + 0.4 * v.cardiacOutput)
    v.bileFlow = math.max(0, gall * (0.5 + 0.5 * liver))
    v.digestion = math.max(0, stomach * 0.7 + liver * 0.3)
    v.renal = math.max(0, kidney * v.cardiacOutput)
    v.filtration = math.max(0, (liver * 0.6 + spleen * 0.4) * v.cardiacOutput)

    -- Pulse wave for rendering heartbeat
    local bpm = math.max(20, v.heartRate)
    v.pulseWave = (v.pulseWave + dt * (bpm / 60) * math.pi * 2) % (math.pi * 2)

    return v
end

function Organs.heartbeatScale(state)
    local w = state.vitals.pulseWave or 0
    -- Systolic kick
    return 1 + 0.08 * math.max(0, math.sin(w)) ^ 3 * (state.integrity.heart or 1)
end

function Organs.fluidColor(fluid)
    if fluid == "bile" then
        return 180, 200, 40, 200
    elseif fluid == "gastric" then
        return 200, 190, 140, 160
    end
    return 170, 10, 22, 200 -- blood
end

function Organs.summaryLine(state)
    local v = state.vitals
    return string.format("HR %.0f  BP %.0f/%.0f  Brain %.0f%%  SpO2 %.0f%%  Bile %.0f%%",
        v.heartRate, v.systolic, v.diastolic,
        v.brainActivity * 100, v.oxygenation * 100, v.bileFlow * 100)
end
