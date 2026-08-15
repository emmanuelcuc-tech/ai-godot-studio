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
