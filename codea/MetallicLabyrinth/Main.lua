-- Metallic Labyrinth
-- Codea (classic API): tilt the iPad to roll a chrome ball to the goal.
-- Traps sit beside the cup — one wrong lean and you fall in.
--
-- Controls: tilt iPad (Gravity). Tap to restart after win/lose.
-- Desktop / Viewer without tilt: drag finger to push the ball.

DISPLAYED_NAME = "Metallic Labyrinth"

-- Tunables
BALL_RADIUS = 14
CELL = 36
GRAVITY_SCALE = 920
MAX_SPEED = 520
TRAP_RADIUS_RATIO = 0.72
GOAL_RADIUS_RATIO = 0.78
BUMPER_BOUNCE = 1.35

-- State
state = "play" -- play | won | lost
levelIndex = 1
lives = 3
needsFullRestart = false
message = ""
messageTimer = 0

ball = nil
walls = {}
traps = {}
goals = {}
bumpers = {}
spawn = vec2(0, 0)
mazeOrigin = vec2(0, 0)
cols, rows = 0, 0

-- Finger assist (simulates tilt when Gravity is flat)
fingerPush = vec2(0, 0)
fingerActive = false

function setup()
    supportedOrientations(LANDSCAPE_ANY)
    displayMode(FULLSCREEN_NO_BUTTONS)

    parameter.integer("Level", 1, Levels.count(), 1)
    parameter.action("Restart Level", function()
        levelIndex = Level
        startLevel(levelIndex)
    end)
    parameter.action("Next Level", function()
        levelIndex = levelIndex + 1
        if levelIndex > Levels.count() then
            levelIndex = 1
        end
        Level = levelIndex
        startLevel(levelIndex)
    end)

    physics.pause()
    physics.continuous = true
    physics.iterations(12, 8)

    startLevel(levelIndex)
end

function startLevel(index)
    clearBodies()
    local data
    data, levelIndex = Levels.get(index)
    Level = levelIndex
    state = "play"
    message = data.name
    messageTimer = 2.2
    lives = math.max(lives, 1)

    local map = data.map
    rows = #map
    cols = #map[1]
    local mazeW = cols * CELL
    local mazeH = rows * CELL
    mazeOrigin = vec2((WIDTH - mazeW) * 0.5, (HEIGHT - mazeH) * 0.5)

    walls = {}
    traps = {}
    goals = {}
    bumpers = {}
    spawn = vec2(mazeOrigin.x + CELL * 1.5, mazeOrigin.y + CELL * 1.5)

    for r = 1, rows do
        local line = map[r]
        for c = 1, cols do
            local ch = line:sub(c, c)
            local cx = mazeOrigin.x + (c - 0.5) * CELL
            -- Codea Y grows upward; map row 1 is top of screen
            local cy = mazeOrigin.y + (rows - r + 0.5) * CELL

            if ch == "#" then
                local body = physics.body(POLYGON,
                    vec2(-CELL * 0.5, -CELL * 0.5),
                    vec2(CELL * 0.5, -CELL * 0.5),
                    vec2(CELL * 0.5, CELL * 0.5),
                    vec2(-CELL * 0.5, CELL * 0.5))
                body.x = cx
                body.y = cy
                body.type = STATIC
                body.friction = 0.35
                body.restitution = 0.18
                body.info = "wall"
                table.insert(walls, body)
            elseif ch == "S" then
                spawn = vec2(cx, cy)
            elseif ch == "G" then
                table.insert(goals, { x = cx, y = cy, r = CELL * 0.5 * GOAL_RADIUS_RATIO })
            elseif ch == "T" then
                table.insert(traps, { x = cx, y = cy, r = CELL * 0.5 * TRAP_RADIUS_RATIO })
            elseif ch == "B" then
                local body = physics.body(CIRCLE, CELL * 0.38)
                body.x = cx
                body.y = cy
                body.type = STATIC
                body.friction = 0.05
                body.restitution = BUMPER_BOUNCE
                body.info = "bumper"
                table.insert(bumpers, { body = body, x = cx, y = cy, pulse = 0 })
            end
        end
    end

    -- Outer frame so the ball cannot escape the board
    addFrame(mazeW, mazeH)

    ball = physics.body(CIRCLE, BALL_RADIUS)
    ball.x = spawn.x
    ball.y = spawn.y
    ball.type = DYNAMIC
    ball.density = 1.4
    ball.friction = 0.12
    ball.restitution = 0.42
    ball.linearDamping = 0.15
    ball.angularDamping = 0.4
    ball.sleepingAllowed = false
    ball.info = "ball"
    ball.interpolate = true

    physics.resume()
    physics.gravity(0, 0)
