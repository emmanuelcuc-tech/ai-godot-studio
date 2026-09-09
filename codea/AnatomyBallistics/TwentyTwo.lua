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
