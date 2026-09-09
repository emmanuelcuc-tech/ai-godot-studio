-- Headless smoke test for Demolition (no Codea runtime required)
-- Run from repo root: lua5.4 codea/Demolition/tests/smoke_test.lua

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
WIDTH, HEIGHT = 1024, 768
DeltaTime = 1 / 60
STATIC, DYNAMIC = 0, 1
BEGAN, MOVING, ENDED = 0, 1, 2

function supportedOrientations() end
function displayMode() end
parameter = setmetatable({}, {
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
            x = 0, y = 0, angle = 0, type = DYNAMIC,
            density = 1, friction = 0.5, restitution = 0.1,
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
CIRCLE, POLYGON = 1, 2

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
CENTER, CORNER = 1, 0

assert(loadfile(ROOT .. "Levels.lua"))()
assert(Levels.count() == 5, "expected 5 levels")
for i = 1, Levels.count() do
    local d, idx = Levels.get(i)
    assert(idx == i)
    local cols = #d.map[1]
    local blocksN = 0
    for r, line in ipairs(d.map) do
        assert(#line == cols, string.format("level %d row %d width mismatch", i, r))
        for c = 1, #line do
            local ch = line:sub(c, c)
            if ch ~= "." and ch ~= " " then blocksN = blocksN + 1 end
        end
    end
    assert(blocksN > 0)
    print(string.format("OK level %d %-18s blocks=%d shots=%d", i, d.name, blocksN, d.shots or 4))
end

assert(loadfile(ROOT .. "Main.lua"))()
assert(DISPLAYED_NAME == "Demolition")
setup()
assert(#blocks > 0, "blocks built")
assert(ball ~= nil, "ball spawned")
assert(state == "aim")

dragStart = vec2(ball.x, ball.y)
dragNow = vec2(ball.x - 120, ball.y + 20)
local shotsBefore = shotsLeft
launchBall()
assert(state == "flying")
assert(shotsLeft == shotsBefore - 1)

local need = math.ceil(initialBlockCount * WIN_RATIO)
for i = 1, need do
    if blocks[i] then blocks[i].scored = true end
end
shotsLeft = 0
evaluateStage()
assert(state == "won", "expected won, got " .. tostring(state))

print("SMOKE_OK Demolition")