end

function addFrame(mazeW, mazeH)
    local t = 18
    local ox, oy = mazeOrigin.x, mazeOrigin.y
    local frames = {
        { ox + mazeW * 0.5, oy - t * 0.5, mazeW + t * 2, t },
        { ox + mazeW * 0.5, oy + mazeH + t * 0.5, mazeW + t * 2, t },
        { ox - t * 0.5, oy + mazeH * 0.5, t, mazeH },
        { ox + mazeW + t * 0.5, oy + mazeH * 0.5, t, mazeH },
    }
    for _, f in ipairs(frames) do
        local body = physics.body(POLYGON,
            vec2(-f[3] * 0.5, -f[4] * 0.5),
            vec2(f[3] * 0.5, -f[4] * 0.5),
            vec2(f[3] * 0.5, f[4] * 0.5),
            vec2(-f[3] * 0.5, f[4] * 0.5))
        body.x = f[1]
        body.y = f[2]
        body.type = STATIC
        body.friction = 0.4
        body.restitution = 0.1
        body.info = "frame"
        table.insert(walls, body)
    end
end

function clearBodies()
    physics.pause()
    if ball then
        ball:destroy()
        ball = nil
    end
    for _, w in ipairs(walls) do
        if w then w:destroy() end
    end
    for _, b in ipairs(bumpers) do
        if b.body then b.body:destroy() end
    end
    walls = {}
    bumpers = {}
    traps = {}
    goals = {}
end

function draw()
    background(18, 20, 28)

    drawBoard()
    drawTraps()
    drawGoals()
    drawBumpers()
    if ball then
        drawMetallicBall(ball.x, ball.y, BALL_RADIUS, ball.angle or 0)
    end
    drawHUD()

    if state == "play" then
        applyTilt()
        checkHoles()
    end

    if messageTimer > 0 then
        messageTimer = messageTimer - DeltaTime
    end
end

function applyTilt()
    -- Gravity is screen-relative while Viewer runs; z ~ -1 when flat on table.
    local gx = Gravity.x
    local gy = Gravity.y
    local tiltMag = math.sqrt(gx * gx + gy * gy)

    -- If nearly flat / simulator, allow finger push
    if tiltMag < 0.08 and fingerActive then
        gx = fingerPush.x
        gy = fingerPush.y
    end

    physics.gravity(gx * GRAVITY_SCALE, gy * GRAVITY_SCALE)

    if ball and ball.linearVelocity then
        local vx, vy = ball.linearVelocity.x, ball.linearVelocity.y
        local speed = math.sqrt(vx * vx + vy * vy)
        if speed > MAX_SPEED then
            local s = MAX_SPEED / speed
            ball.linearVelocity = vec2(vx * s, vy * s)
        end
    end
end

function checkHoles()
    if not ball then return end
    local bx, by = ball.x, ball.y

    for _, t in ipairs(traps) do
        if dist(bx, by, t.x, t.y) < t.r - BALL_RADIUS * 0.25 then
            fallInTrap()
            return
        end
    end

    for _, g in ipairs(goals) do
        if dist(bx, by, g.x, g.y) < g.r - BALL_RADIUS * 0.35 then
            reachGoal()
            return
        end
    end
end

function fallInTrap()
    if state ~= "play" then return end
    state = "lost"
    lives = lives - 1
    sound(SOUND_HIT, 28491)
    if ball then
        ball.linearVelocity = vec2(0, 0)
        ball.type = STATIC
    end
    if lives <= 0 then
        needsFullRestart = true
        message = "Out of lives — tap to retry"
        messageTimer = 99
    else
        needsFullRestart = false
        message = "Fell in a trap! Lives: " .. lives
        messageTimer = 1.6
        tween.delay(0.85, function()
            if state == "lost" and not needsFullRestart then
                resetBall()
                state = "play"
            end
        end)
    end
