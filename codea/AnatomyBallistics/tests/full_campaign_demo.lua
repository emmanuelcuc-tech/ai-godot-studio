-- full_campaign_demo.lua
-- Simulates stages 40ft → 15ft → wall with hits; writes JSON for video render.
-- Run: lua5.4 codea/AnatomyBallistics/tests/full_campaign_demo.lua

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

local W, H = 960, 540
local body, blood, meta = Anatomy.build()
local organState = Organs.newState()
local stage = Stages.new("hv")
local cam = Camera.new()
local frames = {}
local wallZ = 1.85
local bullet = nil
local wallBroken = false

local function encode(v)
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" then return v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "0" end
        return (string.format("%.3f", v):gsub("(%..-)0+$", "%1"):gsub("%.$", ""))
    elseif t == "string" then return '"' .. tostring(v):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
    elseif t == "table" then
        if #v > 0 then
            local p = {}
            for i, x in ipairs(v) do p[i] = encode(x) end
            return "[" .. table.concat(p, ",") .. "]"
        end
        local p = {}
        for k, x in pairs(v) do p[#p + 1] = '"' .. tostring(k) .. '":' .. encode(x) end
        return "{" .. table.concat(p, ",") .. "}"
    end
    return "null"
end

local function sample(tag)
    local snap = stage.snap
    local pts = {}
    for i = 1, #body.nodes, 2 do
        local n = body.nodes[i]
        local sx, sy, d, vis = Camera.project(cam, n, W, H)
        if vis then
            pts[#pts + 1] = {
                x = sx, y = H - sy, kind = n.kind, wet = n.wet or 0,
                crack = n.crack or 0, organ = n.organ,
            }
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
    for i = 1, math.min(#blood.particles, 220) do
        local p = blood.particles[i]
        local sx, sy, _, vis = Camera.project(cam, p, W, H)
        if vis then
            bloodPts[#bloodPts + 1] = {
                x = sx, y = H - sy, free = p.free and 1 or 0,
                fluid = p.fluid or "blood",
            }
        end
    end
    local bx, by = nil, nil
    if bullet then
        local p = bullet.alive and bullet.pos or bullet.hitPos
        if p then
            local sx, sy, _, vis = Camera.project(cam, p, W, H)
            if vis then bx, by = sx, H - sy end
        end
    end
    -- wall corners projected
    local wall = nil
    if snap.throughWall then
        wall = { broken = wallBroken and 1 or 0, pts = {} }
        local corners = { {-1.2,-0.4,wallZ},{1.2,-0.4,wallZ},{1.2,1.6,wallZ},{-1.2,1.6,wallZ} }
        for _, c in ipairs(corners) do
            local sx, sy, _, vis = Camera.project(cam, Vec3.new(c[1], c[2], c[3]), W, H)
            if vis then wall.pts[#wall.pts + 1] = { x = sx, y = H - sy } end
        end
    end
    frames[#frames + 1] = {
        tag = tag,
        mode = cam.mode,
        stage = snap.index,
        rangeFeet = snap.rangeFeet,
        throughWall = snap.throughWall and 1 or 0,
        fps = snap.impactFps,
        ftlb = snap.impactFtlb,
        preWallFps = snap.preWallFps,
        wallDelta = snap.wallDeltaFps or 0,
        nodes = pts,
        trail = trail,
        blood = bloodPts,
        bullet = bx and { x = bx, y = by } or nil,
        wall = wall,
        hr = organState.vitals.heartRate,
        brain = organState.vitals.brainActivity,
        spo2 = organState.vitals.oxygenation,
        bile = organState.vitals.bileFlow,
        heart = organState.integrity.heart,
        tornSkin = SoftBody.countAliveSprings(body, "skin"),
        freeBlood = Blood.freeCount(blood),
        timeScale = Ballistics.timeScaleForPhase(cam.mode),
    }
end

local function fireAt(aimX, aimY)
    local snap = stage.snap
    Camera.setAim(cam, meta.bodyCenter, snap.rangeFeet)
    cam.cine = {}
    cam.impactComplete = false
    wallBroken = false
    local origin, dir = Camera.lookRay(cam, aimX, aimY, W, H)
    local spawn = Vec3.add(origin, Vec3.scale(dir, 0.35))
    bullet = Ballistics.spawn(spawn, dir, TwentyTwo.cinematicSpeed(snap.impactFps), {
        realFps = snap.impactFps,
        realFtlb = snap.impactFtlb,
        grain = snap.grain,
        throughWall = snap.throughWall,
    })
end

local function simulateShot(maxSteps)
    maxSteps = maxSteps or 320
    local impactDone = false
    for step = 1, maxSteps do
        local bodyCenter = SoftBody.center(body)
        Organs.step(organState, 1 / 60)
        local phase, ts = Camera.updateCinematic(cam, bullet, bodyCenter, impactDone, 1 / 60)
        if bullet and bullet.alive then
            if bullet.throughWall and not bullet.wallHit and bullet.pos.z <= wallZ then
                bullet.wallHit = true
                wallBroken = true
            end
            Ballistics.integrate(bullet, (1 / 60) * ts)
            local hitIdx = Ballistics.hitNodeIndex(bullet, body.nodes, 0.28)
            if hitIdx then
                local n = body.nodes[hitIdx]
                local hitPos = Vec3.new(n.x, n.y, n.z)
                local ke = (bullet.realFtlb / 140) * 0.012
                local torn = SoftBody.applyBulletImpact(body, hitPos, bullet.vel, ke, 0.55, bullet.realFtlb)
                local organName, odist = Organs.nearestOrgan(meta.organs, hitPos)
                if organName then
                    Organs.applyHit(organState, organName, bullet.realFtlb,
                        Organs.hitQualityFromDistance(odist, 0.35), n.kind == "bone")
                end
                Blood.ruptureNear(blood, body, torn, bullet.vel)
                Blood.gushAt(blood, hitPos, bullet.vel, 14,
                    organName and Organs.DEFS[organName].fluid or "blood")
                Ballistics.markHit(bullet, hitPos, Vec3.normalize(bullet.vel))
                impactDone = true
                Camera.setImpact(cam, hitPos, bodyCenter)
            elseif bullet.age > 7 then
                bullet.alive = false
                impactDone = true
            end
        elseif impactDone and cam.mode == "impact" then
            cam.hold = (cam.hold or 1.4) - 1 / 60
            if cam.hold <= 0 then
                cam.impactComplete = true
                Camera.setAim(cam, bodyCenter, stage.snap.rangeFeet)
            end
        end
        SoftBody.step(body, 1 / 60, ts)
        Blood.step(blood, 1 / 60, ts, body.nodes)
        if step == 1 or step % 4 == 0 or phase ~= (frames[#frames] and frames[#frames].mode) then
            sample(phase)
        end
        if impactDone and cam.impactComplete then
            sample("post")
            break
        end
        if impactDone and step > 260 then
            sample("post")
            break
        end
    end
end

-- Campaign: shoot at 40, 30, 20, 15, then wall
local stagesToShoot = { 1, 3, 5, 6, 7 } -- indices
print("Campaign demo start")
for _, want in ipairs(stagesToShoot) do
    while stage.index < want do
        Stages.advance(stage)
    end
    Stages.refresh(stage)
    Camera.setAim(cam, SoftBody.center(body), stage.snap.rangeFeet)
    sample("stage_intro")
    -- Aim slightly off-center for variety
    local ax = W * (0.48 + (want % 3) * 0.02)
    local ay = H * (0.50 + (want % 2) * 0.03)
    fireAt(ax, ay)
    simulateShot(340)
    print(string.format("  stage %d @ %sft wall=%s HR=%.0f brain=%.0f%% freeBlood=%d",
        stage.snap.index, tostring(stage.snap.rangeFeet),
        tostring(stage.snap.throughWall),
        organState.vitals.heartRate,
        organState.vitals.brainActivity * 100,
        Blood.freeCount(blood)))
    if stage.index < 7 then
        Stages.advance(stage)
    end
end

local out = {
    width = W, height = H, frames = frames,
    summary = {
        frameCount = #frames,
        organs = #meta.organs,
        nodes = #body.nodes,
        finalHR = organState.vitals.heartRate,
        finalBrain = organState.vitals.brainActivity,
        finalHeart = organState.integrity.heart,
        freeBlood = Blood.freeCount(blood),
    },
}
local path = "/opt/cursor/artifacts/anatomy_campaign_frames.json"
local f = assert(io.open(path, "w"))
f:write(encode(out))
f:close()
print("Wrote " .. path .. " frames=" .. #frames)
