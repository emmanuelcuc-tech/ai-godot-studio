-- Building.lua — Brick-by-brick + glass from blueprint floors (Codea Craft)
-- Each cell / half-brick / glass pane is an independent rigidbody entity.

Building = Building or {}

local MAT_COLORS = {
    brick      = color(168, 72, 52),
    concrete   = color(150, 148, 140),
    wood       = color(140, 95, 48),
    steel      = color(120, 130, 145),
    rebar      = color(130, 135, 145),
    glass      = color(160, 205, 225, 90),
    glass_safe = color(150, 200, 220, 110),
}

function Building.clear(state)
    if not state.parts then return end
    for _, p in ipairs(state.parts) do
        if p.entity and p.entity.destroy then p.entity:destroy() end
    end
    state.parts = {}
end

local function spawnPart(state, kind, wx, wy, wz, sx, sy, sz)
    local e = scene:entity()
    e.x, e.y, e.z = wx, wy, wz
    e.model = craft.model.cube(vec3(sx, sy, sz))
    e.material = craft.material(asset.builtin.Materials.Specular)
    e.material.diffuse = MAT_COLORS[kind] or color(180, 180, 180)
    if kind == "glass" or kind == "glass_safe" then
        e.material.opacity = 0.35
    end
    -- Photo textures when present in project Assets/Textures
    local texKey = kind
    if kind == "glass_safe" then texKey = "glass" end
    if kind == "rebar" then texKey = "concrete" end
    if asset and asset.Documents and readImage then
        -- optional: user drops brick.png etc into project
    end
    e:add(craft.rigidbody, STATIC, 0)
    e:add(craft.shape.box, vec3(sx, sy, sz))
    local vol = sx * sy * sz
    local part = {
        entity = e,
        kind = kind,
        sx = sx, sy = sy, sz = sz,
        mass = Materials.estimateMass(kind, vol),
        broken = false,
        world = { x = wx, y = wy, z = wz },
        floor = state._floorBuilding or 1,
    }
    table.insert(state.parts, part)
    return part
end

function Building.build(state, bp)
    Building.clear(state)
    state.parts = {}
    state.blueprint = bp
    local floors = bp.floors or {}
    local cell = bp.cell or 0.5
    local storyH = bp.storyHeight or 1.0
    local maxRows, maxCols = 1, 1
    for _, plan in ipairs(floors) do
        maxRows = math.max(maxRows, #plan)
        maxCols = math.max(maxCols, #plan[1])
    end
    local ox = -(maxCols * cell) * 0.5
    local oz = -(maxRows * cell) * 0.5

    for f = 1, #floors do
        state._floorBuilding = f
        local plan = floors[f]
        local y0 = (f - 1) * storyH
        local rows = #plan
        -- floor slab under occupied cells
        for r = 1, rows do
            for c = 1, #plan[r] do
                local ch = plan[r]:sub(c, c)
                if ch ~= "." and ch ~= " " then
                    local wx = ox + (c - 0.5) * cell
                    local wz = oz + (r - 0.5) * cell
                    spawnPart(state, "concrete", wx, y0, wz, cell * 0.98, cell * 0.22, cell * 0.98)
                end
            end
        end
        -- walls brick-by-brick / glass panes
        for r = 1, rows do
            for c = 1, #plan[r] do
                local ch = plan[r]:sub(c, c)
                if ch == "." or ch == " " then goto cont end
                local kind = Materials.fromChar(ch)
                local wx = ox + (c - 0.5) * cell
                local wz = oz + (r - 0.5) * cell
                local wallH = storyH * 0.85
                if kind == "glass" or kind == "glass_safe" then
                    spawnPart(state, kind, wx, y0 + cell * 0.22 + wallH * 0.5, wz,
                        cell * 0.9, wallH * 0.88, cell * 0.07)
                else
                    local bh = wallH * 0.48
                    spawnPart(state, kind, wx, y0 + cell * 0.22 + bh * 0.5, wz,
                        cell * 0.95, bh, cell * 0.95)
                    spawnPart(state, kind, wx, y0 + cell * 0.22 + bh * 1.55, wz,
                        cell * 0.95, bh, cell * 0.95)
                end
                ::cont::
            end
        end
    end
    state.floorCount = #floors
    state.bounds = {
        w = maxCols * cell,
        d = maxRows * cell,
        h = #floors * storyH,
        cell = cell,
        storyHeight = storyH,
    }
    state.notes = bp.name or bp.id or "Building"
end

function Building.applyBlast(state, charge)
    local origin = charge.world
    local grams = (charge.massKg or 0.5) * 1000
    local hits = 0
    for _, p in ipairs(state.parts) do
        if p.broken then goto next end
        local dx = p.world.x - origin.x
        local dy = p.world.y - origin.y
        local dz = p.world.z - origin.z
        local R = math.sqrt(dx * dx + dy * dy + dz * dz)
        if R < 0.05 then R = 0.05 end
        local ev = TNT.evaluate(grams, R)
        local result = Materials.evaluateBlast(p.kind, {
            intensity = ev.intensity,
            overpressure = ev.pKpa,
            distance = R,
            grams = grams,
            thickness = math.min(p.sx, p.sz),
            mass = p.mass,
        })
        if result.fail then
            p.broken = true
            hits = hits + 1
            local e = p.entity
            if e then
                if e.rigidbody then e:remove(craft.rigidbody) end
                e:add(craft.rigidbody, DYNAMIC, math.max(1, p.mass))
                local nx, ny, nz = dx / R, dy / R, dz / R
                local kick = math.min(40, (ev.pKpa or 1) / math.max(1, p.mass) * 0.8)
                if e.rigidbody and e.rigidbody.applyForce then
                    e.rigidbody:applyForce(vec3(nx, ny + 0.45, nz) * kick * 50)
                end
                if (p.kind == "glass" or p.kind == "glass_safe") and e.material then
                    e.material.diffuse = color(200, 220, 235, 35)
                    e.material.opacity = 0.15
                end
            end
        elseif result.dent and p.entity and p.entity.material then
            p.entity.material.diffuse = color(90, 95, 100)
        end
        ::next::
    end
    return hits
end
