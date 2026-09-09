-- Anatomy Ballistics 1.1.0
-- Single-file Codea project. Download AnatomyBallistics.codea.zip on iPad,
-- unzip, copy AnatomyBallistics.codea into Files → On My iPad → Codea, tap Play.
-- Drag to aim. Double-tap to fire .22 LR. RESET rebuilds. NEXT advances range.

-- Buffer: Vec3 ------------------------------------------------
-- Vec3.lua
-- Tiny 3D vector helpers (pure Lua; smoke-testable outside Codea).

Vec3 = {}

function Vec3.new(x, y, z)
    return { x = x or 0, y = y or 0, z = z or 0 }
end

function Vec3.copy(v)
    return { x = v.x, y = v.y, z = v.z }
end

function Vec3.add(a, b)
    return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

function Vec3.sub(a, b)
    return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

function Vec3.scale(a, s)
    return { x = a.x * s, y = a.y * s, z = a.z * s }
end

function Vec3.dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

function Vec3.cross(a, b)
    return {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x,
    }
end

function Vec3.length(a)
    return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end

function Vec3.length2(a)
    return a.x * a.x + a.y * a.y + a.z * a.z
end

function Vec3.normalize(a)
    local len = Vec3.length(a)
    if len < 1e-8 then
        return { x = 0, y = 0, z = 0 }
    end
    return { x = a.x / len, y = a.y / len, z = a.z / len }
end

function Vec3.lerp(a, b, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = a.z + (b.z - a.z) * t,
    }
end

function Vec3.dist(a, b)
    return Vec3.length(Vec3.sub(a, b))
end

function Vec3.atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    return math.atan(y, x)
end

-- Buffer: TwentyTwo ------------------------------------------------
-- TwentyTwo.lua
-- Real-world .22 LR reference data for staged ranges + wall barriers.
-- Sources (approx. tables used in-game; cite in README):
--   ShootersCalculator G1 BC 0.122, 40 gr, 1070 fps standard velocity
--   Remington Thunderbolt / HV class 40 gr ~1255 fps muzzle (AmmoReports)
--   Haag 2010 / thesis summary: ~12–15 m/s (~39–49 fps) loss per ½″ drywall

TwentyTwo = {}

TwentyTwo.CALIBER = ".22 LR"
TwentyTwo.GRAIN = 40
TwentyTwo.DIAMETER_IN = 0.223
TwentyTwo.BC_G1 = 0.122

-- Dual reference loads (fps / ft·lbf). Game uses HV as default cartridge.
TwentyTwo.LOADS = {
    standard = {
        name = "CCI / Federal Standard Velocity 40 gr LRN",
        muzzleFps = 1070,
        muzzleFtlb = 102,
        -- ShootersCalculator step table (yd → fps, ftlb)
        tableYd = {
            { 0, 1070, 102 },
            { 10, 1048, 98 },
            { 20, 1028, 94 },
            { 30, 1010, 91 },
            { 40, 992, 87 },
            { 50, 976, 85 },
        },
    },
    hv = {
        name = "Remington Thunderbolt-class HV 40 gr LRN",
        muzzleFps = 1255,
        muzzleFtlb = 140,
        -- Interpolated from published 0 / 25 / 50 yd HV points
        tableYd = {
            { 0, 1255, 140 },
            { 8.33, 1234, 135 },  -- ~25 ft
            { 16.67, 1212, 131 }, -- ~50 ft
            { 25, 1192, 126 },
            { 50, 1133, 114 },
        },
    },
}

TwentyTwo.DEFAULT_LOAD = "hv"

-- Stage ranges in feet (open air), then house-wall stage.
TwentyTwo.RANGE_FEET = { 40, 35, 30, 25, 20, 15 }

-- Interior house wall approximation: ½″ drywall + wood stud + ½″ drywall.
-- Drywall Δv ≈ 45 fps per sheet (mid of 39–49). Stud softwood ~180 fps loss (game model).
TwentyTwo.WALL = {
    name = "Interior house wall (½″ drywall + pine stud + ½″ drywall)",
    drywallSheets = 2,
    drywallDeltaFps = 45, -- per ½″ sheet (Haag-scale)
    studDeltaFps = 180,   -- softwood 2×4 path (engineering estimate for sim)
    plywoodInches = 0,    -- optional exterior sheathing
}

function TwentyTwo.fpsToMs(fps)
    return (fps or 0) * 0.3048
end

function TwentyTwo.ftlbToJoules(ftlb)
    return (ftlb or 0) * 1.35582
end

function TwentyTwo.grainsToKg(gr)
    return (gr or 40) * 6.479891e-5
end

