-- Load the packed single-file Anatomy Ballistics game (no Codea runtime).
-- Run: lua5.4 codea/AnatomyBallistics/tests/merged_load_test.lua

local here = arg and arg[0] and arg[0]:match("(.*/)") or "./"
local packed = here .. "../../../codea/dist/AnatomyBallistics.lua"

local chunk, err = loadfile(packed)
assert(chunk, "packed lua failed to parse: " .. packed .. (err and (" — " .. err) or ""))
chunk()

local fails = 0
local function check(name, cond, detail)
    if cond then
        print("OK  " .. name)
    else
        fails = fails + 1
        print("FAIL " .. name .. (detail and (" — " .. detail) or ""))
    end
end

check("packed setup exists", type(setup) == "function")
check("packed draw exists", type(draw) == "function")
check("TwentyTwo table", type(TwentyTwo) == "table")
check("Anatomy.build", type(Anatomy) == "table" and type(Anatomy.build) == "function")
check("six open ranges", #TwentyTwo.RANGE_FEET == 6)
check("starts 40 ft", TwentyTwo.RANGE_FEET[1] == 40)
check("ends 15 ft", TwentyTwo.RANGE_FEET[6] == 15)

local s40 = TwentyTwo.stageSnapshot(1, "hv")
check("40ft fps near muzzle HV", s40.impactFps > 1200 and s40.impactFps < 1260, tostring(s40.impactFps))
local sw = TwentyTwo.stageSnapshot(7, "hv")
check("wall stage", sw.throughWall == true)
check("wall reduces fps", sw.impactFps < sw.preWallFps)

local st = Organs.newState()
Organs.applyHit(st, "heart", 130, 1, false)
check("heart takes damage", st.integrity.heart < 1)

local body, blood, meta = Anatomy.build()
local names = {}
for _, o in ipairs(meta.organs) do names[o.name] = true end
check("brain present", names.brain)
check("gallbladder present", names.gallbladder)

if fails > 0 then
    print("\n" .. fails .. " failure(s)")
    os.exit(1)
end
print("\nPacked Anatomy Ballistics load checks passed.")
