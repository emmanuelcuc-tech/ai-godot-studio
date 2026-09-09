-- Headless smoke: TNT standard equivalence + Kinney-Graham
local ROOT = "codea/Demolition/"
color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
WIDTH, HEIGHT, DeltaTime, ElapsedTime = 1024, 768, 1 / 60, 0
STATIC, DYNAMIC, CIRCLE, POLYGON = 0, 1, 1, 2
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
            angularVelocity = 0, info = "",
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

assert(loadfile(ROOT .. "TNT.lua"))()
assert(TNT.J_PER_G == 4184)
assert(TNT.J_PER_TON == 4.184e9)
assert(math.abs(TNT.J_PER_TON - TNT.J_PER_G * 1e6) < 1e-6)
assert(TNT.gramsToJoules(1) == 4184)
assert(TNT.tonsToJoules(1) == 4.184e9)
assert(math.abs(TNT.joulesToTons(4.184e9) - 1) < 1e-12)
assert(TNT.gramsToTons(1e6) == 1)

local Z = TNT.scaledDistance(2.0, 0.025)
assert(math.abs(Z - 2.0 / (0.025 ^ (1 / 3))) < 1e-9)
local pNear = TNT.peakOverpressureKpa(0.5, 0.025)
local pFar = TNT.peakOverpressureKpa(8.0, 0.025)
assert(pNear > pFar)

local I = TNT.surfaceIntensity(TNT.gramsToJoules(1000), 2)
local expect = TNT.gramsToJoules(1000) / (4 * math.pi * 4)
assert(math.abs(I - expect) < 1e-6)

local ev = TNT.evaluate(25, 1.0)
assert(ev.joules == 25 * 4184)
assert(math.abs(ev.kilojoules - 104.6) < 0.01)
print(string.format("OK TNT 25g = %.1f kJ = %.6f t · Z@1m=%.3f p=%.1f kPa",
    ev.kilojoules, ev.tons, ev.Z, ev.pKpa))
print("OK format:", TNT.formatYield(25))
print("OK format 1ton:", TNT.formatYield(1e6))

assert(loadfile(ROOT .. "Materials.lua"))()
assert(Materials.TNT_J_PER_G == TNT.J_PER_G)
assert(Materials.TNT_J_PER_TON == TNT.J_PER_TON)
local p2, Z2 = Materials.blastImpulseAt(1.0, 0.025)
assert(p2 > 0 and Z2 > 0)

assert(loadfile(ROOT .. "Levels.lua"))()
assert(loadfile(ROOT .. "Main.lua"))()
assert(APP_VERSION == "1.2.0")
setup()
local grams = TNT_Grams or TNT_GRAMS
tntLeft = 1
placeTNT()
assert(#charges == 1)
local ch = charges[1]
ch.fuse = 0
detonate(ch)
charges = {}
assert(lastBlast ~= nil)
assert(lastBlast.joules == TNT.gramsToJoules(lastBlast.grams))
assert(lastBlast.joules == grams * 4184)
print("SMOKE_OK TNT equivalence")
