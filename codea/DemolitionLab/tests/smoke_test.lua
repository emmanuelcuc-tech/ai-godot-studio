-- Demolition Lab smoke tests (Lua 5.x / LuaJIT compatible)
-- Run: lua codea/DemolitionLab/tests/smoke_test.lua

local root = arg and arg[0] and arg[0]:match("(.*/)") or "./"
package.path = root .. "../?.lua;" .. package.path

-- Minimal Codea stubs
color = color or function(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end

dofile(root .. "../TNT.lua")
dofile(root .. "../Materials.lua")
dofile(root .. "../Blueprints.lua")
dofile(root .. "../Charges.lua")

local fails = 0
local function check(name, cond)
    if cond then
        print("OK  " .. name)
    else
        fails = fails + 1
        print("FAIL " .. name)
    end
end

-- TNT equivalence
check("TNT 1g = 4184 J", TNT.gramsToJoules(1) == 4184)
check("TNT 1 ton = 4.184e9 J", math.abs(TNT.tonsToJoules(1) - 4.184e9) < 1)
local ev = TNT.evaluate(500, 2.0)
check("TNT.evaluate fields", ev.intensity and ev.pKpa and ev.kg)

-- Materials blast
local glass = Materials.evaluateBlast("glass", { intensity = 1e8, overpressure = 80, thickness = 0.05 })
check("glass shatters under strong blast", glass.fail and glass.shatter)
local steel = Materials.evaluateBlast("steel", { intensity = 1e5, overpressure = 5, thickness = 0.2 })
check("steel resists light blast", not steel.fail)
check("estimateMass positive", Materials.estimateMass("brick", 0.1) > 1)

-- Blueprints
check("3 blueprints", Blueprints.count() == 3)
local bp = Blueprints.get(2)
check("office has floors", bp.floors and #bp.floors >= 3)
check("office has glass cells", (bp.floors[2][1]:find("G") ~= nil))

-- Charges sequencing (no Craft scene — mock place without entity)
local st = Charges.newState()
Charges.setDelay(st, 0.3)
check("delay clamp/step 0.3", math.abs(st.nextDelay - 0.3) < 1e-9)
Charges.setDelay(st, 1.5)
check("delay max 0.9", math.abs(st.nextDelay - 0.9) < 1e-9)
Charges.setDelay(st, -1)
check("delay min 0.0", st.nextDelay == 0.0)

-- Manual charge list for fire order (bypass scene:entity)
st.list = {
    { id = 1, delay = 0.2, floor = 2, massKg = 0.5, fired = false, world = {x=0,y=1,z=0} },
    { id = 2, delay = 0.0, floor = 1, massKg = 0.5, fired = false, world = {x=0,y=0,z=0} },
    { id = 3, delay = 0.1, floor = 1, massKg = 0.5, fired = false, world = {x=1,y=0,z=0} },
}
check("beginBoom", Charges.beginBoom(st))
check("arm", Charges.arm(st))
check("sorted by delay", st.list[1].delay == 0.0 and st.list[2].delay == 0.1 and st.list[3].delay == 0.2)

-- delay 0.0 fires on first tick; then 0.1 and 0.2
local fired = {}
st.mode = "armed"
st.fireT = 0
Charges.update(st, 0.001, function(c) fired[#fired+1] = c.delay end)
check("first at ~0", #fired == 1 and fired[1] == 0.0)
Charges.update(st, 0.1, function(c) fired[#fired+1] = c.delay end)
check("second at 0.1", #fired == 2 and fired[2] == 0.1)
Charges.update(st, 0.1, function(c) fired[#fired+1] = c.delay end)
check("third at 0.2", #fired == 3 and fired[3] == 0.2)
check("mode done", st.mode == "done")

Charges.assignFloorCascade(st, 1)
-- floors 1 then 2
local d1, d2
for _, c in ipairs(st.list) do
    if c.floor == 1 then d1 = c.delay end
    if c.floor == 2 then d2 = c.delay end
end
check("floor cascade order", d1 == 0.0 and d2 == 0.1)

if fails == 0 then
    print("SMOKE_OK DemolitionLab TNT materials charges sequencing")
    os.exit(0)
else
    print("SMOKE_FAIL count=" .. fails)
    os.exit(1)
end
