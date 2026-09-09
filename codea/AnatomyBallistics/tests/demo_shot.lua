-- demo_shot.lua
-- Headless cinematic shot demo: writes JSON frames for visualization.
-- Run: lua5.4 codea/AnatomyBallistics/tests/demo_shot.lua

local root = (arg and arg[0] and arg[0]:match("(.*/)") or "./") .. "../"
dofile(root .. "Vec3.lua")
dofile(root .. "Ballistics.lua")
dofile(root .. "SoftBody.lua")
dofile(root .. "Blood.lua")
dofile(root .. "Anatomy.lua")
dofile(root .. "Camera.lua")

local body, blood, meta = Anatomy.build()
local cam = Camera.new()
Camera.setAim(cam, meta.bodyCenter)

local W, H = 960, 640
local origin, dir = Camera.lookRay(cam, W * 0.5, H * 0.52, W, H)
local spawn = Vec3.add(origin, Vec3.scale(dir, 0.35))
local bullet = Ballistics.spawn(spawn, dir, Ballistics.MUZZLE_SPEED)
local impactDone = false
local frames = {}
local tornTotal = 0
local freeBloodMax = 0

local function sample(label)
    local pts = {}
    -- subsample nodes for file size
    for i = 1, #body.nodes, 3 do
        local n = body.nodes[i]
        local sx, sy, d, vis = Camera.project(cam, n, W, H)
        if vis then
            pts[#pts + 1] = {
                x = sx, y = H - sy, -- flip Y for image coords
                kind = n.kind,
                wet = n.wet,
                crack = n.crack,
            }
        end
    end
    local trail = {}
    if bullet and bullet.trail then
        for _, p in ipairs(bullet.trail) do
            local sx, sy, _, vis = Camera.project(cam, p, W, H)
            if vis then
                trail[#trail + 1] = { x = sx, y = H - sy }
            end
        end
    end
    local bloodPts = {}
    for i = 1, #blood.particles, 2 do
        local p = blood.particles[i]
        local sx, sy, _, vis = Camera.project(cam, p, W, H)
        if vis then
            bloodPts[#bloodPts + 1] = { x = sx, y = H - sy, free = p.free and 1 or 0 }
        end
    end
    local bp = bullet and (bullet.alive and bullet.pos or bullet.hitPos)
    local bx, by = nil, nil
    if bp then
        local sx, sy, _, vis = Camera.project(cam, bp, W, H)
        if vis then
            bx, by = sx, H - sy
        end
    end
    frames[#frames + 1] = {
        label = label,
        mode = cam.mode,
        timeScale = Ballistics.timeScaleForPhase(cam.mode),
        nodes = pts,
        trail = trail,
        blood = bloodPts,
        bullet = (bx and { x = bx, y = by }) or nil,
        torn = tornTotal,
        freeBlood = Blood.freeCount(blood),
    }
end

sample("aim")
for step = 1, 360 do
    local bodyCenter = SoftBody.center(body)
    local phase, ts = Camera.updateCinematic(cam, bullet, bodyCenter, impactDone, 1 / 60)
    if bullet.alive then
        Ballistics.integrate(bullet, (1 / 60) * ts)
        local hitIdx = Ballistics.hitNodeIndex(bullet, body.nodes, 0.25)
        if hitIdx then
            local n = body.nodes[hitIdx]
            local hitPos = Vec3.new(n.x, n.y, n.z)
            local ke = Ballistics.kineticEnergy(bullet.mass, Ballistics.speed(bullet.vel))
            local torn = SoftBody.applyBulletImpact(body, hitPos, bullet.vel, ke, 0.55)
            tornTotal = tornTotal + #torn
            Blood.ruptureNear(blood, body, torn, bullet.vel)
            Blood.gushAt(blood, hitPos, bullet.vel, 16)
            Ballistics.markHit(bullet, hitPos, Vec3.normalize(bullet.vel))
            impactDone = true
            Camera.setImpact(cam, hitPos, bodyCenter)
        end
    end
    local tore = SoftBody.step(body, 1 / 60, ts)
    tornTotal = tornTotal + #tore
    Blood.step(blood, 1 / 60, ts, body.nodes)
    freeBloodMax = math.max(freeBloodMax, Blood.freeCount(blood))
    -- capture whenever phase changes + periodic
    if step == 1 or step % 8 == 0 or (frames[#frames] and frames[#frames].label ~= phase) then
        sample(phase)
    end
    if impactDone and step > 200 then
        break
    end
end

-- Minimal JSON encoder
local function esc(s)
    return tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"')
end
local function encode(v)
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" then return v and "true" or "false"
    elseif t == "number" then return string.format("%.4f", v):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    elseif t == "string" then return '"' .. esc(v) .. '"'
    elseif t == "table" then
        local isArr = (#v > 0)
        if isArr then
            local parts = {}
            for i, x in ipairs(v) do parts[i] = encode(x) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, x in pairs(v) do
                parts[#parts + 1] = '"' .. esc(k) .. '":' .. encode(x)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local out = {
    width = W,
    height = H,
    frames = frames,
    summary = {
        nodes = #body.nodes,
        springs = #body.springs,
        tornTotal = tornTotal,
        freeBloodMax = freeBloodMax,
        impact = impactDone and true or false,
        trailPoints = bullet and #bullet.trail or 0,
    },
}

local path = "/opt/cursor/artifacts/anatomy_ballistics_demo_frames.json"
local f = assert(io.open(path, "w"))
f:write(encode(out))
f:close()
print("Wrote " .. path)
print(string.format("frames=%d impact=%s torn=%d freeBloodMax=%d trail=%d",
    #frames, tostring(impactDone), tornTotal, freeBloodMax, bullet and #bullet.trail or 0))
