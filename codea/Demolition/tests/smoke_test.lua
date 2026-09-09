-- Headless smoke test for Demolition materials encyclopedia + physics
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
STATIC, DYNAMIC, CIRCLE, POLYGON = 0, 1, 1, 2
function supportedOrientations() end
function displayMode() end
parameter = setmetatable({ number = function() end }, {
    __call = function() end, __index = function() return function() end end,
})
local bodies = {}
physics = {
    continuous = true, gravity = function() end, iterations = function() end,
    pause = function() end, resume = function() end,
    body = function()
        local b = {
            x = 0, y = 0, angle = 0, type = DYNAMIC, density = 1,
            friction = 0.5, restitution = 0.1, linearVelocity = vec2(0, 0),
            angularVelocity = 0, linearDamping = 0, angularDamping = 0,
            sleepingAllowed = true, interpolate = false, info = "",
            destroy = function(self)
                for i, x in ipairs(bodies) do if x == self then table.remove(bodies, i) break end end
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
assert(Materials.tntTonsToJoules(1) == 4.184e9)
assert(Materials.get("wood").meltC == nil and Materials.get("wood").pyroC == 290)
assert(Materials.get("glass").compressiveMPa == 900)
assert(Materials.get("steel").softenC == 550)
assert(Materials.get("rebar").reinforced == true)
assert(Materials.get("concrete").reinforced == false)

local e = 500
local g = Materials.failureStress(Materials.get("glass"), e, 0.9)
local s = Materials.failureStress(Materials.get("steel"), e, 0.9)
local cT = Materials.failureStress(Materials.get("concrete"), e, 0.9)
local cC = Materials.failureStress(Materials.get("concrete"), e, 0.1)
local rB = Materials.failureStress(Materials.get("rebar"), e, 0.9)
assert(g > s * 5, "glass << steel under tension")
assert(cT > cC, "concrete spalls in tension")
assert(rB < cT, "rebar concrete resists blast tension better than plain")
local hot = Materials.failureStress(Materials.get("steel"), e, 0.5, 600)
local cold = Materials.failureStress(Materials.get("steel"), e, 0.5, 20)
assert(hot > cold, "heated steel weaker")
local p, Z = Materials.blastImpulseAt(1.0, 0.025)
assert(p > 0 and Z > 0)
local I = Materials.blastSurfaceIntensity(Materials.tntGramsToJoules(25), 2)
assert(I > 0)
assert(#Materials.comparisonRows() >= 5)
print(string.format("OK encyclopedia glass=%.2f steel=%.2f rebar=%.2f plainC=%.2f Z=%.2f", g, s, rB, cT, Z))

assert(loadfile(ROOT .. "Levels.lua"))()
assert(loadfile(ROOT .. "Main.lua"))()
setup()
startLevel(5)
local hasRebar, hasLam = false, false
for _, b in ipairs(blocks) do
    if b.kind == "rebar" then hasRebar = true end
    if b.kind == "glass_safe" then hasLam = true end
end
assert(hasRebar and hasLam, "highrise should include rebar + laminated glass")
print("SMOKE_OK Demolition materials encyclopedia")
