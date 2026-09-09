-- Blood.lua
-- Lightweight liquid particles: circulate in vessels, gush when torn.

Blood = {}

Blood.MAX_PARTICLES = 420
Blood.COHESION = 0.12
Blood.VISCOSITY = 0.04
Blood.GRAVITY = -9.2
Blood.GUSH_SPEED = 3.8

function Blood.new()
    return {
        particles = {},
        vessels = {}, -- polyline node-index paths that pump blood
        pumpT = 0,
    }
end

function Blood.addParticle(sys, x, y, z, opts)
    opts = opts or {}
    if #sys.particles >= Blood.MAX_PARTICLES then
        return nil
    end
    local p = {
        x = x, y = y, z = z,
        vx = opts.vx or 0,
        vy = opts.vy or 0,
        vz = opts.vz or 0,
        free = opts.free or false,
        vessel = opts.vessel, -- vessel index when circulating
        t = opts.t or 0, -- param along vessel 0..1
        life = opts.life or 1,
        r = opts.r or (0.04 + math.random() * 0.03),
    }
    sys.particles[#sys.particles + 1] = p
    return #sys.particles
end

function Blood.addVessel(sys, points)
    -- points: array of {x,y,z}
    if not points or #points < 2 then
        return nil
    end
    sys.vessels[#sys.vessels + 1] = { points = points, torn = false }
    return #sys.vessels
end

local function vesselPoint(vessel, t)
    local pts = vessel.points
    local n = #pts
    if n == 1 then
        return pts[1].x, pts[1].y, pts[1].z
    end
    t = math.max(0, math.min(0.999, t))
    local f = t * (n - 1)
    local i = math.floor(f) + 1
    local u = f - (i - 1)
    local a, b = pts[i], pts[math.min(n, i + 1)]
    return a.x + (b.x - a.x) * u,
           a.y + (b.y - a.y) * u,
           a.z + (b.z - a.z) * u
end

function Blood.seedCirculation(sys, countPerVessel)
    countPerVessel = countPerVessel or 10
    for vi, v in ipairs(sys.vessels) do
        for k = 1, countPerVessel do
            local t = (k - 0.5) / countPerVessel
            local x, y, z = vesselPoint(v, t)
            Blood.addParticle(sys, x, y, z, {
                free = false,
                vessel = vi,
                t = t,
            })
        end
    end
end

-- Mark vessels near torn soft-body springs as ruptured.
function Blood.ruptureNear(sys, softBody, tornList, gushDir)
    if not tornList then
        return 0
    end
    local gushed = 0
    for _, tore in ipairs(tornList) do
        local a = softBody.nodes[tore.i]
        local b = softBody.nodes[tore.j]
        if a and b then
            local mx, my, mz = (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5
            for vi, v in ipairs(sys.vessels) do
                if not v.torn then
                    for _, p in ipairs(v.points) do
                        local dx, dy, dz = p.x - mx, p.y - my, p.z - mz
                        if dx * dx + dy * dy + dz * dz < 0.22 then
                            v.torn = true
                            break
                        end
                    end
                end
                if v.torn then
                    -- Free circulating particles on this vessel + spawn gush
                    for _, part in ipairs(sys.particles) do
                        if part.vessel == vi and not part.free then
                            part.free = true
                            local dir = gushDir or { x = 0, y = 0, z = -1 }
                            local s = Blood.GUSH_SPEED * (0.6 + math.random())
                            part.vx = dir.x * s + (math.random() - 0.5) * 2
                            part.vy = dir.y * s + (math.random() - 0.5) * 2 + 1.2
                            part.vz = dir.z * s + (math.random() - 0.5) * 2
                            gushed = gushed + 1
                        end
                    end
                    -- Extra spray bursts at tear
                    for _ = 1, 8 do
                        if #sys.particles >= Blood.MAX_PARTICLES then
                            break
                        end
                        local dir = gushDir or { x = 0, y = 0.2, z = -1 }
                        local s = Blood.GUSH_SPEED * (0.8 + math.random())
                        Blood.addParticle(sys, mx, my, mz, {
                            free = true,
                            vx = dir.x * s + (math.random() - 0.5) * 3,
                            vy = dir.y * s + math.random() * 2.5,
                            vz = dir.z * s + (math.random() - 0.5) * 3,
                            life = 1,
                        })
                        gushed = gushed + 1
                    end
                end
            end
        end
    end
    return gushed
end

function Blood.gushAt(sys, pos, dir, count)
    count = count or 18
    dir = Vec3.normalize(dir or Vec3.new(0, 0.2, -1))
    for _ = 1, count do
        if #sys.particles >= Blood.MAX_PARTICLES then
            break
        end
        local s = Blood.GUSH_SPEED * (0.7 + math.random() * 1.1)
        Blood.addParticle(sys, pos.x, pos.y, pos.z, {
            free = true,
            vx = dir.x * s + (math.random() - 0.5) * 2.5,
            vy = dir.y * s + math.random() * 2.2,
            vz = dir.z * s + (math.random() - 0.5) * 2.5,
            life = 1,
            r = 0.035 + math.random() * 0.04,
        })
    end
end

-- Simple liquid step: circulate OR free-flow with cohesion + viscosity.
function Blood.step(sys, dt, timeScale, softNodes)
    dt = (dt or 1 / 60) * (timeScale or 1)
    sys.pumpT = (sys.pumpT or 0) + dt
    local parts = sys.particles

    -- Circulation along intact vessels
    for _, p in ipairs(parts) do
        if not p.free and p.vessel and sys.vessels[p.vessel] and not sys.vessels[p.vessel].torn then
            p.t = (p.t + dt * 0.22) % 1
            local x, y, z = vesselPoint(sys.vessels[p.vessel], p.t)
            -- Pulse (heartbeat-ish)
            local pulse = 1 + 0.03 * math.sin(sys.pumpT * 6.2 + p.t * 12)
            p.x, p.y, p.z = x, y * pulse - (pulse - 1) * 0.02, z
        end
    end

    -- Neighbor cohesion (cheap O(n^2) capped)
    local n = #parts
    local limit = math.min(n, 160)
    for i = 1, limit do
        local a = parts[i]
        if a.free then
            for j = i + 1, math.min(n, i + 24) do
                local b = parts[j]
                if b.free then
                    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 > 1e-8 and d2 < 0.09 then
                        local d = math.sqrt(d2)
                        local f = (0.12 - d) * Blood.COHESION
                        local fx, fy, fz = dx / d * f, dy / d * f, dz / d * f
                        a.vx = a.vx + fx
                        a.vy = a.vy + fy
                        a.vz = a.vz + fz
                        b.vx = b.vx - fx
                        b.vy = b.vy - fy
                        b.vz = b.vz - fz
                        -- Viscosity
                        local dvx = (b.vx - a.vx) * Blood.VISCOSITY
                        local dvy = (b.vy - a.vy) * Blood.VISCOSITY
                        local dvz = (b.vz - a.vz) * Blood.VISCOSITY
                        a.vx = a.vx + dvx
                        a.vy = a.vy + dvy
                        a.vz = a.vz + dvz
                        b.vx = b.vx - dvx
                        b.vy = b.vy - dvy
                        b.vz = b.vz - dvz
                    end
                end
            end
        end
    end

    for _, p in ipairs(parts) do
        if p.free then
            p.vy = p.vy + Blood.GRAVITY * dt
            p.vx = p.vx * 0.995
            p.vy = p.vy * 0.995
            p.vz = p.vz * 0.995
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.z = p.z + p.vz * dt
            if p.y < SoftBody.GROUND_Y + 0.02 then
                p.y = SoftBody.GROUND_Y + 0.02
                p.vy = p.vy * -0.15
                p.vx = p.vx * 0.7
                p.vz = p.vz * 0.7
                p.life = p.life - dt * 0.15
            end
            p.life = p.life - dt * 0.02
        end
    end

    -- Soft collision with flesh nodes (blood pools in wounds)
    if softNodes then
        for _, p in ipairs(parts) do
            if p.free then
                for _, n in ipairs(softNodes) do
                    if n.wet and n.wet > 0.2 then
                        local dx, dy, dz = p.x - n.x, p.y - n.y, p.z - n.z
                        local d2 = dx * dx + dy * dy + dz * dz
                        if d2 < 0.05 and d2 > 1e-8 then
                            local d = math.sqrt(d2)
                            local push = (0.22 - d) * 0.5
                            p.x = p.x + dx / d * push
                            p.y = p.y + dy / d * push
                            p.z = p.z + dz / d * push
                        end
                    end
                end
            end
        end
    end
end

function Blood.reset(sys)
    sys.particles = {}
    for _, v in ipairs(sys.vessels) do
        v.torn = false
    end
    sys.pumpT = 0
    Blood.seedCirculation(sys, 9)
end

function Blood.freeCount(sys)
    local n = 0
    for _, p in ipairs(sys.particles) do
        if p.free then
            n = n + 1
        end
    end
    return n
end
