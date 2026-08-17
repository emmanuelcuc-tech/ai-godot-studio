-- Chrome Cannon Glass
-- Codea (classic API) for iPad: aim a cannon, Tab/Fire shoots a chrome ball
-- through 5 spaced glass panes with real kinetic energy and slow-motion shatter.
-- Main-screen glass overlay shatters when mic input or speaker output is too loud;
-- tweaking InputGain / OutputVolume resets the screen glass each time.
--
-- Controls:
--   Drag finger near cannon (or vertical drag) to aim
--   Tap FIRE / Space / Tab to shoot
--   Tap RESET (or R) after the shot to reload panes + ball
--   Tap MIXER tab for FL-style Master + all channel volumes
--   Tweaking any mixer fader resets the screen glass
--   Yell into mic or crank Master/OUT + fire to break the screen glass

DISPLAYED_NAME = "Chrome Cannon Glass"

-- Tunables
BALL_RADIUS = 16
BALL_DENSITY = 2.2
MUZZLE_SPEED = 980          -- px/s — feeds KE = 1/2 m v^2
PANE_COUNT = 5
PANE_SPACING = 115
PANE_W, PANE_H = 10, 220
SHATTER_KE = 180000         -- joules-ish (px units); ball must carry enough KE
SHARD_COUNT = 14
GRAVITY_Y = -980
SLOW_MO_BLEND = 0.12        -- how quickly time scale eases
SCREEN_COLS, SCREEN_ROWS = 8, 5
SCREEN_BREAK_COOLDOWN = 0.5 -- seconds after a tweak before loudness can break again

-- Layout
cannonPos = vec2(0, 0)
aimAngle = 0                -- radians, 0 = right
aimMin, aimMax = math.rad(-28), math.rad(42)
corridorY = 0
groundY = 0

-- State
state = "ready"             -- ready | flying | done
ball = nil
panes = {}                  -- { body, x, y, broken }
shards = {}
statics = {}
slowMo = 1
targetSlowMo = 1
prevSlowMo = 1
brokenCount = 0
lastKe = 0
message = "Aim, then FIRE — ball flies in slow-mo through the glass"
messageTimer = 3.5
aiming = false
fireFlash = 0

-- Main-screen glass (covers the display until audio is too loud)
screenBroken = false
screenShards = {}
inputLevel, outputLevel = 0, 0
outputPeak = 0
loudestSource = "input"
InputGain = 1
OutputVolume = 0.7
LoudnessBreak = 0.62
prevInputGain, prevOutputVolume = 1, 0.7
screenBreakCooldown = 0
micOn = false
micHold = 0
micLit = false
micLampMode = "off"
micHeight = 0
micPulse = 0
MIC_FLOOR = 0.03

-- FL-style mixer (Master + strips). Filled in setup() after Mixer.lua loads.
uiPage = "play" -- play | mixer
mixVols = nil
prevMixVols = nil
mixerDrag = nil
mixerLayoutCache = nil
knobDrag = nil
knobLastAng = 0

function setup()
    supportedOrientations(LANDSCAPE_ANY)
    displayMode(FULLSCREEN_NO_BUTTONS)

    parameter.number("MuzzleSpeed", 400, 1600, MUZZLE_SPEED)
    parameter.number("LoudnessBreak", 0.15, 1.2, LoudnessBreak)
    parameter.action("Fire Cannon", function()
        fireCannon()
    end)
    parameter.action("Reset Scene", function()
        resetScene()
    end)
    parameter.action("Reset Screen Glass", function()
        resetScreenGlass()
    end)
    parameter.action("Mixer Page", function()
        uiPage = "mixer"
    end)
    parameter.action("Set All 80%", function()
        mixVols = Mixer.setAll(mixVols or Mixer.defaults(), Mixer.UNITY)
        syncGainsFromMixer()
        resetScreenGlass()
        saveAllSettings()
        message = "All volumes (incl. Master) set to 80%"
        messageTimer = 1.8
    end)
    parameter.action("Save Settings", function()
        saveAllSettings()
        message = "Settings saved"
        messageTimer = 1.4
    end)
    parameter.action("Load Settings", function()
        loadAllSettings()
        syncGainsFromMixer()
        message = "Settings loaded"
        messageTimer = 1.4
    end)

    mixVols = Mixer.defaults()
    loadAllSettings()
    prevMixVols = Mixer.copy(mixVols)
    syncGainsFromMixer()

    physics.continuous = true
    physics.iterations(14, 10)
    physics.pause()

    startMic()
    layoutScene()
    resetScene()
end

function startMic()
    micOn = false
    if mic and mic.start then
        local ok = pcall(function()
            mic.start()
        end)
        micOn = ok
    end
end

function cleanup()
    saveAllSettings()
    if mic and mic.stop then
        pcall(function()
            mic.stop()
        end)
    end
end

function saveAllSettings()
    mixVols = mixVols or Mixer.defaults()
    pcall(function()
        for _, k in ipairs(Mixer.STRIPS) do
            saveProjectData("vol_" .. k, mixVols[k])
        end
        saveProjectData("muzzle", MUZZLE_SPEED)
        saveProjectData("loudness", LoudnessBreak or 0.62)
        saveProjectData("uiPage", uiPage or "play")
    end)
end

function loadAllSettings()
    mixVols = mixVols or Mixer.defaults()
    pcall(function()
        for _, k in ipairs(Mixer.STRIPS) do
            local v = readProjectData("vol_" .. k)
            if v ~= nil then
                mixVols[k] = Mixer.clamp(v)
            end
        end
        local mz = readProjectData("muzzle")
        if mz then MUZZLE_SPEED = mz end
        local ld = readProjectData("loudness")
        if ld then LoudnessBreak = ld end
        local page = readProjectData("uiPage")
        if page == "mixer" or page == "play" then
            uiPage = page
        end
    end)
end

function readMicAmp()
    if mic and mic.amplitude ~= nil then
        return tonumber(mic.amplitude) or 0
    end
    return 0
end

function syncGainsFromMixer()
    mixVols = mixVols or Mixer.defaults()
    InputGain = Mixer.toGain("input", mixVols)
    OutputVolume = Mixer.toGain("output", mixVols)
end

