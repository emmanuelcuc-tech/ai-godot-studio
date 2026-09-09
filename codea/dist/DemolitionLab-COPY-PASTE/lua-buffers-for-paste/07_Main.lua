-- Main.lua — Demolition Lab (Codea Craft)
-- 3D brick-by-brick buildings, photo materials, orbit camera, sequenced TNT.
--
-- Controls:
--   Drag          orbit camera 360°
--   Pinch / +/-   zoom
--   Double-tap    place TNT (unlimited) at hit point
--   [ ]           delay − / +  (0.0–0.9 s)
--   P             toggle pattern spacing (0.1 s between charges)
--   F             floor cascade (selected floor first)
--   B             BOOM → pull exterior cam → flashing ARM
--   Tap red ARM   fire sequenced charges (buzz + boom)
--   1/2/3         shed / office / highrise blueprints
--   R             reset building + charges

viewer.mode = FULLSCREEN

local state = {
    building = { parts = {} },
    charges = nil,
    cam = nil,
    lastTap = 0,
    lastTapPos = vec2(0, 0),
    selectedFloor = 1,
    bpIndex = 1,
    message = "Double-tap to place TNT · B = BOOM",
    msgT = 4,
    hapticPending = false,
    boomPulse = 0,
}

local ui = {
    boom = {x = 0, y = 0, w = 110, h = 44},
    arm  = {x = 0, y = 0, w = 120, h = 120},
}

local function toast(msg, t)
    state.message = msg
    state.msgT = t or 2.5
end

local function loadBlueprint(i)
    state.bpIndex = i
    local bp = Blueprints.get(i)
    Building.build(state.building, bp)
    Charges.clear(state.charges)
    state.selectedFloor = 1
    local b = state.building.bounds
    CameraOrbit.focus(state.cam, vec3(0, b.h * 0.45, 0))
    CameraOrbit.setDistance(state.cam, math.max(8, b.w * 2.2))
    toast((bp.name or "Building") .. " · brick-by-brick + glass", 3)
end

function setup()
    scene = craft.scene()
    scene.sky.active = true
    scene.sun.rotation = quat.eulerAngles(40, -35, 0)

    -- ground
    local ground = scene:entity()
    ground.model = craft.model.cube(vec3(40, 0.2, 40))
    ground.y = -0.1
    ground.material = craft.material(asset.builtin.Materials.Specular)
    ground.material.diffuse = color(55, 70, 50)
    ground:add(craft.rigidbody, STATIC, 0)
    ground:add(craft.shape.box, vec3(40, 0.2, 40))

    state.cam = CameraOrbit.new(scene.camera, {
        target = vec3(0, 2, 0),
        distance = 12,
        yaw = 35,
        pitch = 22,
        minDist = 3,
        maxDist = 40,
    })
    state.charges = Charges.newState()
    loadBlueprint(1)

    parameter.watch("state.message")
end

local function hitWorldFromTouch(x, y)
    -- Approximate ray onto building volume (Craft raycast when available)
    if scene.camera and scene.camera.raycast then
        local hit = scene.camera:raycast(x, y)
        if hit and hit.point then
            return vec3(hit.point.x, hit.point.y, hit.point.z), hit
        end
    end
    -- Fallback: project onto focus plane
    local t = state.cam.target
    local yaw = math.rad(state.cam.yaw)
    local dist = state.cam.distance * 0.35
    local ox = (x / WIDTH - 0.5) * dist
    local oy = (y / HEIGHT - 0.5) * dist * 0.8
    return vec3(t.x + ox, math.max(0.3, t.y + oy), t.z), nil
end

local function floorAtY(y)
    local cellH = 0.5 * 2.2
    return math.max(1, math.floor(y / cellH) + 1)
end

