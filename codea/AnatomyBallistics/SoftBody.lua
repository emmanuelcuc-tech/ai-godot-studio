-- SoftBody.lua
-- Verlet soft body: fabric skin, elastic muscle, breakable bones.

SoftBody = {}

SoftBody.GRAVITY = -6.5
SoftBody.ITERATIONS = 4
SoftBody.GROUND_Y = -2.15

function SoftBody.new()
    return {
        nodes = {},
        springs = {},
        triangles = {}, -- for skin shading {i,j,k, layer}
    }
end

function SoftBody.addNode(body, x, y, z, opts)
    opts = opts or {}
    local n = {
        x = x, y = y, z = z,
        px = x, py = y, pz = z, -- previous for Verlet
        ox = x, oy = y, oz = z, -- rest / bind pose
        mass = opts.mass or 1,
        invMass = 0,
        pinned = opts.pinned or false,
        kind = opts.kind or "flesh", -- flesh | bone | organ | skin
        organ = opts.organ,
        alive = true,
        wet = 0,
        crack = 0,
    }
    if n.pinned or n.mass <= 0 then
        n.invMass = 0
    else
        n.invMass = 1 / n.mass
    end
    body.nodes[#body.nodes + 1] = n
    return #body.nodes
end

function SoftBody.addSpring(body, i, j, opts)
    opts = opts or {}
    local a, b = body.nodes[i], body.nodes[j]
    if not a or not b then
        return nil
    end
    local rest = opts.rest
    if not rest then
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        rest = math.sqrt(dx * dx + dy * dy + dz * dz)
    end
    local s = {
        i = i,
        j = j,
        rest = math.max(0.001, rest),
        stiffness = opts.stiffness or 0.35,
        damping = opts.damping or 0.02,
        breakStrain = opts.breakStrain or 1.85, -- ratio of length/rest
        kind = opts.kind or "muscle", -- skin | muscle | bone | vessel
        alive = true,
        strain = 1,
    }
    -- Bones tolerate less stretch before cracking
    if s.kind == "bone" then
        s.breakStrain = opts.breakStrain or 1.22
        s.stiffness = opts.stiffness or 0.92
    elseif s.kind == "skin" then
        s.breakStrain = opts.breakStrain or 1.55
        s.stiffness = opts.stiffness or 0.55
    elseif s.kind == "vessel" then
        s.breakStrain = opts.breakStrain or 1.35
        s.stiffness = opts.stiffness or 0.4
    end
    body.springs[#body.springs + 1] = s
    return #body.springs
end

function SoftBody.addTriangle(body, i, j, k, layer)
    body.triangles[#body.triangles + 1] = { i = i, j = j, k = k, layer = layer or "skin" }
end

local function constrainSpring(body, s)
    if not s.alive then
        return false
    end
    local a, b = body.nodes[s.i], body.nodes[s.j]
    if not a or not b or a.alive == false or b.alive == false then
        s.alive = false
        return false
    end
    local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1e-8 then
        return false
    end
    s.strain = len / s.rest
    if s.strain > s.breakStrain then
        s.alive = false
        if s.kind == "bone" then
            a.crack = 1
            b.crack = 1
        end
        return true -- tore
    end
    local inv = a.invMass + b.invMass
    if inv <= 0 then
        return false
    end
    local diff = (len - s.rest) / len
    local corr = diff * s.stiffness
    local cx, cy, cz = dx * corr, dy * corr, dz * corr
    local wA = a.invMass / inv
    local wB = b.invMass / inv
    a.x = a.x + cx * wA
    a.y = a.y + cy * wA
    a.z = a.z + cz * wA
    b.x = b.x - cx * wB
    b.y = b.y - cy * wB
    b.z = b.z - cz * wB
    return false
end

function SoftBody.step(body, dt, timeScale)
    dt = (dt or 1 / 60) * (timeScale or 1)
    if dt <= 0 then
        return {}
    end
    local tore = {}
    local nodes = body.nodes
    -- Verlet integrate
    for _, n in ipairs(nodes) do
        if n.alive ~= false and not n.pinned and n.invMass > 0 then
            local vx = (n.x - n.px)
            local vy = (n.y - n.py)
            local vz = (n.z - n.pz)
            n.px, n.py, n.pz = n.x, n.y, n.z
            local damp = 0.994
            n.x = n.x + vx * damp
            n.y = n.y + vy * damp + SoftBody.GRAVITY * dt * dt
            n.z = n.z + vz * damp
            if n.y < SoftBody.GROUND_Y then
                n.y = SoftBody.GROUND_Y
                n.py = n.y + (n.y - n.py) * -0.2
            end
        end
    end
    for _ = 1, SoftBody.ITERATIONS do
        for si, s in ipairs(body.springs) do
            if constrainSpring(body, s) then
                tore[#tore + 1] = { index = si, kind = s.kind, i = s.i, j = s.j }
            end
        end
    end
    return tore
end

-- Apply bullet impulse + tear nearby springs (fabric pull / rip).
-- impactFtlb: real .22 ft·lbf for bone fracture thresholds.
function SoftBody.applyBulletImpact(body, hitPos, velocity, ke, radius, impactFtlb)
    radius = radius or 0.45
    impactFtlb = impactFtlb or (ke * 80) -- fallback scale
    local torn = {}
    local speed = Vec3.length(velocity)
    local dir = Vec3.normalize(velocity)
    local impulseScale = 0.015 + ke * 8
    local fracturedBones = {}

    for _, n in ipairs(body.nodes) do
        if n.alive ~= false and not n.pinned then
            local dx, dy, dz = n.x - hitPos.x, n.y - hitPos.y, n.z - hitPos.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d < radius then
                local w = (1 - d / radius)
                w = w * w
                local push = impulseScale * w * n.invMass
                n.x = n.x + (dir.x * push + dx * 0.35 * w)
                n.y = n.y + (dir.y * push + dy * 0.35 * w)
                n.z = n.z + (dir.z * push + dz * 0.35 * w)
                n.wet = math.min(1, n.wet + w * 0.8)
                if n.kind == "bone" then
                    local btype = n.boneType or "long"
                    local localE = impactFtlb * w
                    if Bones and Bones.canFracture(btype, localE) then
                        n.crack = 1
                        fracturedBones[#fracturedBones + 1] = { type = btype, energy = localE }
                    else
                        n.crack = math.min(1, n.crack + w * 0.5)
                    end
                end
            end
        end
    end

    for si, s in ipairs(body.springs) do
        if s.alive then
            local a, b = body.nodes[s.i], body.nodes[s.j]
            local mx = (a.x + b.x) * 0.5
            local my = (a.y + b.y) * 0.5
            local mz = (a.z + b.z) * 0.5
            local dx, dy, dz = mx - hitPos.x, my - hitPos.y, mz - hitPos.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            local tearR = radius * (s.kind == "skin" and 1.15 or (s.kind == "bone" and 0.55 or 0.9))
            if d < tearR then
                local chance = (1 - d / tearR)
                local need = 0.25
                if s.kind == "bone" then
                    local btype = a.boneType or b.boneType or "long"
                    need = Bones and (Bones.canFracture(btype, impactFtlb * chance) and 0.35 or 0.75) or 0.55
                elseif s.kind == "skin" then
                    need = 0.18
                end
                if chance > need or (ke > 0.005 and chance > need * 0.6) then
                    s.alive = false
                    torn[#torn + 1] = { index = si, kind = s.kind, i = s.i, j = s.j }
                    if s.kind == "bone" then
                        a.crack = 1
                        b.crack = 1
                    end
                else
                    s.rest = s.rest * (1 + 0.08 * chance)
                end
            end
        end
    end
    return torn, speed, fracturedBones
end

function SoftBody.center(body)
    local c = Vec3.new()
    local n = 0
    for _, node in ipairs(body.nodes) do
        if node.alive ~= false then
            c.x = c.x + node.x
            c.y = c.y + node.y
            c.z = c.z + node.z
            n = n + 1
        end
    end
    if n > 0 then
        c.x, c.y, c.z = c.x / n, c.y / n, c.z / n
    end
    return c
end

function SoftBody.countAliveSprings(body, kind)
    local n = 0
    for _, s in ipairs(body.springs) do
        if s.alive and (not kind or s.kind == kind) then
            n = n + 1
        end
    end
    return n
end

function SoftBody.cloneRestPose(body)
    -- Restore bind pose (used by Reset)
    for _, n in ipairs(body.nodes) do
        n.x, n.y, n.z = n.ox, n.oy, n.oz
        n.px, n.py, n.pz = n.ox, n.oy, n.oz
        n.alive = true
        n.wet = 0
        n.crack = 0
    end
    for _, s in ipairs(body.springs) do
        s.alive = true
        s.strain = 1
        -- restore rest from bind
        local a, b = body.nodes[s.i], body.nodes[s.j]
        local dx, dy, dz = a.ox - b.ox, a.oy - b.oy, a.oz - b.oz
        s.rest = math.max(0.001, math.sqrt(dx * dx + dy * dy + dz * dz))
    end
end
