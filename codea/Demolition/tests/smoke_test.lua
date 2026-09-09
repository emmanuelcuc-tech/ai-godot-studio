-- Headless smoke test for Demolition materials + TNT
-- Run: lua5.4 codea/Demolition/tests/smoke_test.lua

local ROOT = "codea/Demolition/"

vec2 = function(x, y)
    local v = { x = x or 0, y = y or 0 }
    function v:len() return math.sqrt(self.x * self.x + self.y * self.y) end
    function v:normalize()
        local L = math.max(1e-9, self:len())
        return vec2(self.x / L, self.y / L)
    end
    setmetatable(v, {
        __sub = function(a, b) return vec2(a.x - b.x, a.y - b.y) end,
        __mul = function(a, b)
            if type(a) == "number" then return vec2(b.x * a, b.y * a) end
            return vec2(a.x * b, a.y * b)
        end,
    })
    return v
end

color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
WIDTH, HEIGHT, DeltaTime, ElapsedTime = 1024, 768, 1 / 60, 0
STATIC, DYNAMIC = 0, 1
CIRCLE, POLYGON = 1, 2

function supportedOrientations() end
function displayMode() end
parameter = setmetatable({ number = function() end }, {
    __call = function() end,
    __index = function() return function() end end,
})

local bodies = {}
physics = {
    continuous = true,
    gravity = function() end,
    iterations = function() end,
    pause = function() end,
    resume = function() end,
    body = function()
        local b = {
            x = 0, y = 0, angle = 0, type = DYNAMIC, density = 1,
            friction = 0.5, restitution = 0.1,
            linearVelocity = vec2(0, 0), angularVelocity = 0,
            linearDamping = 0, angularDamping = 0,
            sleepingAllowed = true, interpolate = false, info = "",
            destroy = function(self)
                for i, x in ipairs(bodies) do
                    if x == self then table.remove(bodies, i) break end
                end
            end,
        }
        table.insert(bodies, b)
        return b
    end,
}

function background() end
function fill() end
function stroke() end
function noStroke() end
function noFill() end
function strokeWidth() end
function rect() end
function ellipse() end
function line() end
function text() end
function fontSize() end
function textMode() end
function pushMatrix() end
function popMatrix() end
function translate() end
function rotate() end
function rectMode() end

assert(loadfile(ROOT .. "Materials.lua"))()
assert(Materials.TNT_J_PER_G == 4184)
assert(math.abs(Materials.TNT_J_PER_TON - 4.184e9) < 1e3)

-- Glass fails under tension much easier than steel
local glass = Materials.get("glass")
local steel = Materials.get("steel")
local wood = Materials.get("wood")
local concrete = Materials.get("concrete")
local e = 500
local gStress = Materials.failureStress(glass, e, 0.9)
local sStress = Materials.failureStress(steel, e, 0.9)
assert(gStress > sStress * 3, "glass should fail far easier than steel under tension")
local woodShock = Materials.failureStress(wood, e, 0.9)
local woodComp = Materials.failureStress(wood, e, 0.1)
assert(woodShock > woodComp, "wood weaker under shock/tension than compression path")
local concT = Materials.failureStress(concrete, e, 0.9)
local concC = Materials.failureStress(concrete, e, 0.1)
assert(concT > concC, "concrete spalls under tension more than crush")

local pNear = Materials.blastImpulseAt(0.5, 0.025)
local pFar = Materials.blastImpulseAt(5.0, 0.025)
assert(pNear > pFar, "blast falls off with distance")
print(string.format("OK materials glassStress=%.2f steelStress=%.2f blastNear=%.1f", gStress, sStress, pNear))

assert(loadfile(ROOT .. "Levels.lua"))()
assert(loadfile(ROOT .. "Main.lua"))()
assert(APP_VERSION == "1.1.0")
setup()
assert(#blocks > 0)

-- Fracture a glass block via applyMaterialDamage
local glassBlk
for _, b in ipairs(blocks) do
    if b.kind == "glass" then glassBlk = b break end
end
-- Starter shed has wood/brick only — go to glass office
startLevel(3)
glassBlk = nil
for _, b in ipairs(blocks) do
    if b.kind == "glass" then glassBlk = b break end
end
assert(glassBlk, "glass block expected on stage 3")
applyMaterialDamage(glassBlk, 2.0, 800, 0.9, 1, 0)
assert(glassBlk.broken, "glass should shatter")
assert(#debris > 0, "debris shards spawned")
print("OK glass shatter debris=" .. #debris)

-- Steel bends first
startLevel(4)
local steelBlk
for _, b in ipairs(blocks) do
    if b.kind == "steel" then steelBlk = b break end
end
assert(steelBlk)
applyMaterialDamage(steelBlk, 0.4, 400, 0.5, 1, 0)
assert(not steelBlk.broken, "steel should bend, not snap at low stress")
assert(steelBlk.bent > 0, "steel bent")
print(string.format("OK steel bend=%.2f", steelBlk.bent))

-- TNT detonation path
tntLeft = 1
placeTNT()
assert(#charges == 1)
charges[1].fuse = 0
detonate(charges[1])
charges = {}
print("OK TNT detonate")

print("SMOKE_OK Demolition materials")