-- Interpolate velocity/energy from a yard table given range in feet.
function TwentyTwo.interpolateLoad(loadKey, rangeFeet)
    local load = TwentyTwo.LOADS[loadKey or TwentyTwo.DEFAULT_LOAD] or TwentyTwo.LOADS.hv
    local yd = (rangeFeet or 0) / 3
    local tab = load.tableYd
    if yd <= tab[1][1] then
        return tab[1][2], tab[1][3], load
    end
    for i = 1, #tab - 1 do
        local a, b = tab[i], tab[i + 1]
        if yd <= b[1] then
            local t = (yd - a[1]) / (b[1] - a[1])
            local fps = a[2] + (b[2] - a[2]) * t
            local ftlb = a[3] + (b[3] - a[3]) * t
            return fps, ftlb, load
        end
    end
    local last = tab[#tab]
    return last[2], last[3], load
end

function TwentyTwo.wallDeltaFps(wall)
    wall = wall or TwentyTwo.WALL
    return (wall.drywallSheets or 0) * (wall.drywallDeltaFps or 45) + (wall.studDeltaFps or 0)
end

-- Apply barrier: reduce fps, recompute energy from ½mv² with grain mass.
function TwentyTwo.afterBarrier(fps, grain, wall)
    grain = grain or TwentyTwo.GRAIN
    local outFps = math.max(0, (fps or 0) - TwentyTwo.wallDeltaFps(wall))
    local massKg = TwentyTwo.grainsToKg(grain)
    local v = TwentyTwo.fpsToMs(outFps)
    local joules = 0.5 * massKg * v * v
    local ftlb = joules / 1.35582
    return outFps, ftlb
end

-- Snapshot for a gameplay stage.
-- stageIndex: 1..#RANGE_FEET open air, then #RANGE_FEET+1 = wall stage (range 12 ft + barrier).
function TwentyTwo.stageSnapshot(stageIndex, loadKey)
    loadKey = loadKey or TwentyTwo.DEFAULT_LOAD
    local ranges = TwentyTwo.RANGE_FEET
    local wallStage = #ranges + 1
    stageIndex = math.max(1, math.min(wallStage, math.floor(stageIndex or 1)))

    local rangeFeet, throughWall
    if stageIndex <= #ranges then
        rangeFeet = ranges[stageIndex]
        throughWall = false
    else
        rangeFeet = 12 -- typical room-to-room engagement distance past wall
        throughWall = true
    end

    local fps, ftlb, load = TwentyTwo.interpolateLoad(loadKey, rangeFeet)
    local preWallFps, preWallFtlb = fps, ftlb
    if throughWall then
        fps, ftlb = TwentyTwo.afterBarrier(fps, TwentyTwo.GRAIN, TwentyTwo.WALL)
    end

    return {
        index = stageIndex,
        maxIndex = wallStage,
        rangeFeet = rangeFeet,
        throughWall = throughWall,
        loadKey = loadKey,
        loadName = load.name,
        grain = TwentyTwo.GRAIN,
        caliber = TwentyTwo.CALIBER,
        impactFps = fps,
        impactFtlb = ftlb,
        preWallFps = preWallFps,
        preWallFtlb = preWallFtlb,
        wallDeltaFps = throughWall and TwentyTwo.wallDeltaFps() or 0,
        impactJoules = TwentyTwo.ftlbToJoules(ftlb),
        label = throughWall
            and string.format("WALL @ %dft (drywall+wood)", rangeFeet)
            or string.format("OPEN @ %dft", rangeFeet),
    }
end

function TwentyTwo.nextStageIndex(stageIndex)
    local maxI = #TwentyTwo.RANGE_FEET + 1
    stageIndex = (stageIndex or 1) + 1
    if stageIndex > maxI then
        return maxI
    end
    return stageIndex
end

-- Map real feet → camera distance (world units) for perspective staging.
function TwentyTwo.cameraDistanceForFeet(rangeFeet)
    rangeFeet = rangeFeet or 40
    -- 15 ft → ~4.2 world units, 40 ft → ~10.5
    return 1.8 + rangeFeet * 0.215
end

-- Map real impact fps into cinematic flight speed (keeps cameras readable).
function TwentyTwo.cinematicSpeed(impactFps)
    impactFps = impactFps or 1200
    -- Scale so ~1255 fps → ~18 world units/s, ~900 fps → ~13
    return 8 + (impactFps / 1255) * 10
end

-- Permanent crush channel radius estimate (inches) — .22 primarily crush wounding.
function TwentyTwo.crushRadiusIn(yawFactor)
    yawFactor = yawFactor or 1
    return (TwentyTwo.DIAMETER_IN * 0.5) * (0.9 + 0.5 * yawFactor)
end

-- Temporary cavity is small for .22 LR (Emergency War Surgery / Brassfetcher-scale).
function TwentyTwo.tempCavityScale(impactFps)
    -- Peak radial KE tiny; return 0–1 scale for FX only
    return math.max(0, math.min(1, ((impactFps or 0) - 800) / 600)) * 0.22
end

-- Buffer: Bones ------------------------------------------------
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

-- Buffer: Organs ------------------------------------------------
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

-- Buffer: Stages ------------------------------------------------
-- Stages.lua
-- Range progression: 40→15 ft by 5 ft, then drywall+wood house-wall stage.

Stages = {}

function Stages.new(loadKey)
    local st = {
        index = 1,
        loadKey = loadKey or TwentyTwo.DEFAULT_LOAD,
        shotsThisStage = 0,
        autoAdvance = true,
    }
    st.snap = TwentyTwo.stageSnapshot(st.index, st.loadKey)
    return st
end

function Stages.refresh(st)
    st.snap = TwentyTwo.stageSnapshot(st.index, st.loadKey)
    return st.snap
end

function Stages.advance(st)
    local nextI = TwentyTwo.nextStageIndex(st.index)
    if nextI == st.index then
        return false, st.snap
    end
    st.index = nextI
    st.shotsThisStage = 0
    Stages.refresh(st)
    return true, st.snap
end

function Stages.reset(st)
    st.index = 1
    st.shotsThisStage = 0
    Stages.refresh(st)
    return st.snap
end

function Stages.onShotFired(st)
    st.shotsThisStage = (st.shotsThisStage or 0) + 1
end

-- After impact cinematic, optionally step closer / into wall stage.
function Stages.maybeAdvanceAfterImpact(st)
    if not st.autoAdvance then
        return false, st.snap
    end
    return Stages.advance(st)
end

function Stages.hudText(st)
    local s = st.snap
    if s.throughWall then
        return string.format(
            "STAGE %d/%d  %s\n.22 LR %dgr  impact %.0f fps · %.0f ft·lbf  (pre-wall %.0f fps)\nBarrier Δv −%.0f fps (2×½″ drywall + pine stud)",
            s.index, s.maxIndex, s.label,
            s.grain, s.impactFps, s.impactFtlb, s.preWallFps, s.wallDeltaFps
        )
    end
    return string.format(
        "STAGE %d/%d  %s\n.22 LR %dgr  impact %.0f fps · %.0f ft·lbf · %.0f J",
        s.index, s.maxIndex, s.label,
        s.grain, s.impactFps, s.impactFtlb, s.impactJoules
    )
end

-- Buffer: Ballistics ------------------------------------------------
-- Ballistics.lua
-- Bullet flight, cooldown, kinetic energy, trajectory sampling.

Ballistics = {}

Ballistics.COOLDOWN = 3.0
Ballistics.MUZZLE_SPEED = 16 -- world units / second (cinematic flight length)
Ballistics.MASS = 0.012
Ballistics.RADIUS = 0.08
Ballistics.GRAVITY = -1.6 -- mild arc in world space
Ballistics.DRAG = 0.06

function Ballistics.kineticEnergy(mass, speed)
    mass = math.max(0, mass or 0)
    speed = math.max(0, speed or 0)
    return 0.5 * mass * speed * speed
end

function Ballistics.speed(v)
    return Vec3.length(v or Vec3.new())
end

function Ballistics.canFire(cooldownLeft)
    return (cooldownLeft or 0) <= 0
end

function Ballistics.tickCooldown(cooldownLeft, dt)
    return math.max(0, (cooldownLeft or 0) - (dt or 0))
end

-- Spawn a bullet from eye toward aim direction.
-- opts: { realFps, realFtlb, grain, caliber, throughWall, stageLabel }
function Ballistics.spawn(origin, direction, speed, opts)
    opts = opts or {}
    speed = speed or Ballistics.MUZZLE_SPEED
    local dir = Vec3.normalize(direction)
    local mass = Ballistics.MASS
    if opts.grain then
        -- Keep sim mass stable; real grain used for damage tables only
        mass = Ballistics.MASS
    end
    return {
        pos = Vec3.copy(origin),
        vel = Vec3.scale(dir, speed),
        mass = mass,
        radius = Ballistics.RADIUS,
        alive = true,
        age = 0,
        trail = { Vec3.copy(origin) },
        hit = false,
        hitPos = nil,
        hitNormal = nil,
        realFps = opts.realFps,
        realFtlb = opts.realFtlb,
        grain = opts.grain or 40,
        caliber = opts.caliber or ".22 LR",
        throughWall = opts.throughWall or false,
        stageLabel = opts.stageLabel,
        wallHit = false,
    }
end

function Ballistics.integrate(bullet, dt)
    if not bullet or not bullet.alive then
        return bullet
    end
    dt = dt or (1 / 60)
    bullet.age = (bullet.age or 0) + dt
    -- Gravity + linear drag
    bullet.vel.y = bullet.vel.y + Ballistics.GRAVITY * dt
    local damp = math.max(0, 1 - Ballistics.DRAG * dt)
    bullet.vel.x = bullet.vel.x * damp
    bullet.vel.y = bullet.vel.y * damp
    bullet.vel.z = bullet.vel.z * damp
    bullet.pos.x = bullet.pos.x + bullet.vel.x * dt
    bullet.pos.y = bullet.pos.y + bullet.vel.y * dt
    bullet.pos.z = bullet.pos.z + bullet.vel.z * dt

    local trail = bullet.trail
    local last = trail[#trail]
    if (not last) or Vec3.dist(last, bullet.pos) > 0.12 then
        trail[#trail + 1] = Vec3.copy(bullet.pos)
        if #trail > 180 then
            table.remove(trail, 1)
        end
    end
    return bullet
end

-- Double-tap detector: returns true when second tap qualifies.
function Ballistics.doubleTap(prevT, prevX, prevY, nowT, x, y, maxDt, maxDist)
    maxDt = maxDt or 0.32
    maxDist = maxDist or 48
    if not prevT then
        return false
    end
    local dt = nowT - prevT
    if dt <= 0 or dt > maxDt then
        return false
    end
    local dx, dy = (x or 0) - (prevX or 0), (y or 0) - (prevY or 0)
    return math.sqrt(dx * dx + dy * dy) <= maxDist
end

-- Soft hit test against point cloud (soft-body nodes).
-- Returns index of closest node within radius, or nil.
function Ballistics.hitNodeIndex(bullet, nodes, pad)
    if not bullet or not bullet.alive or not nodes then
        return nil
    end
    pad = pad or 0.15
    local best, bestD = nil, (bullet.radius + pad)
    bestD = bestD * bestD
    for i, n in ipairs(nodes) do
        if n.alive ~= false then
            local dx = n.x - bullet.pos.x
            local dy = n.y - bullet.pos.y
            local dz = n.z - bullet.pos.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 <= bestD then
                bestD = d2
                best = i
            end
        end
    end
    return best
end

function Ballistics.markHit(bullet, pos, normal)
    bullet.hit = true
    bullet.alive = false
    bullet.hitPos = Vec3.copy(pos)
    bullet.hitNormal = normal and Vec3.copy(normal) or Vec3.new(0, 0, -1)
    bullet.trail[#bullet.trail + 1] = Vec3.copy(pos)
    return bullet
end

-- Phase of the cinematic based on bullet distance to body center.
-- Returns: "side_trail" | "overhead" | "follow_slow" | "impact"
-- Optional state table tracks minimum dwell so overhead is not skipped.
function Ballistics.cinematicPhase(bullet, bodyCenter, impactDone, state, dt)
    if impactDone or (bullet and bullet.hit) then
        return "impact"
    end
    if not bullet or not bullet.alive then
        return "aim"
    end
    local d = Vec3.dist(bullet.pos, bodyCenter)
    local desired
    if d > 3.6 then
        desired = "side_trail"
    elseif d > 1.35 then
        desired = "overhead"
    else
        desired = "follow_slow"
    end
    -- Enforce brief dwell in side_trail → overhead → follow_slow
    if state then
        dt = dt or 0
        state.phase = state.phase or desired
        state.phaseAge = (state.phaseAge or 0) + dt
        local minDwell = {
            side_trail = 0.22,
            overhead = 0.30,
            follow_slow = 0.18,
        }
        local order = { side_trail = 1, overhead = 2, follow_slow = 3, impact = 4 }
        local cur, want = order[state.phase] or 1, order[desired] or 1
        if want > cur and state.phaseAge < (minDwell[state.phase] or 0) then
            desired = state.phase
        elseif desired ~= state.phase and want >= cur then
            state.phase = desired
            state.phaseAge = 0
        else
            desired = state.phase
        end
        if desired ~= state.phase then
            state.phase = desired
            state.phaseAge = 0
        end
    end
    return desired
end

function Ballistics.timeScaleForPhase(phase)
    if phase == "follow_slow" or phase == "impact" then
        return 0.18
    elseif phase == "overhead" then
        return 0.45
    elseif phase == "side_trail" then
        return 0.7
    end
    return 1
end

-- Buffer: SoftBody ------------------------------------------------
-- SoftBody.lua
-- Verlet soft body: fabric skin, elastic muscle, breakable bones.

SoftBody = {}

SoftBody.GRAVITY = -6.5
SoftBody.ITERATIONS = 4
SoftBody.GROUND_Y = -2.15

function SoftBody.new()
    return {
        nodes = {},
        springs = {},
        triangles = {}, -- for skin shading {i,j,k, layer}
    }
end

function SoftBody.addNode(body, x, y, z, opts)
    opts = opts or {}
    local n = {
        x = x, y = y, z = z,
        px = x, py = y, pz = z, -- previous for Verlet
        ox = x, oy = y, oz = z, -- rest / bind pose
        mass = opts.mass or 1,
        invMass = 0,
        pinned = opts.pinned or false,
        kind = opts.kind or "flesh", -- flesh | bone | organ | skin
        organ = opts.organ,
        alive = true,
        wet = 0,
        crack = 0,
    }
    if n.pinned or n.mass <= 0 then
        n.invMass = 0
    else
        n.invMass = 1 / n.mass
    end
    body.nodes[#body.nodes + 1] = n
    return #body.nodes
end

function SoftBody.addSpring(body, i, j, opts)
    opts = opts or {}
    local a, b = body.nodes[i], body.nodes[j]
    if not a or not b then
        return nil
    end
    local rest = opts.rest
    if not rest then
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        rest = math.sqrt(dx * dx + dy * dy + dz * dz)
    end
    local s = {
        i = i,
        j = j,
        rest = math.max(0.001, rest),
        stiffness = opts.stiffness or 0.35,
        damping = opts.damping or 0.02,
        breakStrain = opts.breakStrain or 1.85, -- ratio of length/rest
        kind = opts.kind or "muscle", -- skin | muscle | bone | vessel
        alive = true,
        strain = 1,
    }
    -- Bones tolerate less stretch before cracking
    if s.kind == "bone" then
        s.breakStrain = opts.breakStrain or 1.22
        s.stiffness = opts.stiffness or 0.92
    elseif s.kind == "skin" then
        s.breakStrain = opts.breakStrain or 1.55
        s.stiffness = opts.stiffness or 0.55
    elseif s.kind == "vessel" then
        s.breakStrain = opts.breakStrain or 1.35
        s.stiffness = opts.stiffness or 0.4
    end
    body.springs[#body.springs + 1] = s
    return #body.springs
end

function SoftBody.addTriangle(body, i, j, k, layer)
    body.triangles[#body.triangles + 1] = { i = i, j = j, k = k, layer = layer or "skin" }
end

local function constrainSpring(body, s)
    if not s.alive then
        return false
    end
    local a, b = body.nodes[s.i], body.nodes[s.j]
    if not a or not b or a.alive == false or b.alive == false then
        s.alive = false
        return false
    end
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1e-8 then
        return false
    end
    s.strain = len / s.rest
    if s.strain > s.breakStrain then
        s.alive = false
        if s.kind == "bone" then
            a.crack = 1
            b.crack = 1
        end
        return true -- tore
    end
    local inv = a.invMass + b.invMass
    if inv <= 0 then
        return false
    end
    local diff = (len - s.rest) / len
    local corr = diff * s.stiffness
    local cx, cy, cz = dx * corr, dy * corr, dz * corr
    local wA = a.invMass / inv
    local wB = b.invMass / inv
    a.x = a.x + cx * wA
    a.y = a.y + cy * wA
    a.z = a.z + cz * wA
    b.x = b.x - cx * wB
    b.y = b.y - cy * wB
    b.z = b.z - cz * wB
    return false
end

function SoftBody.step(body, dt, timeScale)
    dt = (dt or 1 / 60) * (timeScale or 1)
    if dt <= 0 then
        return {}
    end
    local tore = {}
    local nodes = body.nodes
    -- Verlet integrate
    for _, n in ipairs(nodes) do
        if n.alive ~= false and not n.pinned and n.invMass > 0 then
            local vx = (n.x - n.px)
            local vy = (n.y - n.py)
            local vz = (n.z - n.pz)
            n.px, n.py, n.pz = n.x, n.y, n.z
            local damp = 0.994
            n.x = n.x + vx * damp
            n.y = n.y + vy * damp + SoftBody.GRAVITY * dt * dt
            n.z = n.z + vz * damp
            if n.y < SoftBody.GROUND_Y then
                n.y = SoftBody.GROUND_Y
                n.py = n.y + (n.y - n.py) * -0.2
            end
        end
    end
    for _ = 1, SoftBody.ITERATIONS do
        for si, s in ipairs(body.springs) do
            if constrainSpring(body, s) then
                tore[#tore + 1] = { index = si, kind = s.kind, i = s.i, j = s.j }
            end
        end
    end
    return tore
end

-- Apply bullet impulse + tear nearby springs (fabric pull / rip).
-- impactFtlb: real .22 ft·lbf for bone fracture thresholds.
function SoftBody.applyBulletImpact(body, hitPos, velocity, ke, radius, impactFtlb)
    radius = radius or 0.45
    impactFtlb = impactFtlb or (ke * 80) -- fallback scale
    local torn = {}
    local speed = Vec3.length(velocity)
    local dir = Vec3.normalize(velocity)
    local impulseScale = 0.015 + ke * 8
    local fracturedBones = {}

    for _, n in ipairs(body.nodes) do
        if n.alive ~= false and not n.pinned then
            local dx, dy, dz = n.x - hitPos.x, n.y - hitPos.y, n.z - hitPos.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d < radius then
                local w = (1 - d / radius)
                w = w * w
                local push = impulseScale * w * n.invMass
                n.x = n.x + (dir.x * push + dx * 0.35 * w)
                n.y = n.y + (dir.y * push + dy * 0.35 * w)
                n.z = n.z + (dir.z * push + dz * 0.35 * w)
                n.wet = math.min(1, n.wet + w * 0.8)
                if n.kind == "bone" then
                    local btype = n.boneType or "long"
                    local localE = impactFtlb * w
                    if Bones and Bones.canFracture(btype, localE) then
                        n.crack = 1
                        fracturedBones[#fracturedBones + 1] = { type = btype, energy = localE }
                    else
                        n.crack = math.min(1, n.crack + w * 0.5)
                    end
                end
            end
        end
    end

    for si, s in ipairs(body.springs) do
        if s.alive then
            local a, b = body.nodes[s.i], body.nodes[s.j]
            local mx = (a.x + b.x) * 0.5
            local my = (a.y + b.y) * 0.5
            local mz = (a.z + b.z) * 0.5
            local dx, dy, dz = mx - hitPos.x, my - hitPos.y, mz - hitPos.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            local tearR = radius * (s.kind == "skin" and 1.15 or (s.kind == "bone" and 0.55 or 0.9))
            if d < tearR then
                local chance = (1 - d / tearR)
                local need = 0.25
                if s.kind == "bone" then
                    local btype = a.boneType or b.boneType or "long"
                    need = Bones and (Bones.canFracture(btype, impactFtlb * chance) and 0.35 or 0.75) or 0.55
                elseif s.kind == "skin" then
                    need = 0.18
                end
                if chance > need or (ke > 0.005 and chance > need * 0.6) then
                    s.alive = false
                    torn[#torn + 1] = { index = si, kind = s.kind, i = s.i, j = s.j }
                    if s.kind == "bone" then
                        a.crack = 1
                        b.crack = 1
                    end
                else
                    s.rest = s.rest * (1 + 0.08 * chance)
                end
            end
        end
    end
    return torn, speed, fracturedBones
end

function SoftBody.center(body)
    local c = Vec3.new()
    local n = 0
    for _, node in ipairs(body.nodes) do
        if node.alive ~= false then
            c.x = c.x + node.x
            c.y = c.y + node.y
            c.z = c.z + node.z
            n = n + 1
        end
    end
    if n > 0 then
        c.x, c.y, c.z = c.x / n, c.y / n, c.z / n
    end
    return c
end

function SoftBody.countAliveSprings(body, kind)
    local n = 0
    for _, s in ipairs(body.springs) do
        if s.alive and (not kind or s.kind == kind) then
            n = n + 1
        end
    end
    return n
end

function SoftBody.cloneRestPose(body)
    -- Restore bind pose (used by Reset)
    for _, n in ipairs(body.nodes) do
        n.x, n.y, n.z = n.ox, n.oy, n.oz
        n.px, n.py, n.pz = n.ox, n.oy, n.oz
        n.alive = true
        n.wet = 0
        n.crack = 0
    end
    for _, s in ipairs(body.springs) do
        s.alive = true
        s.strain = 1
        -- restore rest from bind
        local a, b = body.nodes[s.i], body.nodes[s.j]
        local dx, dy, dz = a.ox - b.ox, a.oy - b.oy, a.oz - b.oz
        s.rest = math.max(0.001, math.sqrt(dx * dx + dy * dy + dz * dz))
    end
end

-- Buffer: Blood ------------------------------------------------
-- Blood.lua
-- Lightweight liquid particles: circulate in vessels, gush when torn.

Blood = {}

Blood.MAX_PARTICLES = 420
Blood.COHESION = 0.12
Blood.VISCOSITY = 0.04
Blood.GRAVITY = -9.2
Blood.GUSH_SPEED = 3.8

function Blood.new()
    return {
        particles = {},
        vessels = {}, -- polyline node-index paths that pump blood
        pumpT = 0,
    }
end

function Blood.addParticle(sys, x, y, z, opts)
    opts = opts or {}
    if #sys.particles >= Blood.MAX_PARTICLES then
        return nil
    end
    local p = {
        x = x, y = y, z = z,
        vx = opts.vx or 0,
        vy = opts.vy or 0,
        vz = opts.vz or 0,
        free = opts.free or false,
        vessel = opts.vessel,
        t = opts.t or 0,
        life = opts.life or 1,
        r = opts.r or (0.04 + math.random() * 0.03),
        fluid = opts.fluid or "blood", -- blood | bile | gastric
    }
    sys.particles[#sys.particles + 1] = p
    return #sys.particles
end

function Blood.addVessel(sys, points)
    -- points: array of {x,y,z}
    if not points or #points < 2 then
        return nil
    end
    sys.vessels[#sys.vessels + 1] = { points = points, torn = false }
    return #sys.vessels
end

local function vesselPoint(vessel, t)
    local pts = vessel.points
    local n = #pts
    if n == 1 then
        return pts[1].x, pts[1].y, pts[1].z
    end
    t = math.max(0, math.min(0.999, t))
    local f = t * (n - 1)
    local i = math.floor(f) + 1
    local u = f - (i - 1)
    local a, b = pts[i], pts[math.min(n, i + 1)]
    return a.x + (b.x - a.x) * u,
           a.y + (b.y - a.y) * u,
           a.z + (b.z - a.z) * u
end

function Blood.seedCirculation(sys, countPerVessel)
    countPerVessel = countPerVessel or 10
    for vi, v in ipairs(sys.vessels) do
        for k = 1, countPerVessel do
            local t = (k - 0.5) / countPerVessel
            local x, y, z = vesselPoint(v, t)
            Blood.addParticle(sys, x, y, z, {
                free = false,
                vessel = vi,
                t = t,
            })
        end
    end
end

-- Mark vessels near torn soft-body springs as ruptured.
function Blood.ruptureNear(sys, softBody, tornList, gushDir)
    if not tornList then
        return 0
    end
    local gushed = 0
    for _, tore in ipairs(tornList) do
        local a = softBody.nodes[tore.i]
        local b = softBody.nodes[tore.j]
        if a and b then
            local mx, my, mz = (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5
            for vi, v in ipairs(sys.vessels) do
                if not v.torn then
                    for _, p in ipairs(v.points) do
                        local dx, dy, dz = p.x - mx, p.y - my, p.z - mz
                        if dx * dx + dy * dy + dz * dz < 0.22 then
                            v.torn = true
                            break
                        end
                    end
                end
                if v.torn then
                    -- Free circulating particles on this vessel + spawn gush
                    for _, part in ipairs(sys.particles) do
                        if part.vessel == vi and not part.free then
                            part.free = true
                            local dir = gushDir or { x = 0, y = 0, z = -1 }
                            local s = Blood.GUSH_SPEED * (0.6 + math.random())
                            part.vx = dir.x * s + (math.random() - 0.5) * 2
                            part.vy = dir.y * s + (math.random() - 0.5) * 2 + 1.2
                            part.vz = dir.z * s + (math.random() - 0.5) * 2
                            gushed = gushed + 1
                        end
                    end
                    -- Extra spray bursts at tear
                    for _ = 1, 8 do
                        if #sys.particles >= Blood.MAX_PARTICLES then
                            break
                        end
                        local dir = gushDir or { x = 0, y = 0.2, z = -1 }
                        local s = Blood.GUSH_SPEED * (0.8 + math.random())
                        Blood.addParticle(sys, mx, my, mz, {
                            free = true,
                            vx = dir.x * s + (math.random() - 0.5) * 3,
                            vy = dir.y * s + math.random() * 2.5,
                            vz = dir.z * s + (math.random() - 0.5) * 3,
                            life = 1,
                        })
                        gushed = gushed + 1
                    end
                end
            end
        end
    end
    return gushed
end

function Blood.gushAt(sys, pos, dir, count, fluid)
    count = count or 18
    fluid = fluid or "blood"
    dir = Vec3.normalize(dir or Vec3.new(0, 0.2, -1))
    for _ = 1, count do
        if #sys.particles >= Blood.MAX_PARTICLES then
            break
        end
        local s = Blood.GUSH_SPEED * (0.7 + math.random() * 1.1)
        Blood.addParticle(sys, pos.x, pos.y, pos.z, {
            free = true,
            fluid = fluid,
            vx = dir.x * s + (math.random() - 0.5) * 2.5,
            vy = dir.y * s + math.random() * 2.2,
            vz = dir.z * s + (math.random() - 0.5) * 2.5,
            life = 1,
            r = 0.035 + math.random() * 0.04,
        })
    end
end

-- Simple liquid step: circulate OR free-flow with cohesion + viscosity.
function Blood.step(sys, dt, timeScale, softNodes)
    dt = (dt or 1 / 60) * (timeScale or 1)
    sys.pumpT = (sys.pumpT or 0) + dt
    local parts = sys.particles

    -- Circulation along intact vessels
    for _, p in ipairs(parts) do
        if not p.free and p.vessel and sys.vessels[p.vessel] and not sys.vessels[p.vessel].torn then
            p.t = (p.t + dt * 0.22) % 1
            local x, y, z = vesselPoint(sys.vessels[p.vessel], p.t)
            -- Pulse (heartbeat-ish)
            local pulse = 1 + 0.03 * math.sin(sys.pumpT * 6.2 + p.t * 12)
            p.x, p.y, p.z = x, y * pulse - (pulse - 1) * 0.02, z
        end
    end

    -- Neighbor cohesion (cheap O(n^2) capped)
    local n = #parts
    local limit = math.min(n, 160)
    for i = 1, limit do
        local a = parts[i]
        if a.free then
            for j = i + 1, math.min(n, i + 24) do
                local b = parts[j]
                if b.free then
                    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 > 1e-8 and d2 < 0.09 then
                        local d = math.sqrt(d2)
                        local f = (0.12 - d) * Blood.COHESION
                        local fx, fy, fz = dx / d * f, dy / d * f, dz / d * f
                        a.vx = a.vx + fx
                        a.vy = a.vy + fy
                        a.vz = a.vz + fz
                        b.vx = b.vx - fx
                        b.vy = b.vy - fy
                        b.vz = b.vz - fz
                        -- Viscosity
                        local dvx = (b.vx - a.vx) * Blood.VISCOSITY
                        local dvy = (b.vy - a.vy) * Blood.VISCOSITY
                        local dvz = (b.vz - a.vz) * Blood.VISCOSITY
                        a.vx = a.vx + dvx
                        a.vy = a.vy + dvy
                        a.vz = a.vz + dvz
                        b.vx = b.vx - dvx
                        b.vy = b.vy - dvy
                        b.vz = b.vz - dvz
                    end
                end
            end
        end
    end

    for _, p in ipairs(parts) do
        if p.free then
            p.vy = p.vy + Blood.GRAVITY * dt
            p.vx = p.vx * 0.995
            p.vy = p.vy * 0.995
            p.vz = p.vz * 0.995
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.z = p.z + p.vz * dt
            if p.y < SoftBody.GROUND_Y + 0.02 then
                p.y = SoftBody.GROUND_Y + 0.02
                p.vy = p.vy * -0.15
                p.vx = p.vx * 0.7
                p.vz = p.vz * 0.7
                p.life = p.life - dt * 0.15
            end
            p.life = p.life - dt * 0.02
        end
    end

    -- Soft collision with flesh nodes (blood pools in wounds)
    if softNodes then
        for _, p in ipairs(parts) do
            if p.free then
                for _, n in ipairs(softNodes) do
                    if n.wet and n.wet > 0.2 then
                        local dx, dy, dz = p.x - n.x, p.y - n.y, p.z - n.z
                        local d2 = dx * dx + dy * dy + dz * dz
                        if d2 < 0.05 and d2 > 1e-8 then
                            local d = math.sqrt(d2)
                            local push = (0.22 - d) * 0.5
                            p.x = p.x + dx / d * push
                            p.y = p.y + dy / d * push
                            p.z = p.z + dz / d * push
                        end
                    end
                end
            end
        end
    end
end

function Blood.reset(sys)
    sys.particles = {}
    for _, v in ipairs(sys.vessels) do
        v.torn = false
    end
    sys.pumpT = 0
    Blood.seedCirculation(sys, 9)
end

function Blood.freeCount(sys)
    local n = 0
    for _, p in ipairs(sys.particles) do
        if p.free then
            n = n + 1
        end
    end
    return n
end

-- Buffer: Anatomy ------------------------------------------------
-- Anatomy.lua
-- Builds a stylized human soft-body: skin fabric, muscle, bones, organs, vessels.

Anatomy = {}

local function ring(body, cx, cy, cz, radius, count, yAxis, opts)
    opts = opts or {}
    local ids = {}
    for i = 1, count do
        local a = (i - 1) / count * math.pi * 2
        local x = cx + math.cos(a) * radius
        local z = cz + math.sin(a) * radius
        local y = cy
        if yAxis then
            -- ring in XZ by default; yAxis unused beyond clarity
        end
        ids[i] = SoftBody.addNode(body, x, y, z, opts)
    end
    return ids
end

local function connectRings(body, a, b, kind, stiff)
    local n = #a
    for i = 1, n do
        SoftBody.addSpring(body, a[i], b[i], { kind = kind, stiffness = stiff })
        SoftBody.addSpring(body, a[i], b[(i % n) + 1], { kind = kind, stiffness = stiff * 0.85 })
        SoftBody.addSpring(body, a[(i % n) + 1], b[i], { kind = kind, stiffness = stiff * 0.85 })
        if kind == "skin" then
            SoftBody.addTriangle(body, a[i], b[i], b[(i % n) + 1], "skin")
            SoftBody.addTriangle(body, a[i], b[(i % n) + 1], a[(i % n) + 1], "skin")
        end
    end
    for i = 1, n do
        SoftBody.addSpring(body, a[i], a[(i % n) + 1], { kind = kind, stiffness = stiff })
        SoftBody.addSpring(body, b[i], b[(i % n) + 1], { kind = kind, stiffness = stiff })
    end
end

local function boneChain(body, points, boneType)
    boneType = boneType or "long"
    local ids = {}
    local br = Bones.breakStrainFor(boneType)
    for i, p in ipairs(points) do
        ids[i] = SoftBody.addNode(body, p.x, p.y, p.z, {
            kind = "bone",
            mass = 0.9 + (Bones.TYPES[boneType].density or 1.5) * 0.35,
            pinned = p.pinned,
        })
        Bones.applyToNode(body.nodes[ids[i]], boneType)
    end
    for i = 1, #ids - 1 do
        SoftBody.addSpring(body, ids[i], ids[i + 1], {
            kind = "bone",
            stiffness = 0.95,
            breakStrain = br,
        })
    end
    for i = 1, #ids - 2 do
        SoftBody.addSpring(body, ids[i], ids[i + 2], {
            kind = "bone",
            stiffness = 0.8,
            breakStrain = br * 1.05,
        })
    end
    return ids
end

local function organCluster(body, cx, cy, cz, name, scale)
    scale = scale or 0.18
    local def = Organs.DEFS[name] or { rgb = { 0.7, 0.3, 0.3 }, fluid = "blood" }
    local ids = {}
    local offsets = {
        { 0, 0, 0 },
        { 1, 0.2, 0.3 }, { -1, 0.1, 0.2 }, { 0.4, -0.8, 0.1 },
        { -0.3, 0.7, -0.4 }, { 0.6, 0.3, -0.6 }, { -0.7, -0.4, -0.2 },
    }
    for _, o in ipairs(offsets) do
        ids[#ids + 1] = SoftBody.addNode(body, cx + o[1] * scale, cy + o[2] * scale, cz + o[3] * scale, {
            kind = "organ",
            organ = name,
            fluid = def.fluid or "blood",
            mass = 0.9,
        })
    end
    for i = 1, #ids do
        for j = i + 1, #ids do
            SoftBody.addSpring(body, ids[i], ids[j], {
                kind = "muscle",
                stiffness = 0.7,
                breakStrain = 1.7,
            })
        end
    end
    return ids, { x = cx, y = cy, z = cz }, def.rgb or { 0.7, 0.3, 0.3 }
end

function Anatomy.build()
    local body = SoftBody.new()
    local meta = {
        organs = {},
        boneIds = {},
        skinRings = {},
        feet = {},
    }

    -- === Skeleton (Y up, facing -Z toward camera) ===
    local spine = boneChain(body, {
        { x = 0, y = -0.95, z = 0, pinned = true }, -- pelvis anchor
        { x = 0, y = -0.55, z = 0.02 },
        { x = 0, y = -0.15, z = 0.04 },
        { x = 0, y = 0.25, z = 0.02 },
        { x = 0, y = 0.55, z = 0 },
        { x = 0, y = 0.78, z = 0 }, -- neck
    }, "vertebra")
    meta.boneIds.spine = spine
    Bones.applyToNode(body.nodes[spine[1]], "pelvis")

    local skull = boneChain(body, {
        { x = 0, y = 0.88, z = 0 },
        { x = 0, y = 1.05, z = 0.02 },
        { x = 0, y = 1.18, z = 0 },
    }, "skull")
    SoftBody.addSpring(body, spine[#spine], skull[1], {
        kind = "bone",
        stiffness = 0.9,
        breakStrain = Bones.breakStrainFor("skull"),
    })
    meta.boneIds.skull = skull

    -- Ribs (simple pairs)
    local ribs = {}
    for i = 1, 4 do
        local y = 0.45 - (i - 1) * 0.14
        local left = SoftBody.addNode(body, -0.28 - i * 0.02, y, 0.05, { kind = "bone", mass = 1.0 })
        local right = SoftBody.addNode(body, 0.28 + i * 0.02, y, 0.05, { kind = "bone", mass = 1.0 })
        Bones.applyToNode(body.nodes[left], "rib")
        Bones.applyToNode(body.nodes[right], "rib")
        local br = Bones.breakStrainFor("rib")
        SoftBody.addSpring(body, spine[5 - math.min(i, 3)], left, { kind = "bone", stiffness = 0.88, breakStrain = br })
        SoftBody.addSpring(body, spine[5 - math.min(i, 3)], right, { kind = "bone", stiffness = 0.88, breakStrain = br })
        SoftBody.addSpring(body, left, right, { kind = "bone", stiffness = 0.75, breakStrain = br })
        ribs[#ribs + 1] = { left, right }
    end
    meta.boneIds.ribs = ribs

    -- Arms
    local function limbBones(side)
        local s = side
        local shoulder = SoftBody.addNode(body, 0.32 * s, 0.48, 0, { kind = "bone", mass = 1.2 })
        Bones.applyToNode(body.nodes[shoulder], "long")
        SoftBody.addSpring(body, spine[5], shoulder, {
            kind = "bone", stiffness = 0.9, breakStrain = Bones.breakStrainFor("long"),
        })
        local chain = boneChain(body, {
            { x = 0.38 * s, y = 0.25, z = 0.02 },
            { x = 0.42 * s, y = -0.05, z = 0.04 },
            { x = 0.45 * s, y = -0.35, z = 0.02 },
        }, "long")
        SoftBody.addSpring(body, shoulder, chain[1], {
            kind = "bone", stiffness = 0.9, breakStrain = Bones.breakStrainFor("long"),
        })
        return { shoulder, chain[1], chain[2], chain[3] }
    end
    meta.boneIds.leftArm = limbBones(-1)
    meta.boneIds.rightArm = limbBones(1)

    -- Legs
    local function legBones(side)
        local s = side
        local hip = SoftBody.addNode(body, 0.14 * s, -0.95, 0, { kind = "bone", mass = 1.3, pinned = true })
        Bones.applyToNode(body.nodes[hip], "pelvis")
        SoftBody.addSpring(body, spine[1], hip, {
            kind = "bone", stiffness = 0.95, breakStrain = Bones.breakStrainFor("pelvis"),
        })
        local chain = boneChain(body, {
            { x = 0.16 * s, y = -1.35, z = 0.02 },
            { x = 0.15 * s, y = -1.75, z = 0.04 },
            { x = 0.15 * s, y = -2.05, z = 0.06, pinned = true },
        }, "long")
        SoftBody.addSpring(body, hip, chain[1], {
            kind = "bone", stiffness = 0.92, breakStrain = Bones.breakStrainFor("long"),
        })
        meta.feet[#meta.feet + 1] = chain[#chain]
        return { hip, chain[1], chain[2], chain[3] }
    end
    meta.boneIds.leftLeg = legBones(-1)
    meta.boneIds.rightLeg = legBones(1)

    -- === Organs (functional + fluids) ===
    local function addOrgan(name, x, y, z, scale)
        local ids, center, rgb = organCluster(body, x, y, z, name, scale)
        meta.organs[#meta.organs + 1] = {
            ids = ids,
            name = name,
            rgb = rgb,
            cx = center.x, cy = center.y, cz = center.z,
            fluid = (Organs.DEFS[name] and Organs.DEFS[name].fluid) or "blood",
        }
        return ids
    end
    meta.organs = {}
    addOrgan("brain", 0, 1.05, 0.02, 0.14)
    addOrgan("heart", -0.06, 0.28, 0.06, 0.12)
    addOrgan("lungL", -0.2, 0.32, -0.02, 0.16)
    addOrgan("lungR", 0.2, 0.32, -0.02, 0.16)
    addOrgan("liver", 0.12, -0.05, 0.04, 0.17)
    addOrgan("gallbladder", 0.18, -0.12, 0.06, 0.07)
    addOrgan("stomach", -0.08, -0.12, 0.05, 0.14)
    addOrgan("kidneyL", -0.14, -0.25, -0.06, 0.09)
    addOrgan("kidneyR", 0.14, -0.25, -0.06, 0.09)
    addOrgan("spleen", -0.22, -0.02, 0.02, 0.1)

    -- Muscle bind organs to spine
    for _, org in ipairs(meta.organs) do
        local bind = (org.name == "brain") and spine[#spine] or spine[3]
        for _, id in ipairs(org.ids) do
            SoftBody.addSpring(body, id, bind, { kind = "muscle", stiffness = 0.55, breakStrain = 1.9 })
            SoftBody.addSpring(body, id, spine[4], { kind = "muscle", stiffness = 0.5, breakStrain = 1.9 })
        end
    end

    -- === Skin fabric cages (tight springs) + muscle underlayer ===
    local function torsoCage(y0, y1, layers, radius, segs)
        local ringsSkin, ringsMuscle = {}, {}
        for li = 1, layers do
            local t = (li - 1) / (layers - 1)
            local y = y0 + (y1 - y0) * t
            local r = radius * (0.85 + 0.2 * math.sin(t * math.pi))
            local skin = ring(body, 0, y, 0, r, segs, true, { kind = "skin", mass = 0.55 })
            local muscle = ring(body, 0, y, 0, r * 0.78, segs, true, { kind = "flesh", mass = 0.8 })
            ringsSkin[li] = skin
            ringsMuscle[li] = muscle
            -- Skin to muscle radial fabric
            for i = 1, segs do
                SoftBody.addSpring(body, skin[i], muscle[i], {
                    kind = "skin",
                    stiffness = 0.62,
                    breakStrain = 1.48,
                })
                SoftBody.addSpring(body, muscle[i], spine[math.min(#spine, 2 + math.floor(t * 3))], {
                    kind = "muscle",
                    stiffness = 0.48,
                    breakStrain = 2.0,
                })
            end
            if li > 1 then
                connectRings(body, ringsSkin[li - 1], skin, "skin", 0.58)
                connectRings(body, ringsMuscle[li - 1], muscle, "muscle", 0.5)
            end
        end
        meta.skinRings[#meta.skinRings + 1] = ringsSkin
        return ringsSkin, ringsMuscle
    end

    torsoCage(-0.85, 0.55, 7, 0.34, 8)

    -- Head skin
    local headRings = {}
    for li = 1, 4 do
        local t = (li - 1) / 3
        local y = 0.9 + t * 0.32
        local r = 0.16 * math.sin(math.pi * (0.25 + t * 0.7)) + 0.08
        headRings[li] = ring(body, 0, y, 0, r, 6, true, { kind = "skin", mass = 0.45 })
        if li > 1 then
            connectRings(body, headRings[li - 1], headRings[li], "skin", 0.6)
        end
        for i = 1, 6 do
            SoftBody.addSpring(body, headRings[li][i], skull[math.min(#skull, 1 + math.floor(t * 2))], {
                kind = "muscle",
                stiffness = 0.55,
                breakStrain = 1.85,
            })
        end
    end

    -- Limb soft sleeves
    local function sleeve(boneIds, radius, segs)
        local prev
        for bi, bid in ipairs(boneIds) do
            local bn = body.nodes[bid]
            local skin = ring(body, bn.x, bn.y, bn.z, radius, segs, true, { kind = "skin", mass = 0.4 })
            for i = 1, segs do
                SoftBody.addSpring(body, skin[i], bid, { kind = "muscle", stiffness = 0.55, breakStrain = 1.95 })
            end
            if prev then
                connectRings(body, prev, skin, "skin", 0.55)
            end
            prev = skin
        end
    end
    sleeve(meta.boneIds.leftArm, 0.09, 5)
    sleeve(meta.boneIds.rightArm, 0.09, 5)
    sleeve(meta.boneIds.leftLeg, 0.12, 6)
    sleeve(meta.boneIds.rightLeg, 0.12, 6)

    -- Blood vessels (paths in world space sampled from anatomy)
    local blood = Blood.new()
    Blood.addVessel(blood, {
        { x = 0, y = -0.9, z = 0.05 },
        { x = 0, y = -0.4, z = 0.06 },
        { x = 0, y = 0.1, z = 0.07 },
        { x = -0.05, y = 0.28, z = 0.08 }, -- toward heart
        { x = 0, y = 0.5, z = 0.04 },
        { x = 0, y = 0.75, z = 0.02 },
    })
    Blood.addVessel(blood, {
        { x = -0.05, y = 0.28, z = 0.08 },
        { x = -0.22, y = 0.35, z = 0.02 },
        { x = -0.35, y = 0.2, z = 0.02 },
        { x = -0.42, y = -0.1, z = 0.03 },
    })
    Blood.addVessel(blood, {
        { x = -0.05, y = 0.28, z = 0.08 },
        { x = 0.22, y = 0.35, z = 0.02 },
        { x = 0.35, y = 0.2, z = 0.02 },
        { x = 0.42, y = -0.1, z = 0.03 },
    })
    Blood.addVessel(blood, {
        { x = 0, y = -0.9, z = 0.05 },
        { x = -0.14, y = -1.3, z = 0.04 },
        { x = -0.15, y = -1.7, z = 0.05 },
    })
    Blood.addVessel(blood, {
        { x = 0, y = -0.9, z = 0.05 },
        { x = 0.14, y = -1.3, z = 0.04 },
        { x = 0.15, y = -1.7, z = 0.05 },
    })
    Blood.seedCirculation(blood, 10)

    meta.bodyCenter = Vec3.new(0, 0.05, 0)
    return body, blood, meta
end

function Anatomy.bounds(body)
    local minv = Vec3.new(1e9, 1e9, 1e9)
    local maxv = Vec3.new(-1e9, -1e9, -1e9)
    for _, n in ipairs(body.nodes) do
        if n.x < minv.x then minv.x = n.x end
        if n.y < minv.y then minv.y = n.y end
        if n.z < minv.z then minv.z = n.z end
        if n.x > maxv.x then maxv.x = n.x end
        if n.y > maxv.y then maxv.y = n.y end
        if n.z > maxv.z then maxv.z = n.z end
    end
    return minv, maxv
end

-- Buffer: Camera ------------------------------------------------
-- Camera.lua
-- Perspective camera + cinematic shot modes for Anatomy Ballistics.

Camera = {}

function Camera.new()
    return {
        eye = Vec3.new(0, 0.4, 5.2),
        target = Vec3.new(0, 0.2, 0),
        up = Vec3.new(0, 1, 0),
        fov = 55,
        mode = "aim", -- aim | side_trail | overhead | follow_slow | impact
        hold = 0,
    }
end

function Camera.basis(cam)
    local forward = Vec3.normalize(Vec3.sub(cam.target, cam.eye))
    local right = Vec3.normalize(Vec3.cross(forward, cam.up))
    -- If degenerate, pick fallback
    if Vec3.length2(right) < 1e-8 then
        right = Vec3.new(1, 0, 0)
    end
    local up = Vec3.normalize(Vec3.cross(right, forward))
    return forward, right, up
end

-- Project world point to screen. Returns x, y, depth (positive in front), visible.
function Camera.project(cam, world, width, height)
    width = width or 1024
    height = height or 768
    local forward, right, up = Camera.basis(cam)
    local rel = Vec3.sub(world, cam.eye)
    local z = Vec3.dot(rel, forward)
    if z < 0.05 then
        return 0, 0, z, false
    end
    local x = Vec3.dot(rel, right)
    local y = Vec3.dot(rel, up)
    local focal = (height * 0.5) / math.tan(math.rad((cam.fov or 55) * 0.5))
    local sx = width * 0.5 + x * focal / z
    local sy = height * 0.5 + y * focal / z
    return sx, sy, z, true
end

function Camera.lookRay(cam, screenX, screenY, width, height)
    width = width or 1024
    height = height or 768
    local forward, right, up = Camera.basis(cam)
    local focal = (height * 0.5) / math.tan(math.rad((cam.fov or 55) * 0.5))
    local nx = (screenX - width * 0.5) / focal
    local ny = (screenY - height * 0.5) / focal
    local dir = Vec3.normalize(Vec3.add(Vec3.add(forward, Vec3.scale(right, nx)), Vec3.scale(up, ny)))
    return cam.eye, dir
end

function Camera.setAim(cam, bodyCenter, rangeFeet)
    cam.mode = "aim"
    local dist = TwentyTwo and TwentyTwo.cameraDistanceForFeet(rangeFeet or cam.rangeFeet or 40)
        or 7.8
    cam.rangeFeet = rangeFeet or cam.rangeFeet or 40
    cam.eye = Vec3.new(0.15, 0.55, dist)
    cam.target = Vec3.copy(bodyCenter or Vec3.new(0, 0.2, 0))
    cam.fov = 48
    cam.hold = 0
end

function Camera.setSideTrail(cam, bullet, bodyCenter)
    cam.mode = "side_trail"
    local p = bullet and bullet.pos or bodyCenter
    cam.eye = Vec3.new(p.x + 4.8, p.y + 0.3, p.z)
    cam.target = Vec3.new(p.x, p.y, (bodyCenter and bodyCenter.z) or 0)
    cam.fov = 48
end

function Camera.setOverhead(cam, bullet, bodyCenter)
    cam.mode = "overhead"
    local p = bullet and bullet.pos or bodyCenter
    local c = bodyCenter or Vec3.new()
    local mid = Vec3.lerp(p, c, 0.45)
    cam.eye = Vec3.new(mid.x, math.max(c.y, mid.y) + 6.2, mid.z + 0.15)
    cam.target = Vec3.new(mid.x, c.y, mid.z)
    cam.up = Vec3.new(0, 0, -1)
    cam.fov = 55
end

function Camera.setFollowSlow(cam, bullet)
    cam.mode = "follow_slow"
    if not bullet then
        return
    end
    local back = Vec3.normalize(bullet.vel)
    -- Camera behind bullet looking forward
    cam.eye = Vec3.sub(bullet.pos, Vec3.scale(back, 1.35))
    cam.eye.y = cam.eye.y + 0.25
    cam.target = Vec3.add(bullet.pos, Vec3.scale(back, 2.5))
    cam.up = Vec3.new(0, 1, 0)
    cam.fov = 42
end

function Camera.setImpact(cam, hitPos, bodyCenter)
    cam.mode = "impact"
    local p = hitPos or bodyCenter or Vec3.new()
    cam.eye = Vec3.new(p.x - 0.4, p.y + 0.9, p.z + 2.2)
    cam.target = Vec3.copy(p)
    cam.up = Vec3.new(0, 1, 0)
    cam.fov = 45
    cam.hold = 1.4
    cam.impactComplete = false
end

function Camera.updateCinematic(cam, bullet, bodyCenter, impactDone, dt)
    cam.cine = cam.cine or {}
    if cam.impactComplete and impactDone then
        Camera.setAim(cam, bodyCenter, cam.rangeFeet)
        return "aim", 1
    end
    local phase = Ballistics.cinematicPhase(bullet, bodyCenter, impactDone, cam.cine, dt)
    if cam.mode == "impact" and (cam.hold or 0) > 0 then
        cam.hold = cam.hold - (dt or 0)
        if cam.hold <= 0 then
            cam.impactComplete = true
            Camera.setAim(cam, bodyCenter, cam.rangeFeet)
            cam.cine = {}
            return "aim", 1
        end
        return "impact", Ballistics.timeScaleForPhase("impact")
    end

    if phase == "side_trail" then
        cam.up = Vec3.new(0, 1, 0)
        Camera.setSideTrail(cam, bullet, bodyCenter)
    elseif phase == "overhead" then
        cam.up = Vec3.new(0, 0, -1)
        Camera.setOverhead(cam, bullet, bodyCenter)
    elseif phase == "follow_slow" then
        cam.up = Vec3.new(0, 1, 0)
        Camera.setFollowSlow(cam, bullet)
    elseif phase == "impact" then
        local hp = (bullet and bullet.hitPos) or bodyCenter
        Camera.setImpact(cam, hp, bodyCenter)
        cam.cine = {}
    else
        cam.up = Vec3.new(0, 1, 0)
        Camera.setAim(cam, bodyCenter, cam.rangeFeet)
        cam.cine = {}
    end
    return phase, Ballistics.timeScaleForPhase(phase)
end

function Camera.mathRad(deg)
    return (deg or 0) * math.pi / 180
end

-- Polyfill if Codea math.rad missing in headless tests
if not math.rad then
    function math.rad(d)
        return d * math.pi / 180
    end
end

-- Buffer: Main ------------------------------------------------
-- Anatomy Ballistics
-- Codea sandbox: .22 LR staged ranges (40→15 ft, then drywall+wood wall),
-- soft-body anatomy with functioning organs, bone density fracture thresholds,
-- circulating blood / bile, cinematic bullet cameras.
--
-- Controls:
--   Drag finger — red semi-opaque aim dot
--   Double-tap — fire (.22 LR, 3s cooldown)
--   RESET — rebuild body; stages restart at 40 ft
--   NEXT / N — advance range stage manually
--
-- Stages auto-advance after impact: 40,35,30,25,20,15 ft → house wall

DISPLAYED_NAME = "Anatomy Ballistics"
APP_VERSION = "1.1.0"

-- Tunables (sidebar)
AimSensitivity = 1
ShowBones = true
ShowOrgans = true
ShowBlood = true
GoreIntensity = 1
AutoAdvance = true

-- Runtime
cam = nil
body = nil
blood = nil
meta = nil
bullet = nil
stage = nil
organState = nil
cooldownLeft = 0
timeScale = 1
impactDone = false
pendingAdvance = false
message = "Stage 1 · 40 ft .22 LR · Double-tap to fire"
messageTimer = 4
aimScreen = nil
lastTapT, lastTapX, lastTapY = nil, nil, nil
resetBtn = { x = 0, y = 0, w = 140, h = 52 }
nextBtn = { x = 0, y = 0, w = 140, h = 52 }
cooldownFlash = 0
woundSparks = {}
wallDebris = {}
wallZ = 1.85
wallBroken = false

function setup()
    supportedOrientations(LANDSCAPE_ANY)
    displayMode(FULLSCREEN_NO_BUTTONS)

    parameter.number("AimSensitivity", 0.4, 2.0, 1)
    parameter.number("GoreIntensity", 0.4, 1.6, 1)
    parameter.boolean("ShowBones", true)
    parameter.boolean("ShowOrgans", true)
    parameter.boolean("ShowBlood", true)
    parameter.boolean("AutoAdvance", true)
    parameter.action("Reset Body", function()
        resetScene()
    end)
    parameter.action("Next Stage", function()
        advanceStage(true)
    end)
    parameter.action("Fire Test Shot", function()
        tryFire(WIDTH * 0.5, HEIGHT * 0.55)
    end)

    resetScene()
    aimScreen = { x = WIDTH * 0.5, y = HEIGHT * 0.55 }
end

function applyStageCamera()
    local snap = stage.snap
    stage.autoAdvance = AutoAdvance
    Camera.setAim(cam, meta.bodyCenter, snap.rangeFeet)
    wallBroken = false
    wallDebris = {}
end

function resetScene()
    body, blood, meta = Anatomy.build()
    organState = Organs.newState()
    stage = Stages.new(TwentyTwo.DEFAULT_LOAD)
    cam = Camera.new()
    applyStageCamera()
    bullet = nil
    cooldownLeft = 0
    timeScale = 1
    impactDone = false
    pendingAdvance = false
    woundSparks = {}
    message = "40 ft · .22 LR HV 40gr · " .. string.format("%.0f fps / %.0f ft·lbf", stage.snap.impactFps, stage.snap.impactFtlb)
    messageTimer = 3
end

function advanceStage(manual)
    local ok, snap = Stages.advance(stage)
    if ok then
        applyStageCamera()
        message = snap.label .. " · " .. string.format("%.0f fps / %.0f ft·lbf", snap.impactFps, snap.impactFtlb)
        messageTimer = 2.8
    elseif manual then
        message = "Final stage (house wall) — RESET to restart ranges"
        messageTimer = 2
    end
    pendingAdvance = false
end

function tryFire(sx, sy)
    if not Ballistics.canFire(cooldownLeft) then
        message = string.format("Chambering… %.1fs", cooldownLeft)
        messageTimer = 1.2
        cooldownFlash = 0.35
        return false
    end
    if cam.mode ~= "aim" and cam.mode ~= "impact" then
        if (cam.hold or 0) > 0 then
            return false
        end
    end
    local snap = stage.snap
    Camera.setAim(cam, meta.bodyCenter, snap.rangeFeet)
    local origin, dir = Camera.lookRay(cam, sx, sy, WIDTH, HEIGHT)
    local spawnPos = Vec3.add(origin, Vec3.scale(dir, 0.35))
    local cineSpeed = TwentyTwo.cinematicSpeed(snap.impactFps)
    bullet = Ballistics.spawn(spawnPos, dir, cineSpeed, {
        realFps = snap.impactFps,
        realFtlb = snap.impactFtlb,
        grain = snap.grain,
        caliber = snap.caliber,
        throughWall = snap.throughWall,
        stageLabel = snap.label,
    })
    cam.cine = {}
    cam.impactComplete = false
    cooldownLeft = Ballistics.COOLDOWN
    impactDone = false
    pendingAdvance = false
    Stages.onShotFired(stage)
    if snap.throughWall then
        message = string.format("Through wall · pre %.0f fps → impact %.0f fps", snap.preWallFps, snap.impactFps)
    else
        message = string.format(".22 LR @ %dft · %.0f fps · %.0f ft·lbf", snap.rangeFeet, snap.impactFps, snap.impactFtlb)
    end
    messageTimer = 1.6
    return true
end

function touched(touch)
    local state = touch.state
    local x, y = touch.x, touch.y

    if insideBtn(resetBtn, x, y) then
        if state == ENDED then
            resetScene()
        end
        return
    end
    if insideBtn(nextBtn, x, y) then
        if state == ENDED then
            advanceStage(true)
        end
        return
    end

    if state == MOVING or state == BEGAN then
        if cam.mode == "aim" or not bullet then
            aimScreen.x = x
            aimScreen.y = y
            aimScreen.x = math.max(40, math.min(WIDTH - 40, aimScreen.x))
            aimScreen.y = math.max(40, math.min(HEIGHT - 40, aimScreen.y))
        end
        aimScreen._lx, aimScreen._ly = x, y
    end

    if state == ENDED then
        aimScreen._lx, aimScreen._ly = nil, nil
        local now = ElapsedTime
        if Ballistics.doubleTap(lastTapT, lastTapX, lastTapY, now, x, y, 0.32, 56) then
            tryFire(aimScreen.x, aimScreen.y)
            lastTapT = nil
        else
            lastTapT, lastTapX, lastTapY = now, x, y
        end
    end
end

function insideBtn(b, x, y)
    return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

function insideReset(x, y)
    return insideBtn(resetBtn, x, y)
end

function keyboard(key)
    if key == "r" or key == "R" then
        resetScene()
    elseif key == "n" or key == "N" then
        advanceStage(true)
    elseif key == " " or key == "\t" then
        tryFire(aimScreen.x, aimScreen.y)
    end
end

function draw()
    updateSim()
    drawWorld()
    drawHUD()
end

function updateSim()
    local dt = DeltaTime
    if dt > 0.05 then
        dt = 0.05
    end
    cooldownLeft = Ballistics.tickCooldown(cooldownLeft, dt)
    if messageTimer > 0 then
        messageTimer = messageTimer - dt
    end
    if cooldownFlash > 0 then
        cooldownFlash = cooldownFlash - dt
    end

    local bodyCenter = SoftBody.center(body)
    meta.bodyCenter = bodyCenter
    local hb = Organs.heartbeatScale(organState)
    -- Gentle heartbeat pulse on heart organ nodes
    for _, org in ipairs(meta.organs) do
        if org.name == "heart" then
            for _, id in ipairs(org.ids) do
                local n = body.nodes[id]
                if n and n.ox then
                    local k = (hb - 1) * 0.15
                    n.x = n.ox + (n.x - n.ox) * 0.9
                    n.y = n.oy + (n.y - n.oy) * 0.9 + k * 0.02
                end
            end
        end
    end
    Organs.step(organState, dt * timeScale)

    if bullet and (bullet.alive or not impactDone) then
        local phase
        phase, timeScale = Camera.updateCinematic(cam, bullet, bodyCenter, impactDone, dt)
        if bullet.alive then
            -- Wall perforation FX (energy already reduced in stage snapshot)
            if bullet.throughWall and not bullet.wallHit and bullet.pos.z <= wallZ then
                bullet.wallHit = true
                wallBroken = true
                for _ = 1, 18 do
                    wallDebris[#wallDebris + 1] = {
                        x = bullet.pos.x + (math.random() - 0.5) * 0.4,
                        y = bullet.pos.y + (math.random() - 0.5) * 0.6,
                        z = wallZ,
                        vx = (math.random() - 0.5) * 2,
                        vy = math.random() * 1.5,
                        vz = -1 - math.random(),
                        life = 0.8 + math.random() * 0.5,
                        wood = math.random() > 0.45,
                    }
                end
            end
            Ballistics.integrate(bullet, dt * timeScale)
            local hitIdx = Ballistics.hitNodeIndex(bullet, body.nodes, 0.22)
            if hitIdx then
                local n = body.nodes[hitIdx]
                local hitPos = Vec3.new(n.x, n.y, n.z)
                local realFtlb = bullet.realFtlb or stage.snap.impactFtlb
                local realFps = bullet.realFps or stage.snap.impactFps
                -- Map real ft·lbf into soft-body KE scale + tissue radius
                local ke = (realFtlb / 140) * 0.012 * GoreIntensity
                local cavity = TwentyTwo.tempCavityScale(realFps)
                local radius = (0.42 + cavity) * GoreIntensity
                local torn, _, fractured = SoftBody.applyBulletImpact(
                    body, hitPos, bullet.vel, ke, radius, realFtlb * GoreIntensity
                )
                local organName, odist = Organs.nearestOrgan(meta.organs, hitPos)
                local quality = Organs.hitQualityFromDistance(odist, 0.32)
                local boneBlocked = n.kind == "bone" and (n.boneType == "skull" or n.boneType == "rib")
                local fluid = "blood"
                if organName then
                    Organs.applyHit(organState, organName, realFtlb, quality, boneBlocked)
                    fluid = (Organs.DEFS[organName] and Organs.DEFS[organName].fluid) or "blood"
                    -- Also damage nearby organs slightly (crush path)
                    for _, org in ipairs(meta.organs) do
                        if org.name ~= organName then
                            local d = Vec3.dist(hitPos, Vec3.new(org.cx, org.cy, org.cz))
                            if d < 0.35 then
                                Organs.applyHit(organState, org.name, realFtlb * 0.35, Organs.hitQualityFromDistance(d, 0.35), false)
                            end
                        end
                    end
                end
                Blood.ruptureNear(blood, body, torn, bullet.vel)
                Blood.gushAt(blood, hitPos, bullet.vel, math.floor(10 + realFtlb / 12), fluid)
                if fluid ~= "blood" then
                    Blood.gushAt(blood, hitPos, bullet.vel, 6, "blood")
                end
                Ballistics.markHit(bullet, hitPos, Vec3.normalize(bullet.vel))
                impactDone = true
                pendingAdvance = AutoAdvance
                Camera.setImpact(cam, hitPos, bodyCenter)
                local hitLabel = organName and (Organs.DEFS[organName].label or organName) or (n.kind or "tissue")
                local boneNote = ""
                if fractured and #fractured > 0 then
                    boneNote = " · bone fracture"
                end
                message = string.format(
                    "Hit %s · %.0f ft·lbf @ %.0f fps%s",
                    hitLabel, realFtlb, realFps, boneNote
                )
                messageTimer = 2.5
                for _ = 1, 12 do
                    woundSparks[#woundSparks + 1] = {
                        x = hitPos.x, y = hitPos.y, z = hitPos.z,
                        vx = (math.random() - 0.5) * 2,
                        vy = math.random() * 2,
                        vz = (math.random() - 0.5) * 2 - 1,
                        life = 0.6 + math.random() * 0.5,
                    }
                end
            elseif bullet.age > 8 or bullet.pos.y < -3 or Vec3.dist(bullet.pos, bodyCenter) > 16 then
                bullet.alive = false
                impactDone = true
                Camera.setAim(cam, bodyCenter, stage.snap.rangeFeet)
                message = "Miss — double-tap to fire again"
                messageTimer = 2
            end
        end
    else
        timeScale = 1
        if cam.mode == "impact" then
            cam.hold = (cam.hold or 0) - dt
            if cam.hold <= 0 then
                cam.impactComplete = true
                Camera.setAim(cam, bodyCenter, stage.snap.rangeFeet)
                if pendingAdvance then
                    advanceStage(false)
                end
            end
        elseif cam.mode ~= "aim" and (not bullet or impactDone) and (cam.hold or 0) <= 0 then
            Camera.setAim(cam, bodyCenter, stage.snap.rangeFeet)
        end
    end

    local tore = SoftBody.step(body, dt, timeScale)
    if #tore > 0 and bullet and bullet.hitPos then
        Blood.ruptureNear(blood, body, tore, bullet.vel or Vec3.new(0, 0, -1))
    end
    -- Sync blood pump rate to heart
    if blood then
        blood.pumpT = (blood.pumpT or 0)
        -- Organs.step already advanced vitals; Blood.step adds its own pumpT
    end
    if ShowBlood then
        Blood.step(blood, dt, timeScale * (0.85 + 0.3 * (organState.vitals.cardiacOutput or 1)), body.nodes)
    end

    for i = #woundSparks, 1, -1 do
        local s = woundSparks[i]
        s.life = s.life - dt
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        s.z = s.z + s.vz * dt
        s.vy = s.vy - 6 * dt
        if s.life <= 0 then
            table.remove(woundSparks, i)
        end
    end
    for i = #wallDebris, 1, -1 do
        local s = wallDebris[i]
        s.life = s.life - dt
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        s.z = s.z + s.vz * dt
        s.vy = s.vy - 8 * dt
        if s.life <= 0 then
            table.remove(wallDebris, i)
        end
    end
end

function drawWorld()
    background(18, 16, 20)
    drawFloorGrid()
    if stage and stage.snap.throughWall then
        drawHouseWall()
    end

    local order = {}
    for i, n in ipairs(body.nodes) do
        local _, _, depth, vis = Camera.project(cam, n, WIDTH, HEIGHT)
        if vis then
            order[#order + 1] = { i = i, depth = depth }
        end
    end
    table.sort(order, function(a, b)
        return a.depth > b.depth
    end)

    strokeWidth(0)
    for _, tri in ipairs(body.triangles) do
        local a, b, c = body.nodes[tri.i], body.nodes[tri.j], body.nodes[tri.k]
        local sx1, sy1, d1, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local sx2, sy2, d2, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
        local sx3, sy3, d3, v3 = Camera.project(cam, c, WIDTH, HEIGHT)
        if v1 and v2 and v3 then
            local wet = (a.wet + b.wet + c.wet) / 3
            fill(170 + wet * 50, 90 - wet * 40, 80 - wet * 30, 55 + wet * 40)
            triangle(sx1, sy1, sx2, sy2, sx3, sy3)
        end
    end

    for _, s in ipairs(body.springs) do
        if s.alive then
            local a, b = body.nodes[s.i], body.nodes[s.j]
            local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
            local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
            if v1 and v2 then
                local drawLine = true
                if s.kind == "skin" then
                    stroke(210, 140, 120, 90)
                    strokeWidth(1.2)
                elseif s.kind == "muscle" then
                    stroke(150, 45, 55, 110)
                    strokeWidth(1.6)
                elseif s.kind == "bone" then
                    if ShowBones then
                        local cr = math.max(a.crack, b.crack)
                        stroke(230 - cr * 80, 220 - cr * 100, 200 - cr * 120, 200)
                        strokeWidth(2.4)
                    else
                        drawLine = false
                    end
                else
                    stroke(180, 80, 90, 80)
                    strokeWidth(1)
                end
                if drawLine then
                    line(x1, y1, x2, y2)
                end
            end
        else
            local a, b = body.nodes[s.i], body.nodes[s.j]
            local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
            local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
            if v1 and v2 and s.kind == "skin" then
                stroke(120, 30, 35, 70)
                strokeWidth(1)
                line(x1, y1, (x1 + x2) * 0.5, (y1 + y2) * 0.5)
            end
        end
    end

    if ShowOrgans then
        noStroke()
        local hb = Organs.heartbeatScale(organState)
        for _, org in ipairs(meta.organs) do
            local integ = organState.integrity[org.name] or 1
            for _, id in ipairs(org.ids) do
                local n = body.nodes[id]
                local sx, sy, depth, vis = Camera.project(cam, n, WIDTH, HEIGHT)
                if vis then
                    local r = (7 + 40 / depth) * (org.name == "heart" and hb or 1)
                    local alpha = 100 + integ * 100
                    fill(org.rgb[1] * 255, org.rgb[2] * 255, org.rgb[3] * 255, alpha)
                    ellipse(sx, sy, r * 2, r * 2)
                end
            end
        end
    end

    if ShowBones then
        noStroke()
        for _, n in ipairs(body.nodes) do
            if n.kind == "bone" then
                local sx, sy, depth, vis = Camera.project(cam, n, WIDTH, HEIGHT)
                if vis then
                    local r = 4 + 28 / depth
                    if n.crack > 0.4 then
                        fill(255, 230, 180, 220)
                    else
                        fill(235, 225, 210, 160)
                    end
                    ellipse(sx, sy, r * 2, r * 2)
                end
            end
        end
    end

    if ShowBlood then
        noStroke()
        for _, p in ipairs(blood.particles) do
            local sx, sy, depth, vis = Camera.project(cam, p, WIDTH, HEIGHT)
            if vis then
                local r = (p.r or 0.04) * (220 / math.max(0.4, depth))
                local a = p.free and (200 * math.max(0.2, p.life)) or 160
                local cr, cg, cb = Organs.fluidColor(p.fluid or "blood")
                fill(cr, cg, cb, a)
                ellipse(sx, sy, r * 2.4, r * 2.4)
            end
        end
    end

    noStroke()
    for _, s in ipairs(woundSparks) do
        local sx, sy, _, vis = Camera.project(cam, s, WIDTH, HEIGHT)
        if vis then
            fill(160, 40, 40, 200 * s.life)
            ellipse(sx, sy, 5, 5)
        end
    end
    for _, s in ipairs(wallDebris) do
        local sx, sy, _, vis = Camera.project(cam, s, WIDTH, HEIGHT)
        if vis then
            if s.wood then
                fill(120, 85, 45, 220 * s.life)
            else
                fill(220, 220, 210, 200 * s.life)
            end
            ellipse(sx, sy, 6, 6)
        end
    end

    if bullet then
        drawBulletTrail(bullet)
        if bullet.alive or bullet.hit then
            local p = bullet.alive and bullet.pos or bullet.hitPos
            local sx, sy, depth, vis = Camera.project(cam, p, WIDTH, HEIGHT)
            if vis then
                fill(240, 220, 80, 230)
                local r = 5 + 30 / math.max(0.5, depth)
                ellipse(sx, sy, r * 2, r * 2)
            end
        end
    end
end

function drawHouseWall()
    -- Two drywall sheets + wood studs (schematic in 3D)
    local z1, z2 = wallZ + 0.08, wallZ - 0.08
    local corners = {
        { -1.2, -0.4, z1 }, { 1.2, -0.4, z1 }, { 1.2, 1.6, z1 }, { -1.2, 1.6, z1 },
    }
    local pts = {}
    local allVis = true
    for i, c in ipairs(corners) do
        local sx, sy, _, vis = Camera.project(cam, Vec3.new(c[1], c[2], c[3]), WIDTH, HEIGHT)
        pts[i] = { x = sx, y = sy }
        if not vis then allVis = false end
    end
    if allVis then
        local alpha = wallBroken and 70 or 140
        fill(210, 205, 195, alpha)
        noStroke()
        triangle(pts[1].x, pts[1].y, pts[2].x, pts[2].y, pts[3].x, pts[3].y)
        triangle(pts[1].x, pts[1].y, pts[3].x, pts[3].y, pts[4].x, pts[4].y)
        -- Studs
        stroke(110, 75, 40, 180)
        strokeWidth(3)
        for sx = -0.8, 0.8, 0.4 do
            local a = Vec3.new(sx, -0.3, wallZ)
            local b = Vec3.new(sx, 1.5, wallZ)
            local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
            local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
            if v1 and v2 then
                line(x1, y1, x2, y2)
            end
        end
        if wallBroken then
            stroke(40, 40, 40, 200)
            strokeWidth(2)
            local hx, hy = Camera.project(cam, Vec3.new(0, 0.5, wallZ), WIDTH, HEIGHT)
            line(hx - 18, hy - 10, hx + 16, hy + 12)
            line(hx - 12, hy + 14, hx + 20, hy - 8)
        end
    end
end

function drawBulletTrail(b)
    local trail = b.trail
    if not trail or #trail < 2 then
        return
    end
    -- Side-trail cinematic uses thicker red path
    local thick = (cam.mode == "side_trail") and 3.2 or 2.0
    for i = 2, #trail do
        local a, c = trail[i - 1], trail[i]
        local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local x2, y2, _, v2 = Camera.project(cam, c, WIDTH, HEIGHT)
        if v1 and v2 then
            local t = i / #trail
            stroke(255, 40 + 40 * t, 40, 80 + 140 * t)
            strokeWidth(thick)
            line(x1, y1, x2, y2)
        end
    end
    -- Predicted velocity tick
    if b.alive then
        local tip = Vec3.add(b.pos, Vec3.scale(Vec3.normalize(b.vel), 0.35))
        local x1, y1, _, v1 = Camera.project(cam, b.pos, WIDTH, HEIGHT)
        local x2, y2, _, v2 = Camera.project(cam, tip, WIDTH, HEIGHT)
        if v1 and v2 then
            stroke(255, 80, 80, 220)
            strokeWidth(2)
            line(x1, y1, x2, y2)
        end
    end
end

function drawFloorGrid()
    stroke(40, 38, 48, 120)
    strokeWidth(1)
    for gx = -3, 3 do
        local a = Vec3.new(gx * 0.7, SoftBody.GROUND_Y, -2)
        local b = Vec3.new(gx * 0.7, SoftBody.GROUND_Y, 2)
        local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
        if v1 and v2 then
            line(x1, y1, x2, y2)
        end
    end
    for gz = -3, 3 do
        local a = Vec3.new(-2.5, SoftBody.GROUND_Y, gz * 0.7)
        local b = Vec3.new(2.5, SoftBody.GROUND_Y, gz * 0.7)
        local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
        if v1 and v2 then
            line(x1, y1, x2, y2)
        end
    end
end

function drawHUD()
    if cam.mode == "aim" or not bullet or impactDone then
        local ax, ay = aimScreen.x, aimScreen.y
        noStroke()
        fill(255, 30, 30, 90)
        ellipse(ax, ay, 28, 28)
        fill(255, 40, 40, 160)
        ellipse(ax, ay, 10, 10)
        stroke(255, 60, 60, 180)
        strokeWidth(1.5)
        line(ax - 22, ay, ax - 10, ay)
        line(ax + 10, ay, ax + 22, ay)
        line(ax, ay - 22, ax, ay - 10)
        line(ax, ay + 10, ax, ay + 22)
    end

    resetBtn.x = WIDTH - 160
    resetBtn.y = HEIGHT - 70
    resetBtn.w = 140
    resetBtn.h = 48
    nextBtn.x = WIDTH - 160
    nextBtn.y = HEIGHT - 130
    nextBtn.w = 140
    nextBtn.h = 48
    noStroke()
    fill(50, 48, 58, 220)
    rect(resetBtn.x, resetBtn.y, resetBtn.w, resetBtn.h)
    fill(60, 70, 90, 220)
    rect(nextBtn.x, nextBtn.y, nextBtn.w, nextBtn.h)
    fill(230, 230, 235)
    fontSize(18)
    textAlign(CENTER)
    textMode(CENTER)
    text("RESET", resetBtn.x + resetBtn.w * 0.5, resetBtn.y + resetBtn.h * 0.5)
    text("NEXT", nextBtn.x + nextBtn.w * 0.5, nextBtn.y + nextBtn.h * 0.5)

    local cx, cy = 90, HEIGHT - 46
    fill(35, 34, 42, 220)
    rect(20, HEIGHT - 72, 150, 52)
    local ready = Ballistics.canFire(cooldownLeft)
    if ready then
        fill(80, 200, 110, 230)
        text("READY", cx, cy)
    else
        fill(220, 90, 70, 230)
        text(string.format("%.1fs", cooldownLeft), cx, cy)
        local w = 120 * (1 - cooldownLeft / Ballistics.COOLDOWN)
        fill(200, 70, 60, 180)
        rect(30, HEIGHT - 28, w, 6)
    end
    if cooldownFlash > 0 then
        fill(255, 80, 80, 80 * cooldownFlash / 0.35)
        rect(0, 0, WIDTH, HEIGHT)
    end

    -- Stage + ballistics card
    fill(20, 22, 28, 210)
    rect(20, 70, 360, 78)
    fill(230, 230, 240)
    fontSize(13)
    textAlign(LEFT)
    textMode(CORNER)
    local snap = stage.snap
    text(string.format("STAGE %d/%d  %s", snap.index, snap.maxIndex, snap.label), 30, 88)
    text(string.format(".22 LR %dgr  %.0f fps  %.0f ft·lbf  (%.0f J)",
        snap.grain, snap.impactFps, snap.impactFtlb, snap.impactJoules), 30, 108)
    if snap.throughWall then
        fill(220, 180, 120)
        text(string.format("Barrier −%.0f fps  (pre-wall %.0f fps)", snap.wallDeltaFps, snap.preWallFps), 30, 128)
    else
        fill(160, 200, 160)
        text("Open air · HV Thunderbolt-class reference", 30, 128)
    end

    -- Vitals
    fill(20, 22, 28, 210)
    rect(20, 158, 360, 72)
    fill(200, 220, 255)
    fontSize(12)
    text(Organs.summaryLine(organState), 30, 178)
    local v = organState.vitals
    -- Heartbeat bar
    local pulse = 0.5 + 0.5 * math.max(0, math.sin(v.pulseWave))
    fill(200, 50, 60, 180)
    rect(30, 198, 200 * pulse * (organState.integrity.heart or 1), 10)
    fill(180, 180, 190)
    text(string.format("Heart integ %.0f%%  Brain %.0f%%  Cardiac out %.0f%%",
        (organState.integrity.heart or 1) * 100,
        (organState.integrity.brain or 1) * 100,
        v.cardiacOutput * 100), 30, 220)

    fill(255, 255, 255, 160)
    fontSize(14)
    local modeLabel = string.upper(cam.mode or "aim")
    text(modeLabel .. string.format("  ·  x%.2f  ·  %dft", timeScale, snap.rangeFeet), 24, 28)
    text("Anatomy Ballistics " .. APP_VERSION, 24, 48)

    if messageTimer > 0 then
        fill(255, 240, 240, 220)
        fontSize(15)
        textAlign(CENTER)
        textMode(CENTER)
        text(message, WIDTH * 0.5, 36)
    end

    textAlign(CENTER)
    textMode(CENTER)
    fontSize(15)
    if cam.mode == "side_trail" then
        fill(255, 80, 80, 200)
        text("BULLET TRAIL", WIDTH * 0.5, HEIGHT - 36)
    elseif cam.mode == "overhead" then
        fill(200, 220, 255, 200)
        text("OVERHEAD CONTACT", WIDTH * 0.5, HEIGHT - 36)
    elseif cam.mode == "follow_slow" then
        fill(255, 220, 120, 200)
        text("SLOW-MO FOLLOW", WIDTH * 0.5, HEIGHT - 36)
    end
end

