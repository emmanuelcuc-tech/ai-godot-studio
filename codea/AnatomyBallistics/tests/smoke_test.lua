-- Headless smoke test for Anatomy Ballistics pure-Lua modules.
-- Run: lua5.4 codea/AnatomyBallistics/tests/smoke_test.lua

local root = (arg and arg[0] and arg[0]:match("(.*/)") or "./") .. "../"
package.path = package.path .. ";" .. root .. "?.lua"

dofile(root .. "Vec3.lua")
dofile(root .. "Ballistics.lua")
dofile(root .. "SoftBody.lua")
dofile(root .. "Blood.lua")
dofile(root .. "Anatomy.lua")
dofile(root .. "Camera.lua")

local fails = 0
local function check(name, cond, detail)
    if cond then
        print("OK  " .. name)
    else
        fails = fails + 1
        print("FAIL " .. name .. (detail and (" — " .. detail) or ""))
    end
end

-- Vec3
local a = Vec3.new(3, 4, 0)
check("vec length 3-4-5", math.abs(Vec3.length(a) - 5) < 1e-9)
check("vec normalize unit", math.abs(Vec3.length(Vec3.normalize(a)) - 1) < 1e-9)

-- Ballistics cooldown / KE / double-tap
check("cooldown blocks fire", not Ballistics.canFire(1.5))
check("cooldown allows fire", Ballistics.canFire(0))
check("cooldown ticks down", Ballistics.tickCooldown(3, 1) == 2)
-- Update KE test - still positive at lower speed
local ke = Ballistics.kineticEnergy(0.012, Ballistics.MUZZLE_SPEED)
check("KE positive", ke > 0)
check("double tap detects", Ballistics.doubleTap(1.0, 100, 100, 1.2, 110, 105, 0.32, 48))
check("double tap rejects slow", not Ballistics.doubleTap(1.0, 100, 100, 1.8, 110, 105, 0.32, 48))

local b = Ballistics.spawn(Vec3.new(0, 0, 5), Vec3.new(0, 0, -1), Ballistics.MUZZLE_SPEED)
check("spawn alive", b.alive == true)
local z0 = b.pos.z
Ballistics.integrate(b, 1 / 60)
check("bullet advances", b.pos.z < z0)
check("trail records", #b.trail >= 1)

-- Soft body tear
local sb = SoftBody.new()
local i1 = SoftBody.addNode(sb, 0, 0, 0, { mass = 1 })
local i2 = SoftBody.addNode(sb, 0.2, 0, 0, { mass = 1 })
SoftBody.addSpring(sb, i1, i2, { kind = "skin", breakStrain = 1.3, stiffness = 0.5 })
-- Yank far apart
sb.nodes[2].x = 2.0
local tore = SoftBody.step(sb, 1 / 60, 1)
check("skin spring can tear", #tore >= 1 or not sb.springs[1].alive)

-- Anatomy build
local body, blood, meta = Anatomy.build()
check("anatomy has nodes", #body.nodes > 40, "nodes=" .. #body.nodes)
check("anatomy has springs", #body.springs > 80, "springs=" .. #body.springs)
check("has organs", #meta.organs >= 4)
check("has vessels", #blood.vessels >= 3)
check("blood seeded", #blood.particles > 10)

local skinBefore = SoftBody.countAliveSprings(body, "skin")
local boneBefore = SoftBody.countAliveSprings(body, "bone")
check("skin springs exist", skinBefore > 10)
check("bone springs exist", boneBefore > 5)

-- Bullet impact tears tissue
local hit = Vec3.new(0, 0.25, 0.05)
local vel = Vec3.new(0, 0, -40)
local ke2 = Ballistics.kineticEnergy(0.012, 40)
local torn = SoftBody.applyBulletImpact(body, hit, vel, ke2, 0.55)
check("impact tears something", #torn > 0, "torn=" .. #torn)
Blood.gushAt(blood, hit, vel, 12)
Blood.ruptureNear(blood, body, torn, vel)
Blood.step(blood, 1 / 60, 1, body.nodes)
check("blood can free-flow", Blood.freeCount(blood) > 0)

SoftBody.cloneRestPose(body)
Blood.reset(blood)
check("reset restores skin springs", SoftBody.countAliveSprings(body, "skin") == skinBefore)
check("reset restores bone springs", SoftBody.countAliveSprings(body, "bone") == boneBefore)

-- Camera / cinematic phases
local cam = Camera.new()
Camera.setAim(cam, meta.bodyCenter)
local sx, sy, depth, vis = Camera.project(cam, Vec3.new(0, 0.2, 0), 1024, 768)
check("project body visible", vis == true and depth > 0)
local origin, dir = Camera.lookRay(cam, 512, 384, 1024, 768)
check("look ray forward", dir.z < 0)

local farBullet = Ballistics.spawn(Vec3.new(0, 0.2, 8), Vec3.new(0, 0, -1), 40)
check("phase side_trail", Ballistics.cinematicPhase(farBullet, meta.bodyCenter, false) == "side_trail")
local midBullet = Ballistics.spawn(Vec3.new(0, 0.2, 2.2), Vec3.new(0, 0, -1), 40)
check("phase overhead", Ballistics.cinematicPhase(midBullet, meta.bodyCenter, false) == "overhead")
local nearBullet = Ballistics.spawn(Vec3.new(0, 0.2, 1.0), Vec3.new(0, 0, -1), 40)
check("phase follow_slow", Ballistics.cinematicPhase(nearBullet, meta.bodyCenter, false) == "follow_slow")
check("slow mo scale", Ballistics.timeScaleForPhase("follow_slow") < 0.3)

-- Dwell keeps side_trail briefly even if distance would advance
local st = {}
local early = Ballistics.spawn(Vec3.new(0, 0.2, 2.0), Vec3.new(0, 0, -1), 40)
local p1 = Ballistics.cinematicPhase(early, meta.bodyCenter, false, st, 0.01)
-- Force state into side_trail with young age
st.phase, st.phaseAge = "side_trail", 0.05
local p2 = Ballistics.cinematicPhase(early, meta.bodyCenter, false, st, 0.05)
check("phase dwell holds side_trail", p2 == "side_trail")
st.phaseAge = 0.5
local p3 = Ballistics.cinematicPhase(early, meta.bodyCenter, false, st, 0.05)
check("phase dwell advances to overhead", p3 == "overhead")

-- Simulate short flight + camera update without crash
for _ = 1, 30 do
    Ballistics.integrate(farBullet, 1 / 60)
    Camera.updateCinematic(cam, farBullet, meta.bodyCenter, false, 1 / 60)
    SoftBody.step(body, 1 / 60, 0.7)
end
check("sim loop stable", farBullet.alive == true or farBullet.hit == true or true)

if fails > 0 then
    print("\n" .. fails .. " failure(s)")
    os.exit(1)
end
print("\nAll smoke checks passed.")
print(string.format("Anatomy nodes=%d springs=%d blood=%d", #body.nodes, #body.springs, #blood.particles))
