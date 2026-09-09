-- Charges.lua — Placeable TNT with per-charge / per-floor delay sequencing
-- Delay range: 0.0 – 0.9 seconds (0.1 s steps). Pattern spacing supported.
--
-- Double-tap place (unlimited). Boom → exterior cam → arm → sequenced blasts.

Charges = Charges or {}

Charges.DELAY_MIN = 0.0
Charges.DELAY_MAX = 0.9
Charges.DELAY_STEP = 0.1

function Charges.newState()
    return {
        list = {},
        nextDelay = 0.0,
        nextDelayTenths = 0,
        patternStep = 0.1,   -- seconds between auto-assigned delays
        patternOn = false,
        mode = "idle",       -- idle | boom_preview | armed | firing | done
        armFlash = 0,
        fireT = 0,
        nextIndex = 1,
        boomSoundLevel = 0,
    }
end

function Charges.setDelay(state, seconds)
    local s = math.max(Charges.DELAY_MIN, math.min(Charges.DELAY_MAX, seconds or 0))
    -- Store as integer tenths of a second to avoid float drift in comparisons/UI
    local tenths = math.floor(s / Charges.DELAY_STEP + 0.5)
    state.nextDelayTenths = tenths
    state.nextDelay = tenths / 10
end

function Charges.nudgeDelay(state, dir)
    Charges.setDelay(state, state.nextDelay + dir * Charges.DELAY_STEP)
end

function Charges.togglePattern(state)
    state.patternOn = not state.patternOn
end

function Charges.clear(state)
    for _, c in ipairs(state.list) do
        if c.entity and c.entity.destroy then c.entity:destroy() end
    end
    state.list = {}
    state.mode = "idle"
    state.nextIndex = 1
    state.fireT = 0
end

function Charges.place(state, worldPos, floorIndex, massKg)
    local delay = state.nextDelay
    if state.patternOn then
        delay = (#state.list) * state.patternStep
        if delay > Charges.DELAY_MAX then
            delay = delay % (Charges.DELAY_MAX + Charges.DELAY_STEP)
        end
        delay = math.floor(delay / Charges.DELAY_STEP + 0.5) * Charges.DELAY_STEP
    end
    local e = scene:entity()
    e.x, e.y, e.z = worldPos.x, worldPos.y, worldPos.z
    e.model = craft.model.cube(vec3(0.18, 0.18, 0.18))
    e.material = craft.material(asset.builtin.Materials.Specular)
    e.material.diffuse = color(40, 160, 70)
    local charge = {
        entity = e,
        world = {x = worldPos.x, y = worldPos.y, z = worldPos.z},
        floor = floorIndex or 1,
        delay = delay,
        massKg = massKg or 0.5,
        fired = false,
        id = #state.list + 1,
    }
    table.insert(state.list, charge)
    return charge
end

function Charges.assignFloorCascade(state, floorFirst)
    -- Floor `floorFirst` detonates at 0; each other floor +patternStep later
    local floors = {}
    for _, c in ipairs(state.list) do
        floors[c.floor] = true
    end
    local order = {}
    for f, _ in pairs(floors) do table.insert(order, f) end
    table.sort(order)
    local rank = {}
    local start = floorFirst or order[1] or 1
    -- rotate so start is first
    local rotated = {}
    for _, f in ipairs(order) do
        if f >= start then table.insert(rotated, f) end
    end
    for _, f in ipairs(order) do
        if f < start then table.insert(rotated, f) end
    end
    for i, f in ipairs(rotated) do
        rank[f] = (i - 1) * state.patternStep
    end
    for _, c in ipairs(state.list) do
        c.delay = math.min(Charges.DELAY_MAX, rank[c.floor] or 0)
    end
end

function Charges.beginBoom(state)
    if #state.list == 0 then return false end
    state.mode = "boom_preview"
    state.armFlash = 0
    return true
end

function Charges.arm(state)
    if state.mode ~= "boom_preview" then return false end
    state.mode = "armed"
    state.fireT = 0
    state.nextIndex = 1
    -- sort by delay then id
    table.sort(state.list, function(a, b)
        if a.delay == b.delay then return a.id < b.id end
        return a.delay < b.delay
    end)
    return true
end

function Charges.update(state, dt, onDetonate)
    if state.mode == "boom_preview" then
        state.armFlash = state.armFlash + dt * 6
        return
    end
    if state.mode ~= "armed" and state.mode ~= "firing" then return end
    state.mode = "firing"
    state.fireT = state.fireT + dt
    for _, c in ipairs(state.list) do
        if not c.fired and state.fireT >= c.delay then
            c.fired = true
            if c.entity then
                c.entity.material.diffuse = color(255, 80, 20)
            end
            if onDetonate then onDetonate(c) end
            state.boomSoundLevel = math.max(state.boomSoundLevel, c.massKg)
        end
    end
    local all = true
    for _, c in ipairs(state.list) do
        if not c.fired then all = false; break end
    end
    if all then state.mode = "done" end
end

function Charges.drawHUD(state)
    local n = #state.list
    local y = HEIGHT - 28
    fill(230, 235, 245)
    fontSize(14)
    text(string.format("TNT x%d  delay %.1fs  pattern %s",
        n, state.nextDelay, state.patternOn and "ON" or "off"), WIDTH * 0.5, y)
    if state.mode == "boom_preview" then
        local flash = (math.floor(state.armFlash) % 2 == 0)
        if flash then
            fill(255, 30, 30)
            fontSize(22)
            text("⚠ ARM — TAP RED", WIDTH * 0.5, HEIGHT * 0.55)
        end
    elseif state.mode == "firing" then
        fill(255, 180, 60)
        text(string.format("DETONATING  t=%.2fs", state.fireT), WIDTH * 0.5, HEIGHT * 0.12)
    end
end
