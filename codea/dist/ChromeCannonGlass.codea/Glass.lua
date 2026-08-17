-- Glass.lua
-- Kinetic energy + pane shatter helpers (pure math; smoke-testable outside Codea).

Glass = {}

-- LuaJIT (Codea) has math.atan2; Lua 5.3+ uses math.atan(y, x).
function Glass.atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    return math.atan(y, x)
end

-- Real kinetic energy: KE = 1/2 * m * v^2
function Glass.kineticEnergy(mass, speed)
    mass = math.max(0, mass or 0)
    speed = math.max(0, speed or 0)
    return 0.5 * mass * speed * speed
end

function Glass.speedFromVelocity(vx, vy)
    vx = vx or 0
    vy = vy or 0
    return math.sqrt(vx * vx + vy * vy)
end

-- Circle mass from density (Box2D-style area density).
function Glass.circleMass(density, radius)
    density = density or 1
    radius = radius or 1
    return density * math.pi * radius * radius
end

-- Remaining speed after spending shatterEnergy from KE (same mass).
function Glass.speedAfterEnergyLoss(mass, speed, shatterEnergy)
    local ke = Glass.kineticEnergy(mass, speed)
    local left = math.max(0, ke - (shatterEnergy or 0))
    if mass <= 0 then return 0 end
    return math.sqrt(2 * left / mass)
end

-- Pane breaks when impact KE meets threshold (scaled by hit fraction).
function Glass.shouldShatter(ke, threshold, hitFraction)
    threshold = threshold or 1
    hitFraction = hitFraction or 1
    return (ke or 0) >= threshold * math.max(0.15, hitFraction)
end

-- Build shard launch velocities from impact direction + leftover energy.
-- Returns array of {vx, vy, spin} for count shards.
function Glass.shardVelocities(count, impactVx, impactVy, leftoverKe, shardMass)
    count = math.max(1, math.floor(count or 8))
    shardMass = math.max(0.001, shardMass or 0.05)
    local impactSpeed = Glass.speedFromVelocity(impactVx, impactVy)
    local base = 0
    if leftoverKe > 0 and shardMass > 0 then
        base = math.sqrt(2 * leftoverKe / (shardMass * count))
    end
    base = base + impactSpeed * 0.35

    local out = {}
    local ang0 = Glass.atan2(impactVy, impactVx)
    if impactSpeed < 1 then
        ang0 = 0
    end
    for i = 1, count do
        local spread = ((i - 0.5) / count - 0.5) * math.pi * 0.95
        local ang = ang0 + spread
        local jitter = 0.65 + ((i * 37) % 10) * 0.04
        local sp = base * jitter
        local spin = ((i % 2 == 0) and 1 or -1) * (4 + i * 0.7)
        out[i] = {
            vx = math.cos(ang) * sp,
            vy = math.sin(ang) * sp + 40,
            spin = spin,
        }
    end
    return out
end

-- Evenly spaced pane X positions along a corridor.
function Glass.panePositions(count, firstX, spacing)
    count = math.max(1, math.floor(count or 5))
    firstX = firstX or 0
    spacing = spacing or 120
    local xs = {}
    for i = 1, count do
        xs[i] = firstX + (i - 1) * spacing
    end
    return xs
end

-- Slow-mo factor while the ball is inside the glass corridor.
function Glass.slowMoFactor(ballX, corridorStart, corridorEnd, inFlight, brokenCount, paneCount)
    if not inFlight then return 1 end
    paneCount = paneCount or 5
    brokenCount = brokenCount or 0
    if ballX < corridorStart - 40 then return 1 end
    if ballX > corridorEnd + 80 then return 1 end
    -- Deepest slo-mo while panes remain; ease out after last break
    local remain = math.max(0, paneCount - brokenCount)
    if remain <= 0 then
        return 0.45
    end
    return 0.18 + 0.04 * (paneCount - remain)
end

function Glass.cannonMuzzle(cx, cy, angle, barrelLen)
    barrelLen = barrelLen or 70
    return cx + math.cos(angle) * barrelLen, cy + math.sin(angle) * barrelLen
end

function Glass.muzzleVelocity(angle, speed)
    speed = speed or 900
    return math.cos(angle) * speed, math.sin(angle) * speed
end

-- Audio: input = mic * gain, output = peak * volume (both 0+).
function Glass.audioLevels(micAmp, inputGain, outputPeak, outputVolume)
    local inputLevel = math.max(0, (micAmp or 0) * (inputGain or 1))
    local outputLevel = math.max(0, (outputPeak or 0) * (outputVolume or 1))
    return inputLevel, outputLevel