end

function reachGoal()
    state = "won"
    sound(SOUND_POWERUP, 21950)
    if levelIndex >= Levels.count() then
        message = "You cleared every maze! Tap to play again"
    else
        message = "Goal! Tap for next maze"
    end
    messageTimer = 99
    if ball then
        ball.linearVelocity = vec2(0, 0)
        ball.type = STATIC
    end
end

function resetBall()
    if not ball then return end
    ball.type = DYNAMIC
    ball.x = spawn.x
    ball.y = spawn.y
    ball.linearVelocity = vec2(0, 0)
    ball.angularVelocity = 0
    physics.gravity(0, 0)
end

function touched(touch)
    if touch.state == BEGAN then
        if state == "won" then
            levelIndex = levelIndex + 1
            if levelIndex > Levels.count() then
                levelIndex = 1
            end
            lives = math.max(lives, 3)
            startLevel(levelIndex)
            return
        elseif state == "lost" and needsFullRestart then
            lives = 3
            needsFullRestart = false
            startLevel(levelIndex)
            return
        end
        fingerActive = true
        updateFinger(touch)
    elseif touch.state == MOVING and fingerActive then
        updateFinger(touch)
    elseif touch.state == ENDED or touch.state == CANCELLED then
        fingerActive = false
        fingerPush = vec2(0, 0)
    end
end

function updateFinger(touch)
    if not ball then return end
    local dx = touch.x - ball.x
    local dy = touch.y - ball.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then
        fingerPush = vec2(0, 0)
        return
    end
    -- Normalize and scale into Gravity-like range [-1,1]
    fingerPush = vec2(dx / len, dy / len) * math.min(1, len / 120)
end

-- Drawing ---------------------------------------------------------------

function drawBoard()
    -- Table wood / metal plate
    local mazeW = cols * CELL
    local mazeH = rows * CELL
    noStroke()
    fill(42, 48, 58)
    rect(mazeOrigin.x - 10, mazeOrigin.y - 10, mazeW + 20, mazeH + 20)

    -- Floor cells
    for r = 1, rows do
        local line = Levels.data[levelIndex].map[r]
        for c = 1, cols do
            local ch = line:sub(c, c)
            if ch ~= "#" then
                local cx = mazeOrigin.x + (c - 1) * CELL
                local cy = mazeOrigin.y + (rows - r) * CELL
                if (r + c) % 2 == 0 then
                    fill(58, 64, 76)
                else
                    fill(52, 58, 70)
                end
                rect(cx, cy, CELL, CELL)
            end
        end
    end

    -- Walls with bevel
    for _, w in ipairs(walls) do
        if w.info == "wall" then
            local x = w.x - CELL * 0.5
            local y = w.y - CELL * 0.5
            fill(22, 24, 30)
            rect(x, y, CELL, CELL)
            fill(70, 78, 92)
            rect(x + 2, y + CELL - 5, CELL - 4, 3)
            fill(12, 14, 18)
            rect(x + 2, y + 2, CELL - 4, 3)
        end
    end

    -- Draw frame as thick border
    stroke(90, 98, 112)
    strokeWidth(14)
    noFill()
    rect(mazeOrigin.x - 7, mazeOrigin.y - 7, mazeW + 14, mazeH + 14)
    noStroke()
end

function drawTraps()
    for _, t in ipairs(traps) do
        -- Dark pit with red rim warning
        for i = 5, 1, -1 do
            local a = 40 + i * 25
            fill(8, 4, 6, a)
            ellipse(t.x, t.y, t.r * 2 * (i / 5))
        end
        fill(4, 2, 4)
        ellipse(t.x, t.y, t.r * 1.7)
        stroke(160, 40, 48)
        strokeWidth(2)
        noFill()
        ellipse(t.x, t.y, t.r * 2)
        noStroke()
        -- Danger ticks
        fill(180, 50, 55, 180)
        for a = 0, 5 do
            local ang = a * math.pi / 3 + ElapsedTime * 0.6
            local px = t.x + math.cos(ang) * (t.r * 0.55)
            local py = t.y + math.sin(ang) * (t.r * 0.55)
            ellipse(px, py, 4)
        end
    end