local function inRect(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function layoutUI()
    ui.boom.x = WIDTH - 130
    ui.boom.y = 24
    ui.arm.x = WIDTH * 0.5 - 60
    ui.arm.y = HEIGHT * 0.42
end

local function onDetonate(charge)
    local hits = Building.applyBlast(state.building, charge)
    state.boomPulse = math.min(1, 0.35 + charge.massKg * 0.4)
    state.hapticPending = true
    toast(string.format("BOOM %.2f kg @ floor %d → %d parts", charge.massKg, charge.floor, hits), 2)
    -- Sound: volume scales with yield
    if sound then
        sound(SOUND_EXPLODE, math.min(1, 0.4 + charge.massKg))
    end
end

function update(dt)
    CameraOrbit.update(state.cam, dt)
    Charges.update(state.charges, dt, onDetonate)
    if state.msgT > 0 then state.msgT = state.msgT - dt end
    if state.boomPulse > 0 then state.boomPulse = math.max(0, state.boomPulse - dt * 1.2) end

    -- Haptic buzz when charge fires (iPad)
    if state.hapticPending then
        state.hapticPending = false
        if haptic and haptic.impact then
            haptic.impact(HapticStyle and HapticStyle.Heavy or 2)
        elseif vibrate then
            vibrate()
        end
    end
end

function draw()
    update(DeltaTime)
    scene:draw()
    layoutUI()

    -- HUD overlay (2D)
    ortho()
    viewMatrix(matrix())
    camera(0,0,1, 0,0,0, 0,1,0)

    Charges.drawHUD(state.charges)

    -- BOOM button
    local ch = state.charges
    fill(200, 50, 40)
    if ch.mode == "idle" or ch.mode == "done" then
        rect(ui.boom.x, ui.boom.y, ui.boom.w, ui.boom.h)
        fill(255)
        fontSize(18)
        text("BOOM", ui.boom.x + ui.boom.w * 0.5, ui.boom.y + ui.boom.h * 0.5)
    end

    -- Flashing red ARM button during boom_preview
    if ch.mode == "boom_preview" then
        local flash = (math.floor(ch.armFlash) % 2 == 0)
        if flash then
            fill(255, 20, 20)
        else
            fill(120, 10, 10)
        end
        ellipse(ui.arm.x + ui.arm.w * 0.5, ui.arm.y + ui.arm.h * 0.5, ui.arm.w)
        fill(255)
        fontSize(20)
        text("ARM", ui.arm.x + ui.arm.w * 0.5, ui.arm.y + ui.arm.h * 0.5)
        fill(255, 200, 200)
        fontSize(13)
        text("Camera pulled outside — tap ARM to fire", WIDTH * 0.5, ui.arm.y - 24)
    end

    -- Delay / pattern strip
    fill(20, 24, 32, 180)
    rect(12, 12, 280, 70)
    fill(230, 235, 245)
    fontSize(13)
    textAlign(LEFT)
    text(string.format("[ ] delay  %.1f s", ch.nextDelay), 24, 62)
    text(string.format("P pattern %s (%.1fs)", ch.patternOn and "ON" or "off", ch.patternStep), 24, 42)
    text("Double-tap place · 1/2/3 blueprints · R reset", 24, 22)
    textAlign(CENTER)

    if state.msgT > 0 then
        fill(255, 230, 120)
        fontSize(16)
        text(state.message, WIDTH * 0.5, HEIGHT - 54)
    end

    -- Screen shake flash on boom
    if state.boomPulse > 0 then
        fill(255, 180, 80, 40 * state.boomPulse)
        rect(0, 0, WIDTH, HEIGHT)
    end
end

function touched(touch)
    if touch.state == BEGAN then
        layoutUI()
        -- ARM
        if state.charges.mode == "boom_preview" and inRect(touch.x, touch.y, ui.arm) then
            Charges.arm(state.charges)
            toast("ARMED — sequenced detonation", 2)
            return
        end
        -- BOOM
        if inRect(touch.x, touch.y, ui.boom) then
            if Charges.beginBoom(state.charges) then
                CameraOrbit.pullExterior(state.cam, state.building.bounds)
                toast("Outside view — tap flashing ARM", 3)
            else
                toast("Place TNT first (double-tap)", 2)
            end
            return
        end

        local now = ElapsedTime
        local isDouble = (now - state.lastTap) < 0.35
            and (touch.x - state.lastTapPos.x)^2 + (touch.y - state.lastTapPos.y)^2 < 40 * 40
        state.lastTap = now
        state.lastTapPos = vec2(touch.x, touch.y)

        if isDouble and (state.charges.mode == "idle" or state.charges.mode == "done") then
            if state.charges.mode == "done" then
                -- allow placing more after a run
                state.charges.mode = "idle"
                for _, c in ipairs(state.charges.list) do c.fired = false end
            end
            local wp = hitWorldFromTouch(touch.x, touch.y)
            local fl = floorAtY(wp.y)
            local c = Charges.place(state.charges, wp, fl, 0.5)
            toast(string.format("Charge #%d floor %d delay %.1fs", c.id, c.floor, c.delay), 1.5)
            return
        end

        CameraOrbit.touchBegan(state.cam, touch)
    elseif touch.state == MOVING then
        CameraOrbit.touchMoved(state.cam, touch)
    elseif touch.state == ENDED or touch.state == CANCELLED then
        CameraOrbit.touchEnded(state.cam, touch)
    end
end

function keyboard(key)
    if key == "[" then Charges.nudgeDelay(state.charges, -1); toast(string.format("Delay %.1fs", state.charges.nextDelay), 1)
    elseif key == "]" then Charges.nudgeDelay(state.charges, 1); toast(string.format("Delay %.1fs", state.charges.nextDelay), 1)
    elseif key == "p" or key == "P" then
        Charges.togglePattern(state.charges)
        toast(state.charges.patternOn and "Pattern ON — 0.1s apart" or "Pattern off — manual delay", 2)
    elseif key == "f" or key == "F" then
        Charges.assignFloorCascade(state.charges, state.selectedFloor)
        toast("Floor cascade from floor " .. state.selectedFloor, 2)
    elseif key == "b" or key == "B" then
        if Charges.beginBoom(state.charges) then
            CameraOrbit.pullExterior(state.cam, state.building.bounds)
        end
    elseif key == "r" or key == "R" then
        loadBlueprint(state.bpIndex)
    elseif key == "1" then loadBlueprint(1)
    elseif key == "2" then loadBlueprint(2)
    elseif key == "3" then loadBlueprint(3)
    elseif key == "=" or key == "+" then CameraOrbit.zoom(state.cam, -1)
    elseif key == "-" then CameraOrbit.zoom(state.cam, 1)
    end
end