end

function Glass.isTooLoud(inputLevel, outputLevel, threshold)
    threshold = threshold or 0.62
    local loudest = math.max(inputLevel or 0, outputLevel or 0)
    return loudest >= threshold, loudest, (inputLevel or 0) >= (outputLevel or 0) and "input" or "output"
end

-- True when InputGain or OutputVolume sliders moved enough to reset glass.
function Glass.tweakChanged(prevIn, prevOut, newIn, newOut, epsilon)
    epsilon = epsilon or 0.012
    prevIn = prevIn or newIn or 0
    prevOut = prevOut or newOut or 0
    newIn = newIn or 0
    newOut = newOut or 0
    return math.abs(newIn - prevIn) > epsilon or math.abs(newOut - prevOut) > epsilon
end

-- Grid of screen-glass tiles covering the display (centers + sizes).
function Glass.screenTileGrid(cols, rows, width, height)
    cols = math.max(1, math.floor(cols or 8))
    rows = math.max(1, math.floor(rows or 5))
    width = width or 1024
    height = height or 768
    local tw, th = width / cols, height / rows
    local tiles = {}
    for r = 1, rows do
        for c = 1, cols do
            tiles[#tiles + 1] = {
                x = (c - 0.5) * tw,
                y = (r - 0.5) * th,
                w = tw,
                h = th,
                col = c,
                row = r,
            }
        end
    end
    return tiles
end

-- Burst velocity for a screen tile flying off the display.
function Glass.screenBurstVelocity(tileX, tileY, cx, cy, loudness)
    loudness = math.max(0.2, loudness or 1)
    local dx = (tileX or 0) - (cx or 0)
    local dy = (tileY or 0) - (cy or 0)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then
        dx, dy, len = 1, 0.4, 1
    end
    local sp = 220 + loudness * 480
    return (dx / len) * sp, (dy / len) * sp + 80
end

-- Hammer strike: KE = 1/2 m v^2, quadratic falloff from the hit point.
function Glass.hammerImpact(mass, speed)
    return Glass.kineticEnergy(mass or 2.4, speed or 720)
end

function Glass.hammerFalloff(dist, radius)
    radius = math.max(1, radius or 90)
    dist = math.max(0, dist or 0)
    if dist >= radius then
        return 0
    end
    local t = 1 - dist / radius
    return t * t
end

function Glass.tileBreakThreshold(tw, th)
    local area = math.max(1, (tw or 80) * (th or 80))
    return 90 + area * 0.035
end

function Glass.hammerBreaksTile(ke, falloff, tw, th)
    return (ke or 0) * (falloff or 0) >= Glass.tileBreakThreshold(tw, th)
end

function Glass.tilesInHammerRadius(tiles, hx, hy, radius)
    local hits = {}
    radius = radius or 110
    hx, hy = hx or 0, hy or 0
    for _, t in ipairs(tiles or {}) do
        if not t.broken then
            local dx = (t.x or 0) - hx
            local dy = (t.y or 0) - hy
            local dist = math.sqrt(dx * dx + dy * dy)
            local f = Glass.hammerFalloff(dist, radius)
            if f > 0 then
                hits[#hits + 1] = { tile = t, dist = dist, falloff = f }
            end
        end
    end
    return hits
end

function Glass.hammerBurstVelocity(tileX, tileY, hx, hy, ke, shardMass)
    local dx = (tileX or 0) - (hx or 0)
    local dy = (tileY or 0) - (hy or 0)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then
        dx, dy, len = 0.25, 1, 1.03
    end
    shardMass = math.max(0.001, shardMass or 0.12)
    local speed = 140
    if (ke or 0) > 0 then
        speed = math.sqrt(2 * ke / shardMass) * 0.28 + 90
    end
    speed = math.min(880, speed)
    return (dx / len) * speed, (dy / len) * speed + 55
end

function Glass.paneHitByHammer(px, py, pw, ph, hx, hy, radius)
    pw, ph = pw or 10, ph or 220
    radius = radius or 110
    local nx = math.max((px or 0) - pw * 0.5, math.min(hx or 0, (px or 0) + pw * 0.5))
    local ny = math.max((py or 0) - ph * 0.5, math.min(hy or 0, (py or 0) + ph * 0.5))
    local dx = (hx or 0) - nx
    local dy = (hy or 0) - ny
    return dx * dx + dy * dy <= radius * radius
end

function Glass.countIntact(tiles)
    local n = 0
    for _, t in ipairs(tiles or {}) do
        if not t.broken then
            n = n + 1
        end
    end
    return n
end