end

function drawGoals()
    for _, g in ipairs(goals) do
        -- Soft glow
        fill(40, 180, 110, 50)
        ellipse(g.x, g.y, g.r * 2.6)
        fill(30, 140, 90, 90)
        ellipse(g.x, g.y, g.r * 2.1)
        fill(20, 90, 60)
        ellipse(g.x, g.y, g.r * 1.6)
        fill(12, 50, 35)
        ellipse(g.x, g.y, g.r * 1.15)
        -- Cup lip
        stroke(90, 220, 150)
        strokeWidth(3)
        noFill()
        ellipse(g.x, g.y, g.r * 2)
        noStroke()
        fill(200, 255, 220, 160)
        ellipse(g.x - g.r * 0.25, g.y + g.r * 0.25, 6)
    end
end

function drawBumpers()
    for _, b in ipairs(bumpers) do
        b.pulse = (b.pulse or 0) + DeltaTime * 3
        local s = 1 + 0.06 * math.sin(b.pulse)
        fill(200, 120, 40)
        ellipse(b.x, b.y, CELL * 0.76 * s)
        fill(255, 180, 80)
        ellipse(b.x - 4, b.y + 5, CELL * 0.28)
        fill(80, 40, 10)
        ellipse(b.x, b.y, CELL * 0.22)
    end
end

function drawMetallicBall(x, y, r, angle)
    -- Chrome sphere: dark rim, silver body, specular highlight
    fill(20, 22, 28, 90)
    ellipse(x + 3, y - 3, r * 2.15)

    for i = 8, 1, -1 do
        local t = i / 8
        local shade = 70 + t * 140
        fill(shade, shade + 4, shade + 10)
        ellipse(x - r * 0.08 * (1 - t), y + r * 0.08 * (1 - t), r * 2 * t)
    end

    -- Cool metal band
    stroke(180, 190, 205, 120)
    strokeWidth(2)
    noFill()
    ellipse(x, y, r * 1.85)
    noStroke()

    -- Specular
    fill(255, 255, 255, 220)
    ellipse(x - r * 0.35, y + r * 0.38, r * 0.55)
    fill(255, 255, 255, 140)
    ellipse(x + r * 0.25, y - r * 0.15, r * 0.22)

    -- Tiny engraved line to show spin
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
    text(string.format("Metallic Labyrinth  ·  Lv %d/%d  ·  Lives %d",
        levelIndex, Levels.count(), lives), 24, HEIGHT - 36)

    fontSize(16)
    fill(160, 170, 185)
    text("Tilt iPad to roll  ·  Goal = green cup  ·  Red pits = traps", 24, HEIGHT - 58)

    if messageTimer > 0 and message ~= "" then
        fontSize(28)
        textAlign(CENTER)
        textMode(CENTER)
        fill(0, 0, 0, 140)
        rectMode(CENTER)
        rect(WIDTH * 0.5, HEIGHT * 0.12, math.min(WIDTH * 0.85, 640), 54)
        rectMode(CORNER)
        fill(255, 230, 140)
        text(message, WIDTH * 0.5, HEIGHT * 0.12)
    end

    if state == "won" or needsFullRestart then
        fontSize(18)
        fill(200, 210, 230)
        textAlign(CENTER)
        textMode(CENTER)
        text("Tap anywhere to continue", WIDTH * 0.5, HEIGHT * 0.06)
    end
end

-- Helpers ---------------------------------------------------------------

function dist(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

function collide(contact)
    -- Optional: bumper ding
    if contact.state == BEGAN then
        local a = contact.bodyA and contact.bodyA.info
        local b = contact.bodyB and contact.bodyB.info
        if a == "bumper" or b == "bumper" then
            sound(SOUND_JUMP, 16402)
        end
    end
end