function playOutputSound(kind, seed, bus)
    bus = bus or "output"
    mixVols = mixVols or Mixer.defaults()
    local vol = Mixer.toGain(bus, mixVols)
    local src
    if seed then
        src = sound(kind, seed)
    else
        src = sound(kind)
    end
    if src then
        pcall(function()
            src.volume = math.min(1, math.max(0, vol))
        end)
    end
    outputPeak = math.max(outputPeak, math.min(1, Mixer.effective(bus, mixVols)))
end

function layoutScene()
    groundY = HEIGHT * 0.18
    corridorY = groundY + PANE_H * 0.5 + 8
    cannonPos = vec2(WIDTH * 0.11, groundY + 36)
    aimAngle = math.rad(8)
end

function resetScene()
    clearDynamics()
    clearStatics()
    brokenCount = 0
    lastKe = 0
    slowMo = 1
    targetSlowMo = 1
    prevSlowMo = 1
    state = "ready"
    fireFlash = 0
    message = "Aim, then FIRE — chrome ball · kinetic shatter · slow-mo"
    messageTimer = 2.8

    -- Ground
    local gw = WIDTH + 200
    local ground = physics.body(POLYGON,
        vec2(-gw * 0.5, -18), vec2(gw * 0.5, -18),
        vec2(gw * 0.5, 18), vec2(-gw * 0.5, 18))
    ground.x = WIDTH * 0.5
    ground.y = groundY - 18
    ground.type = STATIC
    ground.friction = 0.55
    ground.restitution = 0.12
    ground.info = "ground"
    table.insert(statics, ground)

    -- Backstop wall
    local wall = physics.body(POLYGON,
        vec2(-12, -HEIGHT * 0.4), vec2(12, -HEIGHT * 0.4),
        vec2(12, HEIGHT * 0.4), vec2(-12, HEIGHT * 0.4))
    wall.x = WIDTH - 28
    wall.y = HEIGHT * 0.45
    wall.type = STATIC
    wall.friction = 0.3
    wall.restitution = 0.35
    wall.info = "wall"
    table.insert(statics, wall)

    -- Five glass panes
    panes = {}
    local firstX = cannonPos.x + 150
    local xs = Glass.panePositions(PANE_COUNT, firstX, PANE_SPACING)
    for i, x in ipairs(xs) do
        local body = physics.body(POLYGON,
            vec2(-PANE_W * 0.5, -PANE_H * 0.5),
            vec2(PANE_W * 0.5, -PANE_H * 0.5),
            vec2(PANE_W * 0.5, PANE_H * 0.5),
            vec2(-PANE_W * 0.5, PANE_H * 0.5))
        body.x = x
        body.y = corridorY
        body.type = STATIC
        body.friction = 0.05
        body.restitution = 0.05
        body.info = "glass"
        body.paneIndex = i
        table.insert(panes, {
            body = body,
            x = x,
            y = corridorY,
            broken = false,
            index = i,
        })
    end

    spawnBallReady()
    resetScreenGlass()
    physics.gravity(0, GRAVITY_Y)
    physics.resume()
end

function spawnBallReady()
    if ball then
        ball:destroy()
        ball = nil
    end
    local mx, my = Glass.cannonMuzzle(cannonPos.x, cannonPos.y, aimAngle, 78)
    ball = physics.body(CIRCLE, BALL_RADIUS)
    ball.x = mx
    ball.y = my
    ball.type = STATIC
    ball.density = BALL_DENSITY
    ball.friction = 0.08
    ball.restitution = 0.55
    ball.linearDamping = 0.02
    ball.angularDamping = 0.15
    ball.sleepingAllowed = false
    ball.interpolate = true
    ball.info = "ball"
    ball.bullet = true
end

function clearDynamics()
    if ball then
        ball:destroy()
        ball = nil
    end
    for _, s in ipairs(shards) do
        if s.body then s.body:destroy() end
    end
    shards = {}
    clearScreenShards()
end

function clearStatics()
    for _, p in ipairs(panes) do
        if p.body then p.body:destroy() end
    end
    panes = {}
    for _, b in ipairs(statics) do
        if b then b:destroy() end
    end
    statics = {}
end

function fireCannon()
    if state ~= "ready" or not ball then return end
    if MuzzleSpeed then MUZZLE_SPEED = MuzzleSpeed end

    local mx, my = Glass.cannonMuzzle(cannonPos.x, cannonPos.y, aimAngle, 78)
    ball.type = DYNAMIC
    ball.x = mx
    ball.y = my
    ball.angularVelocity = 0

    local vx, vy = Glass.muzzleVelocity(aimAngle, MUZZLE_SPEED)
    ball.linearVelocity = vec2(vx, vy)

    local mass = Glass.circleMass(BALL_DENSITY, BALL_RADIUS)
    lastKe = Glass.kineticEnergy(mass, MUZZLE_SPEED)

    state = "flying"
    fireFlash = 1
    targetSlowMo = 0.22
    message = string.format("Fired · KE %.0f  ·  slow-mo through glass", lastKe)
    messageTimer = 2.5
    playOutputSound(SOUND_EXPLODE, 29480, "fire")
end

function draw()
    if uiPage == "mixer" then
        drawMixerPage()
        updateSlowMo()
        updateAudioGlass()
        if messageTimer > 0 then
            messageTimer = messageTimer - DeltaTime
        end
        return
    end

    -- Black leather studio
    drawLeather()
    drawGround()
    drawCannon()
    drawPanes()
    drawShards()
    drawScreenShards()
    if ball then
        drawMetallicBall(ball.x, ball.y, BALL_RADIUS, ball.angle or 0)
    end
    drawHUD()
    drawButtons()
    drawPageTabs()
    drawScreenGlassOverlay()
    drawMeters()
    drawMicSpeakerLamps()
    drawVolumeKnobs()

    updateSlowMo()
    updateBallKe()
    updateFlight()
    updateAudioGlass()

    if fireFlash > 0 then
        fireFlash = math.max(0, fireFlash - DeltaTime * 2.2)
    end
    if messageTimer > 0 then
        messageTimer = messageTimer - DeltaTime
    end
end

