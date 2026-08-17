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
--   Sidebar InputGain / OutputVolume — reset screen glass when tweaked
--   Yell into mic or crank output + fire to break the screen glass

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

function setup()
    supportedOrientations(LANDSCAPE_ANY)
    displayMode(FULLSCREEN_NO_BUTTONS)

    parameter.number("MuzzleSpeed", 400, 1600, MUZZLE_SPEED)
    parameter.number("InputGain", 0, 3, InputGain)
    parameter.number("OutputVolume", 0, 3, OutputVolume)
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
    if mic and mic.stop then
        pcall(function()
            mic.stop()
        end)
    end
end

function readMicAmp()
    if mic and mic.amplitude ~= nil then
        return tonumber(mic.amplitude) or 0
    end
    return 0
end

function playOutputSound(kind, seed)
    local vol = math.min(3, math.max(0, OutputVolume or 0.7))
    local src
    if seed then
        src = sound(kind, seed)
    else
        src = sound(kind)
    end
    if src then
        pcall(function()
            src.volume = math.min(1, vol)
        end)
    end
    -- Peak is 1 at full blast; OutputVolume scales it in Glass.audioLevels
    outputPeak = math.max(outputPeak, 1)
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
    playOutputSound(SOUND_EXPLODE, 29480)
end

function draw()
    -- Soft workshop atmosphere
    background(22, 26, 34)
    drawBackdrop()
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
    drawScreenGlassOverlay()
    drawMeters()

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
        playOutputSound(SOUND_HIT, 20112)
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
    playOutputSound(SOUND_HIT, 31882)
end

-- Input ----------------------------------------------------------------

function touched(touch)
    if touch.state == BEGAN then
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
    elseif touch.state == MOVING and aiming then
        aimFromTouch(touch)
    elseif touch.state == ENDED or touch.state == CANCELLED then
        aiming = false
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
    if key == "\t" or key == "tab" or key == " " then
        fireCannon()
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

function hitButton(touch, b)
    return touch.x >= b.x and touch.x <= b.x + b.w
        and touch.y >= b.y and touch.y <= b.y + b.h
end

-- Drawing --------------------------------------------------------------

function drawBackdrop()
    -- Floor shadow band + ceiling wash
    noStroke()
    for i = 0, 10 do
        local t = i / 10
        fill(28 + t * 8, 32 + t * 6, 42 + t * 4)
        rect(0, HEIGHT * (0.55 + t * 0.045), WIDTH, HEIGHT * 0.05)
    end
    -- Soft spotlight over corridor
    fill(60, 70, 90, 28)
    ellipse(WIDTH * 0.55, corridorY + 40, WIDTH * 0.7, PANE_H * 1.6)
end

function drawGround()
    noStroke()
    fill(38, 42, 52)
    rect(0, 0, WIDTH, groundY)
    fill(48, 54, 66)
    rect(0, groundY - 6, WIDTH, 8)
    -- Floor planks
    stroke(30, 34, 42)
    strokeWidth(1)
    for x = 0, WIDTH, 48 do
        line(x, 8, x + 20, groundY - 10)
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
        stroke(180, 200, 255, 70)
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
            fill(220, 235, 255, 160)
            fontSize(14)
            textAlign(CENTER)
            textMode(CENTER)
            text(tostring(p.index), p.x, p.y + PANE_H * 0.5 + 18)
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
    fill(230, 235, 245)
    font("HelveticaNeue-Light")
    fontSize(22)
    textAlign(LEFT)
    textMode(CORNER)
    text("Chrome Cannon Glass", 22, HEIGHT - 34)

    fontSize(15)
    fill(160, 175, 195)
    text(string.format(
        "Aim · FIRE/Tab · panes %d/%d · KE %.0f · IN %.2f OUT %.2f",
        brokenCount, PANE_COUNT, lastKe, inputLevel, outputLevel), 22, HEIGHT - 56)

    if messageTimer > 0 and message ~= "" then
        fontSize(22)
        textAlign(CENTER)
        textMode(CENTER)
        fill(0, 0, 0, 150)
        rectMode(CENTER)
        rect(WIDTH * 0.5, HEIGHT * 0.9, math.min(WIDTH * 0.9, 720), 48)
        rectMode(CORNER)
        fill(255, 230, 150)
        text(message, WIDTH * 0.5, HEIGHT * 0.9)
    end
end

function drawButtons()
    local f, r = fireBtn(), resetBtn()
    -- Reset
    fill(50, 58, 72)
    rect(r.x, r.y, r.w, r.h, 10)
    fill(200, 210, 225)
    fontSize(18)
    textAlign(CENTER)
    textMode(CENTER)
    text("RESET", r.x + r.w * 0.5, r.y + r.h * 0.5)
    -- Fire
    if state == "ready" then
        fill(180, 70, 55)
    else
        fill(90, 50, 45)
    end
    rect(f.x, f.y, f.w, f.h, 10)
    fill(255, 240, 230)
    text("FIRE", f.x + f.w * 0.5, f.y + f.h * 0.5)
end

-- Main-screen glass (loud input/output) --------------------------------

function updateAudioGlass()
    local inG = InputGain or 1
    local outV = OutputVolume or 0.7
    local thresh = LoudnessBreak or 0.62
    local dt = DeltaTime or 0.016

    if Glass.tweakChanged(prevInputGain, prevOutputVolume, inG, outV) then
        resetScreenGlass()
        screenBreakCooldown = SCREEN_BREAK_COOLDOWN
        message = "Input/output tweaked — screen glass reset"
        messageTimer = 1.6
    end
    prevInputGain, prevOutputVolume = inG, outV

    outputPeak = outputPeak * math.max(0, 1 - dt * 1.35)
    if outputPeak < 0.02 then outputPeak = 0 end

    inputLevel, outputLevel = Glass.audioLevels(readMicAmp(), inG, outputPeak, outV)
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
    playOutputSound(SOUND_EXPLODE, 19221)
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
    local function bar(x, y, w, h, value, label, hot)
        fill(20, 22, 28, 180)
        rect(x, y, w, h, 6)
        local t = math.min(1, value / math.max(0.05, thresh * 1.4))
        if hot then
            fill(220, 70, 55)
        else
            fill(80, 170, 120)
        end
        rect(x + 4, y + 4, (w - 8) * t, h - 8, 4)
        fill(230, 235, 245)
        fontSize(13)
        textAlign(LEFT)
        textMode(CORNER)
        text(string.format("%s  %.2f", label, value), x, y + h + 4)
    end
    local inHot = inputLevel >= thresh
    local outHot = outputLevel >= thresh
    bar(22, 22, 160, 16, inputLevel, micOn and "IN  mic" or "IN  (no mic)", inHot)
    bar(200, 22, 160, 16, outputLevel, "OUT  speaker", outHot)
    fill(160, 175, 195)
    fontSize(12)
    text(screenBroken and "screen: shattered — tweak IN/OUT to reset"
        or "screen: intact — too loud = break", 22, 58)
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
