-- demo_shot.lua — headless cinematic + stage ballistics demo
local root = (arg and arg[0] and arg[0]:match("(.*/)") or "./") .. "../"
dofile(root .. "Vec3.lua")
dofile(root .. "TwentyTwo.lua")
dofile(root .. "Bones.lua")
dofile(root .. "Organs.lua")
dofile(root .. "Stages.lua")
dofile(root .. "Ballistics.lua")
dofile(root .. "SoftBody.lua")
dofile(root .. "Blood.lua")
dofile(root .. "Anatomy.lua")
dofile(root .. "Camera.lua")

local body, blood, meta = Anatomy.build()
local organState = Organs.newState()
local stage = Stages.new("hv")
local cam = Camera.new()
Camera.setAim(cam, meta.bodyCenter, stage.snap.rangeFeet)

local W, H = 960, 640
local snap = stage.snap
local origin, dir = Camera.lookRay(cam, W * 0.5, H * 0.52, W, H)
local spawn = Vec3.add(origin, Vec3.scale(dir, 0.35))
local bullet = Ballistics.spawn(spawn, dir, TwentyTwo.cinematicSpeed(snap.impactFps), {
    realFps = snap.impactFps,
    realFtlb = snap.impactFtlb,
    grain = snap.grain,
    throughWall = false,
})
local impactDone = false
local frames = {}
local tornTotal = 0

local function sample(label)
    local pts = {}
    for i = 1, #body.nodes, 3 do
        local n = body.nodes[i]
        local sx, sy, d, vis = Camera.project(cam, n, W, H)
        if vis then
            pts[#pts + 1] = { x = sx, y = H - sy, kind = n.kind, wet = n.wet, crack = n.crack }
        end
    end
    local trail = {}
    if bullet and bullet.trail then
        for _, p in ipairs(bullet.trail) do
            local sx, sy, _, vis = Camera.project(cam, p, W, H)
            if vis then trail[#trail + 1] = { x = sx, y = H - sy } end
        end
    end
    local bloodPts = {}
    for i = 1, #blood.particles, 2 do
        local p = blood.particles[i]
        local sx, sy, _, vis = Camera.project(cam, p, W, H)
        if vis then bloodPts[#bloodPts + 1] = { x = sx, y = H - sy, free = p.free and 1 or 0, fluid = p.fluid or "blood" } end
    end
    local bp = bullet and (bullet.alive and bullet.pos or bullet.hitPos)
    local bx, by = nil, nil
    if bp then
        local sx, sy, _, vis = Camera.project(cam, bp, W, H)
        if vis then bx, by = sx, H - sy end
    end
    frames[#frames + 1] = {
        label = label,
        mode = cam.mode,
        timeScale = Ballistics.timeScaleForPhase(cam.mode),
        nodes = pts,
        trail = trail,
        blood = bloodPts,
        bullet = bx and { x = bx, y = by } or nil,
        torn = tornTotal,
        freeBlood = Blood.freeCount(blood),
        rangeFeet = stage.snap.rangeFeet,
        fps = bullet and bullet.realFps or snap.impactFps,
        ftlb = bullet and bullet.realFtlb or snap.impactFtlb,
        hr = organState.vitals.heartRate,
        brain = organState.vitals.brainActivity,
    }
end

sample("aim")
for step = 1, 360 do
    local bodyCenter = SoftBody.center(body)
    Organs.step(organState, (1 / 60) * (timeScale or 1))
    local phase, ts = Camera.updateCinematic(cam, bullet, bodyCenter, impactDone, 1 / 60)
    timeScale = ts
    if bullet.alive then
        Ballistics.integrate(bullet, (1 / 60) * ts)
        local hitIdx = Ballistics.hitNodeIndex(bullet, body.nodes, 0.25)
        if hitIdx then
            local n = body.nodes[hitIdx]
            local hitPos = Vec3.new(n.x, n.y, n.z)
            local ke = (bullet.realFtlb / 140) * 0.012
            local torn = SoftBody.applyBulletImpact(body, hitPos, bullet.vel, ke, 0.5, bullet.realFtlb)
            tornTotal = tornTotal + #torn
            local organName, odist = Organs.nearestOrgan(meta.organs, hitPos)
            if organName then
                Organs.applyHit(organState, organName, bullet.realFtlb, Organs.hitQualityFromDistance(odist, 0.32), false)
            end
            Blood.gushAt(blood, hitPos, bullet.vel, 16, organName and Organs.DEFS[organName].fluid or "blood")
            Ballistics.markHit(bullet, hitPos, Vec3.normalize(bullet.vel))
            impactDone = true
            Camera.setImpact(cam, hitPos, bodyCenter)
        end
    end
    local tore = SoftBody.step(body, 1 / 60, ts)
    tornTotal = tornTotal + #tore
    Blood.step(blood, 1 / 60, ts, body.nodes)
    if step == 1 or step % 8 == 0 or (frames[#frames] and frames[#frames].label ~= phase) then
        sample(phase)
    end
    if impactDone and step > 200 then break end
end

-- Also snapshot wall stage energy for log
local wall = TwentyTwo.stageSnapshot(7, "hv")

local function esc(s) return tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"') end
local function encode(v)
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" then return v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge then return "0" end
        return string.format("%.4f", v):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    elseif t == "string" then return '"' .. esc(v) .. '"'
    elseif t == "table" then
        if #v > 0 then
            local parts = {}
            for i, x in ipairs(v) do parts[i] = encode(x) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = '"' .. esc(k) .. '":' .. encode(x) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local out = {
    width = W, height = H, frames = frames,
    summary = {
        nodes = #body.nodes,
        springs = #body.springs,
        tornTotal = tornTotal,
        freeBloodMax = Blood.freeCount(blood),
        impact = impactDone and true or false,
        rangeFeet = 40,
        impactFps = snap.impactFps,
        impactFtlb = snap.impactFtlb,
        wallFps = wall.impactFps,
        wallDelta = wall.wallDeltaFps,
        heartRate = organState.vitals.heartRate,
        brain = organState.vitals.brainActivity,
        heartInteg = organState.integrity.heart,
    },
}
local path = "/opt/cursor/artifacts/anatomy_ballistics_demo_frames.json"
local f = assert(io.open(path, "w"))
f:write(encode(out))
f:close()
print("Wrote " .. path)
print(string.format("40ft: %.0ffps/%.0fftlb torn=%d HR=%.0f brain=%.2f wall=%.0ffps",
    snap.impactFps, snap.impactFtlb, tornTotal,
    organState.vitals.heartRate, organState.vitals.brainActivity, wall.impactFps))
