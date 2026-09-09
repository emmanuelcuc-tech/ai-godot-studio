-- Headless smoke test for Anatomy Ballistics (incl. .22 LR stages + organs).
-- Run: lua5.4 codea/AnatomyBallistics/tests/smoke_test.lua

local root = (arg and arg[0] and arg[0]:match("(.*/)") or "./") .. "../"
package.path = package.path .. ";" .. root .. "?.lua"

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

local fails = 0
local function check(name, cond, detail)
    if cond then
        print("OK  " .. name)
    else
        fails = fails + 1
        print("FAIL " .. name .. (detail and (" — " .. detail) or ""))
    end
end

-- .22 LR stage table: 40→15 by 5, then wall
check("six open ranges", #TwentyTwo.RANGE_FEET == 6)
check("starts 40 ft", TwentyTwo.RANGE_FEET[1] == 40)
check("ends 15 ft", TwentyTwo.RANGE_FEET[6] == 15)

local s40 = TwentyTwo.stageSnapshot(1, "hv")
check("stage1 40ft", s40.rangeFeet == 40 and not s40.throughWall)
check("40ft fps near muzzle HV", s40.impactFps > 1200 and s40.impactFps < 1260, tostring(s40.impactFps))
check("40ft energy > 120 ftlb", s40.impactFtlb > 120, tostring(s40.impactFtlb))

local s15 = TwentyTwo.stageSnapshot(6, "hv")
check("stage6 15ft", s15.rangeFeet == 15)
check("closer has higher/equal fps", s15.impactFps >= s40.impactFps - 1)

local sw = TwentyTwo.stageSnapshot(7, "hv")
check("wall stage", sw.throughWall == true)
check("wall reduces fps", sw.impactFps < sw.preWallFps)
check("wall delta ~270 fps", sw.wallDeltaFps == 2 * 45 + 180, tostring(sw.wallDeltaFps))

local std = TwentyTwo.stageSnapshot(1, "standard")
check("std vel ~1040+ at 40ft", std.impactFps > 1030 and std.impactFps < 1075, tostring(std.impactFps))

-- Bones
check("rib fractures easier than femur", Bones.fractureEnergyFtlb("rib") < Bones.fractureEnergyFtlb("long"))
check("rib can fracture at ~40 ftlb", Bones.canFracture("rib", 40))
check("femur resists low energy", not Bones.canFracture("long", 25))
check("femur fractures at high transfer", Bones.canFracture("long", 55))

-- Organs
local st = Organs.newState()
local dmg = Organs.applyHit(st, "heart", 130, 1, false)
check("heart takes damage", dmg > 0 and st.integrity.heart < 1)
Organs.applyHit(st, "gallbladder", 100, 1, false)
check("bile organ leaks", st.leak.gallbladder > 0)
Organs.step(st, 0.5)
check("vitals react", st.vitals.heartRate > 72 or st.vitals.cardiacOutput < 1)
check("brain activity present", st.vitals.brainActivity > 0)

-- Stages progression
local stages = Stages.new("hv")
check("stage starts 40", stages.snap.rangeFeet == 40)
for i = 1, 5 do
    Stages.advance(stages)
end
check("after 5 advances at 15", stages.snap.rangeFeet == 15)
local ok = Stages.advance(stages)
check("next is wall", ok and stages.snap.throughWall)

-- Anatomy build with new organs
local body, blood, meta = Anatomy.build()
check("has brain organ", #meta.organs >= 8)
local names = {}
for _, o in ipairs(meta.organs) do names[o.name] = true end
check("brain present", names.brain)
check("gallbladder present", names.gallbladder)
check("kidneys present", names.kidneyL and names.kidneyR)
check("bone typed", body.nodes[meta.boneIds.skull[1]].boneType == "skull")

-- Impact with real ftlb
local hit = Vec3.new(0, 0.28, 0.05)
local vel = Vec3.new(0, 0, -16)
local torn, _, fractured = SoftBody.applyBulletImpact(body, hit, vel, 0.01, 0.5, 130)
check("impact tears", #torn > 0)
Blood.gushAt(blood, hit, vel, 8, "bile")
check("bile particle", (function()
    for _, p in ipairs(blood.particles) do if p.fluid == "bile" then return true end end
    return false
end)())

-- Camera distance scales with feet
local d40 = TwentyTwo.cameraDistanceForFeet(40)
local d15 = TwentyTwo.cameraDistanceForFeet(15)
check("camera farther at 40ft", d40 > d15)

if fails > 0 then
    print("\n" .. fails .. " failure(s)")
    os.exit(1)
end
print("\nAll smoke checks passed.")
print(string.format("40ft: %.0f fps / %.0f ft·lbf | wall: %.0f fps (Δ −%.0f)",
    s40.impactFps, s40.impactFtlb, sw.impactFps, sw.wallDeltaFps))
