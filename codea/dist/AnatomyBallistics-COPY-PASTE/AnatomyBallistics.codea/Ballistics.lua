-- Ballistics.lua
-- Bullet flight, cooldown, kinetic energy, trajectory sampling.

Ballistics = {}

Ballistics.COOLDOWN = 3.0
Ballistics.MUZZLE_SPEED = 16 -- world units / second (cinematic flight length)
Ballistics.MASS = 0.012
Ballistics.RADIUS = 0.08
Ballistics.GRAVITY = -1.6 -- mild arc in world space
Ballistics.DRAG = 0.06

function Ballistics.kineticEnergy(mass, speed)
    mass = math.max(0, mass or 0)
    speed = math.max(0, speed or 0)
    return 0.5 * mass * speed * speed
end

function Ballistics.speed(v)
    return Vec3.length(v or Vec3.new())
end

function Ballistics.canFire(cooldownLeft)
    return (cooldownLeft or 0) <= 0
end

function Ballistics.tickCooldown(cooldownLeft, dt)
    return math.max(0, (cooldownLeft or 0) - (dt or 0))
end

-- Spawn a bullet from eye toward aim direction.
-- opts: { realFps, realFtlb, grain, caliber, throughWall, stageLabel }
function Ballistics.spawn(origin, direction, speed, opts)
    opts = opts or {}
    speed = speed or Ballistics.MUZZLE_SPEED
    local dir = Vec3.normalize(direction)
    local mass = Ballistics.MASS
    if opts.grain then
        -- Keep sim mass stable; real grain used for damage tables only
        mass = Ballistics.MASS
    end
    return {
        pos = Vec3.copy(origin),
        vel = Vec3.scale(dir, speed),
        mass = mass,
        radius = Ballistics.RADIUS,
        alive = true,
        age = 0,
        trail = { Vec3.copy(origin) },
        hit = false,
        hitPos = nil,
        hitNormal = nil,
        realFps = opts.realFps,
        realFtlb = opts.realFtlb,
        grain = opts.grain or 40,
        caliber = opts.caliber or ".22 LR",
        throughWall = opts.throughWall or false,
        stageLabel = opts.stageLabel,
        wallHit = false,
    }
end

function Ballistics.integrate(bullet, dt)
    if not bullet or not bullet.alive then
        return bullet
    end
    dt = dt or (1 / 60)
    bullet.age = (bullet.age or 0) + dt
    -- Gravity + linear drag
    bullet.vel.y = bullet.vel.y + Ballistics.GRAVITY * dt
    local damp = math.max(0, 1 - Ballistics.DRAG * dt)
    bullet.vel.x = bullet.vel.x * damp
    bullet.vel.y = bullet.vel.y * damp
    bullet.vel.z = bullet.vel.z * damp
    bullet.pos.x = bullet.pos.x + bullet.vel.x * dt
    bullet.pos.y = bullet.pos.y + bullet.vel.y * dt
    bullet.pos.z = bullet.pos.z + bullet.vel.z * dt

    local trail = bullet.trail
    local last = trail[#trail]
    if (not last) or Vec3.dist(last, bullet.pos) > 0.12 then
        trail[#trail + 1] = Vec3.copy(bullet.pos)
        if #trail > 180 then
            table.remove(trail, 1)
        end
    end
    return bullet
end

-- Double-tap detector: returns true when second tap qualifies.
function Ballistics.doubleTap(prevT, prevX, prevY, nowT, x, y, maxDt, maxDist)
    maxDt = maxDt or 0.32
    maxDist = maxDist or 48
    if not prevT then
        return false
    end
    local dt = nowT - prevT
    if dt <= 0 or dt > maxDt then
        return false
    end
    local dx, dy = (x or 0) - (prevX or 0), (y or 0) - (prevY or 0)
    return math.sqrt(dx * dx + dy * dy) <= maxDist
end

-- Soft hit test against point cloud (soft-body nodes).
-- Returns index of closest node within radius, or nil.
function Ballistics.hitNodeIndex(bullet, nodes, pad)
    if not bullet or not bullet.alive or not nodes then
        return nil
    end
    pad = pad or 0.15
    local best, bestD = nil, (bullet.radius + pad)
    bestD = bestD * bestD
    for i, n in ipairs(nodes) do
        if n.alive ~= false then
            local dx = n.x - bullet.pos.x
            local dy = n.y - bullet.pos.y
            local dz = n.z - bullet.pos.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 <= bestD then
                bestD = d2
                best = i
            end
        end
    end
    return best
end

function Ballistics.markHit(bullet, pos, normal)
    bullet.hit = true
    bullet.alive = false
    bullet.hitPos = Vec3.copy(pos)
    bullet.hitNormal = normal and Vec3.copy(normal) or Vec3.new(0, 0, -1)
    bullet.trail[#bullet.trail + 1] = Vec3.copy(pos)
    return bullet
end

-- Phase of the cinematic based on bullet distance to body center.
-- Returns: "side_trail" | "overhead" | "follow_slow" | "impact"
-- Optional state table tracks minimum dwell so overhead is not skipped.
function Ballistics.cinematicPhase(bullet, bodyCenter, impactDone, state, dt)
    if impactDone or (bullet and bullet.hit) then
        return "impact"
    end
    if not bullet or not bullet.alive then
        return "aim"
    end
    local d = Vec3.dist(bullet.pos, bodyCenter)
    local desired
    if d > 3.6 then
        desired = "side_trail"
    elseif d > 1.35 then
        desired = "overhead"
    else
        desired = "follow_slow"
    end
    -- Enforce brief dwell in side_trail → overhead → follow_slow
    if state then
        dt = dt or 0
        state.phase = state.phase or desired
        state.phaseAge = (state.phaseAge or 0) + dt
        local minDwell = {
            side_trail = 0.22,
            overhead = 0.30,
            follow_slow = 0.18,
        }
        local order = { side_trail = 1, overhead = 2, follow_slow = 3, impact = 4 }
        local cur, want = order[state.phase] or 1, order[desired] or 1
        if want > cur and state.phaseAge < (minDwell[state.phase] or 0) then
            desired = state.phase
        elseif desired ~= state.phase and want >= cur then
            state.phase = desired
            state.phaseAge = 0
        else
            desired = state.phase
        end
        if desired ~= state.phase then
            state.phase = desired
            state.phaseAge = 0
        end
    end
    return desired
end

function Ballistics.timeScaleForPhase(phase)
    if phase == "follow_slow" or phase == "impact" then
        return 0.18
    elseif phase == "overhead" then
        return 0.45
    elseif phase == "side_trail" then
        return 0.7
    end
    return 1
end