function updateSlowMo()
    if state == "flying" and ball then
        local firstX = panes[1] and panes[1].x or cannonPos.x
        local lastX = panes[#panes] and panes[#panes].x or (cannonPos.x + 500)
        targetSlowMo = Glass.slowMoFactor(
            ball.x, firstX, lastX, true, brokenCount, PANE_COUNT)
    elseif state == "ready" then
        targetSlowMo = 1
    else
        targetSlowMo = math.min(1, targetSlowMo + DeltaTime * 0.35)
    end

    slowMo = slowMo + (targetSlowMo - slowMo) * math.min(1, SLOW_MO_BLEND + DeltaTime * 2)

    -- Scale live velocities when time factor changes (classic Codea has no world timeScale)
    if math.abs(slowMo - prevSlowMo) > 0.001 then
        local ratio = slowMo / math.max(0.001, prevSlowMo)
        scaleAllDynamicVelocities(ratio)
        prevSlowMo = slowMo
    end
    physics.gravity(0, GRAVITY_Y * slowMo)
end

function scaleAllDynamicVelocities(ratio)
    if ball and ball.type == DYNAMIC and ball.linearVelocity then
        ball.linearVelocity = vec2(
            ball.linearVelocity.x * ratio,
            ball.linearVelocity.y * ratio)
        ball.angularVelocity = (ball.angularVelocity or 0) * ratio
    end
    for _, s in ipairs(shards) do
        local b = s.body
        if b and b.linearVelocity then
            b.linearVelocity = vec2(
                b.linearVelocity.x * ratio,
                b.linearVelocity.y * ratio)
            b.angularVelocity = (b.angularVelocity or 0) * ratio
        end
    end
    for _, s in ipairs(screenShards) do
        local b = s.body
        if b and b.linearVelocity then
            b.linearVelocity = vec2(
                b.linearVelocity.x * ratio,
                b.linearVelocity.y * ratio)
            b.angularVelocity = (b.angularVelocity or 0) * ratio
        end
    end
end

function updateBallKe()
    if not ball or ball.type ~= DYNAMIC or not ball.linearVelocity then return end
    local mass = Glass.circleMass(BALL_DENSITY, BALL_RADIUS)
    local sp = Glass.speedFromVelocity(ball.linearVelocity.x, ball.linearVelocity.y)
    -- Report KE in “full-speed” units (undo slow-mo so HUD stays meaningful)
    local fullSpeed = sp / math.max(0.05, slowMo)
    lastKe = Glass.kineticEnergy(mass, fullSpeed)
end

function updateFlight()
    if state ~= "flying" or not ball then return end
    -- Done when ball rests or leaves playable area
    if ball.x > WIDTH + 40 or ball.y < -80 then
        state = "done"
        message = "Shot complete — tap RESET for another run"
        messageTimer = 99
        targetSlowMo = 1
    elseif ball.linearVelocity then
        local sp = Glass.speedFromVelocity(ball.linearVelocity.x, ball.linearVelocity.y)
        if brokenCount >= PANE_COUNT and sp < 40 * slowMo and ball.y <= groundY + BALL_RADIUS + 4 then
            state = "done"
            message = "All five panes shattered — RESET to fire again"
            messageTimer = 99
            targetSlowMo = 1
        end
    end
end

function collide(contact)
    if contact.state ~= BEGAN then return end
    local a, b = contact.bodyA, contact.bodyB
    if not a or not b then return end

    local ballBody, glassBody
    if a.info == "ball" and b.info == "glass" then
        ballBody, glassBody = a, b
    elseif b.info == "ball" and a.info == "glass" then
        ballBody, glassBody = b, a
    else
        return
    end

    local pane = paneFromBody(glassBody)
    if not pane or pane.broken then return end

    local vx = ballBody.linearVelocity and ballBody.linearVelocity.x or 0
    local vy = ballBody.linearVelocity and ballBody.linearVelocity.y or 0
    local fullVx, fullVy = vx / math.max(0.05, slowMo), vy / math.max(0.05, slowMo)
    local mass = Glass.circleMass(BALL_DENSITY, BALL_RADIUS)
    local speed = Glass.speedFromVelocity(fullVx, fullVy)
    local ke = Glass.kineticEnergy(mass, speed)

    if not Glass.shouldShatter(ke, SHATTER_KE, 1) then
    playOutputSound(SOUND_HIT, 20112, "hit")
        return
    end

    shatterPane(pane, fullVx, fullVy, ke)
end

function paneFromBody(body)
    for _, p in ipairs(panes) do
        if p.body == body then return p end
    end
    return nil
end

function shatterPane(pane, impactVx, impactVy, ke)
    pane.broken = true
    brokenCount = brokenCount + 1
    if pane.body then
        pane.body:destroy()
        pane.body = nil
    end

    local shardMass = 0.08
    local leftover = math.max(ke - SHATTER_KE * 0.55, ke * 0.25)
    local vel = Glass.shardVelocities(SHARD_COUNT, impactVx, impactVy, leftover, shardMass)

    for i, v in ipairs(vel) do
        local w = 6 + (i % 4) * 2
        local h = 10 + (i % 5) * 3
        local body = physics.body(POLYGON,
            vec2(-w * 0.5, -h * 0.5), vec2(w * 0.5, -h * 0.5),
            vec2(w * 0.5, h * 0.5), vec2(-w * 0.5, h * 0.5))
        local ox = ((i % 5) - 2) * 6
        local oy = ((i % 7) - 3) * 8
        body.x = pane.x + ox
        body.y = pane.y + oy
        body.type = DYNAMIC
        body.density = 0.35
        body.friction = 0.2
        body.restitution = 0.15
        body.sleepingAllowed = true
        body.info = "shard"
        -- Apply in current slow-mo frame
        body.linearVelocity = vec2(v.vx * slowMo, v.vy * slowMo)
        body.angularVelocity = v.spin * slowMo
        table.insert(shards, {
            body = body,
            w = w,
            h = h,
            life = 8,
        })
    end

    -- Bleed KE from the ball (real energy spent breaking glass)
    if ball and ball.linearVelocity then
        local mass = Glass.circleMass(BALL_DENSITY, BALL_RADIUS)
        local sp = Glass.speedFromVelocity(
            ball.linearVelocity.x / math.max(0.05, slowMo),
            ball.linearVelocity.y / math.max(0.05, slowMo))
        local newSp = Glass.speedAfterEnergyLoss(mass, sp, SHATTER_KE * 0.45)
        local ang = Glass.atan2(impactVy, impactVx)
        ball.linearVelocity = vec2(
            math.cos(ang) * newSp * slowMo,
            math.sin(ang) * newSp * slowMo)
    end

    targetSlowMo = math.min(targetSlowMo, 0.16)
    message = string.format("Pane %d shattered · KE left %.0f · %d/%d",
        pane.index, lastKe, brokenCount, PANE_COUNT)
    messageTimer = 2.2
    playOutputSound(SOUND_HIT, 31882, "glass")
end

-- Input ----------------------------------------------------------------

function touched(touch)
    if touch.state == BEGAN then
        if hitButton(touch, playTabBtn()) then
            uiPage = "play"
            mixerDrag = nil
            knobDrag = nil
            return
        end
        if hitButton(touch, mixerTabBtn()) then
            uiPage = "mixer"
            mixerDrag = nil
            knobDrag = nil
            aiming = false
            return
        end
        local kid = volumeKnobAt(touch.x, touch.y)
        if kid then
            knobDrag = kid
            aiming = false
            mixerDrag = nil
            local k = volumeKnobLayout()[kid]
            knobLastAng = Glass.atan2(touch.y - k.y, touch.x - k.x)
            return
        end
        if uiPage == "mixer" then
            if hitButton(touch, setAllBtn()) then
                mixVols = Mixer.setAll(mixVols or Mixer.defaults(), Mixer.UNITY)
                syncGainsFromMixer()
                resetScreenGlass()
                message = "All volumes (incl. Master) set to 80%"
                messageTimer = 1.8
                return
            end
            local id = mixerStripAt(touch.x, touch.y)
            if id then
                mixerDrag = id
                applyMixerTouch(touch)
            end
            return
        end
        if hitButton(touch, fireBtn()) then
            fireCannon()
            return
        end
        if hitButton(touch, resetBtn()) then
            resetScene()
            return
        end
        -- Aim if touching left half / near cannon
        if touch.x < WIDTH * 0.45 or dist(touch.x, touch.y, cannonPos.x, cannonPos.y) < 160 then
            aiming = true
            aimFromTouch(touch)
        end
    elseif touch.state == MOVING then
        if knobDrag then
            applyKnobTwist(touch)
        elseif uiPage == "mixer" and mixerDrag then
            applyMixerTouch(touch)
        elseif aiming then
            aimFromTouch(touch)
        end
    elseif touch.state == ENDED or touch.state == CANCELLED then
        aiming = false
        mixerDrag = nil
        knobDrag = nil
    end
end

function aimFromTouch(touch)
    local dx = touch.x - cannonPos.x
    local dy = touch.y - cannonPos.y
    if math.abs(dx) + math.abs(dy) < 8 then return end
    local a = Glass.atan2(dy, dx)
    aimAngle = clamp(a, aimMin, aimMax)
    if state == "ready" then
        local mx, my = Glass.cannonMuzzle(cannonPos.x, cannonPos.y, aimAngle, 78)
        if ball then
            ball.x = mx
            ball.y = my
        end
    end
end

function keyboard(key)
    if key == "\t" or key == "tab" then
        if uiPage == "mixer" then
            uiPage = "play"
        else
            fireCannon()
        end
    elseif key == "m" or key == "M" then
        uiPage = (uiPage == "mixer") and "play" or "mixer"
    elseif key == " " then
        if uiPage == "play" then fireCannon() end
    elseif key == "r" or key == "R" then
        resetScene()
    elseif key == "w" or key == "W" then
        nudgeAim(math.rad(2))
    elseif key == "s" or key == "S" then
        nudgeAim(math.rad(-2))
    end
end

function nudgeAim(delta)
    aimAngle = clamp(aimAngle + delta, aimMin, aimMax)
    if state == "ready" and ball then
        local mx, my = Glass.cannonMuzzle(cannonPos.x, cannonPos.y, aimAngle, 78)
        ball.x, ball.y = mx, my
    end
end

function fireBtn()
    return { x = WIDTH - 150, y = 28, w = 120, h = 52 }
end

function resetBtn()
    return { x = WIDTH - 290, y = 28, w = 120, h = 52 }
end

function playTabBtn()
    return { x = 22, y = HEIGHT - 92, w = 108, h = 34 }
end

function mixerTabBtn()
    return { x = 138, y = HEIGHT - 92, w = 108, h = 34 }
end

function setAllBtn()
    return { x = WIDTH - 188, y = HEIGHT - 92, w = 166, h = 34 }
end

function hitButton(touch, b)
    return touch.x >= b.x and touch.x <= b.x + b.w
        and touch.y >= b.y and touch.y <= b.y + b.h
end

-- Drawing --------------------------------------------------------------

function neonFill(alpha, value)
    local t = ElapsedTime or 0
    local r, g, b = Mixer.neonRGB(t, value or 1)
    fill(r, g, b, alpha or 255)
    return r, g, b
end

function neonText(str, x, y, size)
    size = size or 22
    font("HelveticaNeue-Bold")
    fontSize(size)
    local t = ElapsedTime or 0
    local r, g, b = Mixer.neonRGB(t, 1)
    -- Tube glow (light-bulb halo)
    fill(r, g, b, 28)
    text(str, x + 2, y)
    text(str, x - 2, y)
    text(str, x, y + 2)
    text(str, x, y - 2)
    fill(r, g, b, 70)
    text(str, x + 1, y)
    text(str, x - 1, y)
    -- Phosphor
    fill(r, g, b, 220)
    text(str, x, y)
    -- Hot filament
    fill(math.min(255, r + 90), math.min(255, g + 90), math.min(255, b + 90), 255)
    text(str, x, y)
end

function drawLeather()
    background(5, 3, 4)
    noStroke()
    -- Hide patches
    for i = 0, 22 do
        local gx = (i * 137 + 19) % (WIDTH + 80) - 40
        local gy = (i * 89 + 7) % (HEIGHT + 60) - 30
        fill(12 + (i % 5), 8, 9, 70)
        ellipse(gx, gy, 220 - (i % 6) * 18, 110)
    end
    -- Pebbled grain
    for i = 0, 90 do
        local x = (i * 73 + 11) % WIDTH
        local y = (i * 47 + 23) % HEIGHT
        fill(18, 12, 12, 40)
        ellipse(x, y, 16 + (i % 6) * 3, 11 + (i % 4) * 2)
        fill(3, 1, 2, 50)
        ellipse(x + 3, y - 2, 7, 5)
    end
    -- Wet sheen
    fill(42, 30, 32, 18)
    ellipse(WIDTH * 0.38, HEIGHT * 0.72, WIDTH * 0.85, HEIGHT * 0.28)
    fill(28, 20, 22, 14)
    ellipse(WIDTH * 0.7, HEIGHT * 0.25, WIDTH * 0.5, HEIGHT * 0.2)
    -- Stitching
    stroke(32, 22, 20, 90)
    strokeWidth(1.2)
    line(14, 14, WIDTH - 14, 14)
    line(14, HEIGHT - 14, WIDTH - 14, HEIGHT - 14)
    line(14, 14, 14, HEIGHT - 14)
    line(WIDTH - 14, 14, WIDTH - 14, HEIGHT - 14)
    noStroke()
end

function drawBackdrop()
end

function drawGround()
    noStroke()
    fill(8, 5, 6)
    rect(0, 0, WIDTH, groundY)
    for i = 0, 24 do
        fill(16, 10, 10, 40)
        ellipse((i * 53) % WIDTH, groundY * 0.45, 50, 22)
    end
    fill(22, 14, 14)
    rect(0, groundY - 5, WIDTH, 6)
    -- Leather stitch on floor edge
    stroke(36, 24, 22, 100)
    strokeWidth(1)
    for x = 20, WIDTH - 20, 18 do
        line(x, groundY - 2, x + 8, groundY - 2)
    end
    noStroke()
end

function drawCannon()
    pushMatrix()
    translate(cannonPos.x, cannonPos.y)
    -- Carriage
    fill(45, 40, 36)
    ellipse(-8, -18, 42, 28)
    fill(70, 62, 55)
    rect(-28, -22, 40, 18)
    -- Wheels
    fill(28, 28, 32)
    ellipse(-18, -28, 26)
    ellipse(8, -28, 26)
    fill(90, 90, 100)
    ellipse(-18, -28, 10)
    ellipse(8, -28, 10)

    rotate(math.deg(aimAngle))
    -- Barrel
    fill(55, 58, 66)
    rect(0, -14, 82, 28)
    fill(80, 86, 98)
    rect(0, -10, 82, 8)
    fill(25, 28, 34)
    ellipse(82, 0, 22, 28)
    -- Muzzle flash
    if fireFlash > 0 then
        fill(255, 200, 80, 220 * fireFlash)
        ellipse(96, 0, 40 + 30 * fireFlash, 28 + 20 * fireFlash)
        fill(255, 255, 220, 200 * fireFlash)
        ellipse(100, 0, 18 + 10 * fireFlash)
    end
    popMatrix()

    -- Aim guide
    if state == "ready" then
        local nr, ng, nb = Mixer.neonRGB(ElapsedTime or 0, 1)
        stroke(nr, ng, nb, 90)
        strokeWidth(2)
        local mx, my = Glass.cannonMuzzle(cannonPos.x, cannonPos.y, aimAngle, 78)
        local ex = mx + math.cos(aimAngle) * 160
        local ey = my + math.sin(aimAngle) * 160
        line(mx, my, ex, ey)
        noStroke()
    end
end

function drawPanes()
    for _, p in ipairs(panes) do
        if not p.broken then
            -- Frame
            fill(70, 78, 90)
            rect(p.x - PANE_W * 0.5 - 4, p.y - PANE_H * 0.5 - 8, PANE_W + 8, 10)
            rect(p.x - PANE_W * 0.5 - 4, p.y + PANE_H * 0.5 - 2, PANE_W + 8, 10)
            -- Glass
            fill(140, 190, 230, 55)
            rect(p.x - PANE_W * 0.5, p.y - PANE_H * 0.5, PANE_W, PANE_H)
            stroke(200, 230, 255, 100)
            strokeWidth(1)
            line(p.x - 2, p.y - PANE_H * 0.4, p.x + 2, p.y + PANE_H * 0.35)
            noStroke()
            -- Pane number
            fontSize(14)
            textAlign(CENTER)
            textMode(CENTER)
            neonText(tostring(p.index), p.x, p.y + PANE_H * 0.5 + 18, 14)
        else
            -- Empty frame posts
            fill(50, 54, 62, 120)
            rect(p.x - 3, p.y - PANE_H * 0.5, 6, PANE_H)
        end
    end
end

function drawShards()
    for i = #shards, 1, -1 do
        local s = shards[i]
        s.life = s.life - DeltaTime
        if s.life <= 0 or not s.body then
            if s.body then s.body:destroy() end
            table.remove(shards, i)
        else
            pushMatrix()
            translate(s.body.x, s.body.y)
            rotate(math.deg(s.body.angle or 0))
            fill(170, 210, 240, 160)
            rect(-s.w * 0.5, -s.h * 0.5, s.w, s.h)
            stroke(230, 250, 255, 180)
            strokeWidth(1)
            line(-s.w * 0.4, -s.h * 0.3, s.w * 0.3, s.h * 0.4)
            noStroke()
            popMatrix()
        end
    end
end

function drawMetallicBall(x, y, r, angle)
    fill(20, 22, 28, 90)
    ellipse(x + 3, y - 3, r * 2.15)
    for i = 8, 1, -1 do
        local t = i / 8
        local shade = 70 + t * 140
        fill(shade, shade + 4, shade + 12)
        ellipse(x - r * 0.08 * (1 - t), y + r * 0.08 * (1 - t), r * 2 * t)
    end
    stroke(180, 190, 205, 120)
    strokeWidth(2)
    noFill()
    ellipse(x, y, r * 1.85)
    noStroke()
    fill(255, 255, 255, 220)
    ellipse(x - r * 0.35, y + r * 0.38, r * 0.55)
    fill(255, 255, 255, 140)
    ellipse(x + r * 0.25, y - r * 0.15, r * 0.22)
    pushMatrix()
    translate(x, y)
    rotate(math.deg(angle))
    stroke(40, 45, 55, 100)
    strokeWidth(1)
    line(-r * 0.5, 0, r * 0.5, 0)
    noStroke()
    popMatrix()
end

function drawHUD()
    textAlign(LEFT)
    textMode(CORNER)
    neonText("Chrome Cannon Glass", 22, HEIGHT - 34, 24)
    neonText(string.format(
        "Aim · FIRE/Tab · panes %d/%d · KE %.0f · IN %.2f OUT %.2f",
        brokenCount, PANE_COUNT, lastKe, inputLevel, outputLevel), 22, HEIGHT - 58, 14)

    if messageTimer > 0 and message ~= "" then
        textAlign(CENTER)
        textMode(CENTER)
        fill(0, 0, 0, 160)
        rectMode(CENTER)
        rect(WIDTH * 0.5, HEIGHT * 0.9, math.min(WIDTH * 0.9, 720), 48)
        rectMode(CORNER)
        neonText(message, WIDTH * 0.5, HEIGHT * 0.9, 20)
    end
end

function drawButtons()
    local f, r = fireBtn(), resetBtn()
    fill(12, 8, 8, 220)
    rect(r.x, r.y, r.w, r.h, 10)
    textAlign(CENTER)
    textMode(CENTER)
    neonText("RESET", r.x + r.w * 0.5, r.y + r.h * 0.5, 18)
    if state == "ready" then
        fill(40, 8, 12, 230)
    else
        fill(18, 8, 8, 230)
    end
    rect(f.x, f.y, f.w, f.h, 10)
    neonText("FIRE", f.x + f.w * 0.5, f.y + f.h * 0.5, 18)
end

function drawPageTabs()
    local p, m = playTabBtn(), mixerTabBtn()
    local function tab(b, label, on)
        if on then
            fill(18, 10, 12, 240)
        else
            fill(10, 7, 8, 220)
        end
        rect(b.x, b.y, b.w, b.h, 8)
        textAlign(CENTER)
        textMode(CENTER)
        neonText(label, b.x + b.w * 0.5, b.y + b.h * 0.5, 16)
    end
    tab(p, "PLAY", uiPage == "play")
    tab(m, "MIXER", uiPage == "mixer")
end

function mixerStripRects()
    local strips = Mixer.STRIPS
    local n = #strips
    local gap = 10
    local stripW = math.min(88, (WIDTH - 80) / n - gap)
    local total = n * stripW + (n - 1) * gap
    local x0 = (WIDTH - total) * 0.5
    local y0 = 70
    local h = HEIGHT - 190
    local rects = {}
    for i, id in ipairs(strips) do
        local x = x0 + (i - 1) * (stripW + gap)
        rects[id] = { x = x, y = y0, w = stripW, h = h, id = id }
    end
    return rects
end

function mixerStripAt(px, py)
    local rects = mixerStripRects()
    for id, r in pairs(rects) do
        if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
            return id
        end
    end
    return nil
end

function applyMixerTouch(touch)
    if not mixerDrag then return end
    mixVols = mixVols or Mixer.defaults()
    local rects = mixerStripRects()
    local r = rects[mixerDrag]
    if not r then return end
    local pad = 28
    mixVols[mixerDrag] = Mixer.volumeFromFaderY(touch.y, r.y + pad, r.y + r.h - pad)
    syncGainsFromMixer()
end

function volumeKnobLayout()
    -- Same IN / OUT pots on PLAY and MIXER so you can always twist them.
    return {
        input = { x = WIDTH * 0.48, y = 96, r = 46 },
        output = { x = WIDTH * 0.48 + 114, y = 96, r = 46 },
    }
end

function volumeKnobAt(px, py)
    local layout = volumeKnobLayout()
    if Mixer.hitKnob(px, py, layout.input) then return "input" end
    if Mixer.hitKnob(px, py, layout.output) then return "output" end
    return nil
end

function applyKnobTwist(touch)
    if not knobDrag then return end
    local k = volumeKnobLayout()[knobDrag]
    if not k then return end
    local ang = Glass.atan2(touch.y - k.y, touch.x - k.x)
    mixVols = mixVols or Mixer.defaults()
    mixVols[knobDrag] = Mixer.twistVolume(mixVols[knobDrag] or Mixer.UNITY, knobLastAng, ang)
    knobLastAng = ang
    syncGainsFromMixer()
end

function drawVolumeKnobs()
    mixVols = mixVols or Mixer.defaults()
    local layout = volumeKnobLayout()
    drawTwistKnob(layout.input, mixVols.input, "IN")
    drawTwistKnob(layout.output, mixVols.output, "OUT")
end

function drawTwistKnob(k, vol, label)
    if not k then return end
    fill(6, 4, 4, 220)
    ellipse(k.x, k.y, k.r * 2.45)
    fill(32, 26, 26)
    ellipse(k.x, k.y, k.r * 2.05)
    fill(16, 12, 12)
    ellipse(k.x, k.y, k.r * 1.72)
    -- Tick marks
    stroke(40, 32, 32, 140)
    strokeWidth(1)
    for i = 0, 10 do
        local a = Mixer.KNOB_MIN + (Mixer.KNOB_MAX - Mixer.KNOB_MIN) * (i / 10)
        local x1 = k.x + math.cos(a) * k.r * 0.82
        local y1 = k.y + math.sin(a) * k.r * 0.82
        local x2 = k.x + math.cos(a) * k.r * 0.95
        local y2 = k.y + math.sin(a) * k.r * 0.95
        line(x1, y1, x2, y2)
    end
    noStroke()
    local ang = Mixer.knobAngleFromVolume(vol or Mixer.UNITY)
    local nr, ng, nb = Mixer.neonRGB(ElapsedTime or 0, 1)
    local ix = k.x + math.cos(ang) * k.r * 0.7
    local iy = k.y + math.sin(ang) * k.r * 0.7
    stroke(nr, ng, nb, 230)
    strokeWidth(3)
    line(k.x, k.y, ix, iy)
    noStroke()
    fill(nr, ng, nb, 230)
    ellipse(ix, iy, 9)
    fill(8, 6, 6)
    ellipse(k.x, k.y, 10)
    textAlign(CENTER)
    textMode(CENTER)
    neonText(label, k.x, k.y + k.r + 16, 13)
    neonText(string.format("%.0f%%", ((vol or Mixer.UNITY) / Mixer.UNITY) * 100),
        k.x, k.y - k.r - 12, 12)
end

function drawMixerPage()
    drawLeather()
    fill(8, 5, 6, 200)
    rect(0, HEIGHT - 108, WIDTH, 108)
    textAlign(LEFT)
    textMode(CORNER)
    neonText("Mixer  ·  Master + all volumes", 22, HEIGHT - 34, 22)
    neonText("Drag faders  ·  SET ALL 80%  ·  tweak any strip to reset screen glass", 22, HEIGHT - 56, 13)

    drawPageTabs()
    local all = setAllBtn()
    fill(12, 8, 8, 230)
    rect(all.x, all.y, all.w, all.h, 8)
    textAlign(CENTER)
    textMode(CENTER)
    neonText("SET ALL 80%", all.x + all.w * 0.5, all.y + all.h * 0.5, 14)

    mixVols = mixVols or Mixer.defaults()
    local rects = mixerStripRects()
    for _, id in ipairs(Mixer.STRIPS) do
        drawMixerStrip(rects[id], id, mixVols[id] or Mixer.UNITY)
    end
    drawVolumeKnobs()

    if messageTimer > 0 and message ~= "" then
        textAlign(CENTER)
        textMode(CENTER)
        fill(0, 0, 0, 160)
        rectMode(CENTER)
        rect(WIDTH * 0.5, 36, math.min(WIDTH * 0.9, 720), 40)
        rectMode(CORNER)
        neonText(message, WIDTH * 0.5, 36, 18)
    end
end

function drawMixerStrip(r, id, vol)
    if not r then return end
    local master = (id == "master")
    if master then
        fill(18, 10, 10)
    else
        fill(12, 8, 9)
    end
    rect(r.x, r.y, r.w, r.h, 8)

    -- meter
    local meterW = 10
    local mx = r.x + 8
    fill(12, 12, 14)
    rect(mx, r.y + 24, meterW, r.h - 70)
    local peak = 0
    if id == "input" then peak = math.min(1, inputLevel) end
    if id == "output" or id == "master" then peak = math.min(1, outputLevel) end
    if id == "fire" or id == "hit" or id == "glass" then
        peak = math.min(1, outputPeak)
    end
    local mh = (r.h - 70) * peak
    if id == "input" then
        local pulse = 0.55 + 0.45 * math.abs(math.sin((micPulse or 0) * 3.1))
        if micLampMode == "hold" then pulse = 1 end
        if not micLit then pulse = 0.15 end
        fill(220 * pulse, 24, 28, 80 + 175 * pulse)
    elseif peak > 0.85 then
        fill(220, 70, 50)
    elseif peak > 0.6 then
        fill(220, 180, 50)
    else
        fill(70, 180, 90)
    end
    rect(mx, r.y + 24, meterW, mh)

    -- fader track
    local pad = 28
    local y0, y1 = r.y + pad, r.y + r.h - pad
    local fx = r.x + r.w * 0.62
    stroke(20, 20, 24)
    strokeWidth(6)
    line(fx, y0, fx, y1)
    noStroke()
    local fy = Mixer.faderYFromVolume(vol, y0, y1)
    if master then
        fill(232, 148, 72)
    else
        fill(200, 200, 210)
    end
    rect(fx - 14, fy - 8, 28, 16, 4)

    -- unity tick (0.8)
    local uy = Mixer.faderYFromVolume(Mixer.UNITY, y0, y1)
    fill(255, 200, 80, 160)
    rect(fx + 16, uy - 1, 8, 2)

    textAlign(CENTER)
    textMode(CENTER)
    neonText(Mixer.stripLabel(id), r.x + r.w * 0.5, r.y + 14, 13)
    neonText(string.format("%.0f%%", (vol / Mixer.UNITY) * 100), r.x + r.w * 0.5, r.y + r.h - 14, 12)
end

-- Main-screen glass (loud input/output) --------------------------------

function updateAudioGlass()
    mixVols = mixVols or Mixer.defaults()
    prevMixVols = prevMixVols or Mixer.copy(mixVols)
    syncGainsFromMixer()
    local inG = InputGain or 1
    local outV = OutputVolume or 0.7
    local thresh = LoudnessBreak or 0.62
    local dt = DeltaTime or 0.016

    local tweaked, which = Mixer.anyChanged(prevMixVols, mixVols)
    if tweaked then
        resetScreenGlass()
        screenBreakCooldown = SCREEN_BREAK_COOLDOWN
        message = string.format("%s fader tweaked — screen glass reset",
            Mixer.stripLabel(which))
        messageTimer = 1.6
        prevMixVols = Mixer.copy(mixVols)
        saveAllSettings()
    end

    outputPeak = outputPeak * math.max(0, 1 - dt * 1.35)
    if outputPeak < 0.02 then outputPeak = 0 end

    inputLevel, outputLevel = Glass.audioLevels(readMicAmp(), inG, outputPeak, outV)
    micHold, micLit, micHeight, micLampMode = Mixer.micLamp(inputLevel, micHold, dt, MIC_FLOOR)
    if micLit then
        local pulseRate = (micLampMode == "flash") and 14 or 3
        micPulse = (micPulse or 0) + dt * pulseRate
    else
        micPulse = 0
    end
    local tooLoud, _, source = Glass.isTooLoud(inputLevel, outputLevel, thresh)
    loudestSource = source

    if screenBreakCooldown > 0 then
        screenBreakCooldown = screenBreakCooldown - dt
        return
    end
    if tooLoud and not screenBroken then
        shatterScreenGlass(source, math.max(inputLevel, outputLevel))
    end
end

function resetScreenGlass()
    clearScreenShards()
    screenBroken = false
    screenBreakCooldown = SCREEN_BREAK_COOLDOWN
end

function clearScreenShards()
    for _, s in ipairs(screenShards) do
        if s.body then s.body:destroy() end
    end
    screenShards = {}
end

function shatterScreenGlass(source, loudness)
    if screenBroken then return end
    screenBroken = true
    clearScreenShards()
    local tiles = Glass.screenTileGrid(SCREEN_COLS, SCREEN_ROWS, WIDTH, HEIGHT)
    local cx, cy = WIDTH * 0.5, HEIGHT * 0.5
    -- Input cracks from the mic side (left); output from the speaker side (right)
    if source == "input" then
        cx = WIDTH * 0.18
    elseif source == "output" then
        cx = WIDTH * 0.82
    end
    for _, t in ipairs(tiles) do
        local body = physics.body(POLYGON,
            vec2(-t.w * 0.5, -t.h * 0.5), vec2(t.w * 0.5, -t.h * 0.5),
            vec2(t.w * 0.5, t.h * 0.5), vec2(-t.w * 0.5, t.h * 0.5))
        body.x = t.x
        body.y = t.y
        body.type = DYNAMIC
        body.density = 0.22
        body.friction = 0.12
        body.restitution = 0.08
        body.sleepingAllowed = true
        body.info = "screenShard"
        local vx, vy = Glass.screenBurstVelocity(t.x, t.y, cx, cy, loudness)
        body.linearVelocity = vec2(vx * (slowMo or 1), vy * (slowMo or 1))
        body.angularVelocity = ((t.col + t.row) % 2 == 0 and 6 or -6) * loudness
        table.insert(screenShards, { body = body, w = t.w, h = t.h, life = 7 })
    end
    message = string.format("SCREEN GLASS SHATTERED — loud %s (%.2f)", source, loudness)
    messageTimer = 2.8
    playOutputSound(SOUND_EXPLODE, 19221, "glass")
end

function drawScreenShards()
    for i = #screenShards, 1, -1 do
        local s = screenShards[i]
        s.life = s.life - (DeltaTime or 0)
        if s.life <= 0 or not s.body then
            if s.body then s.body:destroy() end
            table.remove(screenShards, i)
        else
            pushMatrix()
            translate(s.body.x, s.body.y)
            rotate(math.deg(s.body.angle or 0))
            fill(175, 215, 245, 150)
            rect(-s.w * 0.5, -s.h * 0.5, s.w, s.h)
            stroke(240, 250, 255, 200)
            strokeWidth(1)
            line(-s.w * 0.4, s.h * 0.3, s.w * 0.35, -s.h * 0.35)
            noStroke()
            popMatrix()
        end
    end
end

function drawScreenGlassOverlay()
    if screenBroken then return end
    -- Intact main-screen pane
    fill(170, 205, 235, 32)
    rect(0, 0, WIDTH, HEIGHT)
    -- Specular wash
    fill(255, 255, 255, 18)
    rect(WIDTH * 0.08, HEIGHT * 0.12, WIDTH * 0.18, HEIGHT * 0.72)
    -- Stress cracks as audio approaches the break point
    local thresh = math.max(0.05, LoudnessBreak or 0.62)
    local stress = math.min(1, math.max(inputLevel, outputLevel) / thresh)
    if stress > 0.45 then
        stroke(220, 235, 250, 40 + 140 * (stress - 0.45))
        strokeWidth(1.5)
        local cx, cy = WIDTH * 0.5, HEIGHT * 0.55
        for i = 1, 7 do
            local ang = i * 0.9 + stress * 0.4
            line(cx, cy, cx + math.cos(ang) * WIDTH * 0.35 * stress,
                cy + math.sin(ang) * HEIGHT * 0.4 * stress)
        end
        noStroke()
    end
    -- Rim
    stroke(210, 230, 250, 70)
    strokeWidth(3)
    noFill()
    rect(4, 4, WIDTH - 8, HEIGHT - 8)
    noStroke()
end

function drawMeters()
    local thresh = LoudnessBreak or 0.62
    fill(160, 175, 195)
    fontSize(12)
    textAlign(LEFT)
    textMode(CORNER)
    neonText(screenBroken and "screen: shattered — tweak MIXER to reset"
        or "screen: intact — too loud = break", 22, 58, 12)
end

function drawMicSpeakerLamps()
    local colH = math.min(220, HEIGHT * 0.32)
    local baseY = 88
    local micX = 48
    local outX = 118

    -- Microphone body
    fill(36, 38, 44)
    ellipse(micX, baseY + 18, 28, 36)
    fill(58, 60, 68)
    rect(micX - 6, baseY - 8, 12, 22)
    fill(22, 22, 26)
    ellipse(micX, baseY + 28, 18, 10)

    -- Red lamp: flash / pulse, or remain lit while audio holds
    local pulse = 0.5 + 0.5 * math.abs(math.sin((micPulse or 0) * 2.4))
    local glow = 0
    if micLampMode == "hold" then
        glow = 1
    elseif micLampMode == "flash" then
        glow = pulse
    elseif micLit then
        glow = 0.35 + 0.65 * pulse
    end
    if glow > 0 then
        fill(220, 20, 28, 40 + 90 * glow)
        ellipse(micX, baseY + 52, 34 + 10 * glow)
        fill(255, 30, 36, 160 + 95 * glow)
        ellipse(micX, baseY + 52, 16 + 4 * glow)
        fill(255, 180, 180, 80 + 120 * glow)
        ellipse(micX - 3, baseY + 55, 5)
    else
        fill(50, 16, 18)
        ellipse(micX, baseY + 52, 14)
    end
    textAlign(CENTER)
    textMode(CENTER)
    neonText("MIC", micX, baseY - 18, 12)

    -- Volume as HEIGHT: mic column (red) + speaker playback column (amber)
    local function volumeColumn(x, level, r, g, b, label)
        local wellH = colH
        fill(16, 16, 20, 200)
        rect(x - 11, baseY + 70, 22, wellH, 4)
        local h = Mixer.volumeHeight(level, wellH - 6)
        if h > 1 then
            fill(r, g, b, 220)
            rect(x - 8, baseY + 73, 16, h, 3)
            -- hot cap
            fill(255, math.min(255, g + 40), math.min(255, b + 40), 200)
            rect(x - 8, baseY + 73 + h - 4, 16, 5)
        end
        neonText(label, x, baseY + 70 + wellH + 12, 11)
    end
    volumeColumn(micX, micHeight, 230, 36, 40, string.format("IN %.0f", micHeight * 100))
    volumeColumn(outX, math.min(1, outputLevel), 255, 170, 50, string.format("OUT %.0f", math.min(1, outputLevel) * 100))
end

-- Helpers --------------------------------------------------------------

function dist(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
