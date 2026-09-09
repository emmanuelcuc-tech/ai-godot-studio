-- Demolition
-- Codea (classic API): slingshot a wrecking ball into brick towers.
-- Knock the structure down. Clear the quota to finish the stage.
--
-- Controls:
--   Drag back from the ball — pull the slingshot
--   Release — fling the wrecking ball
--   RESET — rebuild the stage
--   NEXT — skip to next stage (after clear, tap also advances)

DISPLAYED_NAME = "Demolition"
APP_VERSION = "1.0.0"

SHOTS_PER_STAGE = 4
BLOCK = 36
BALL_R = 22
WIN_RATIO = 0.62

state = "aim" -- aim | flying | settled | won | lost
levelIndex = 1
shotsLeft = SHOTS_PER_STAGE
score = 0
message = ""
messageTimer = 0

ground = nil
blocks = {}
ball = nil
anchor = nil
particles = {}
dragging = false
dragStart = nil
dragNow = nil
settleTimer = 0
initialBlockCount = 0
resetBtn = { w = 130, h = 50 }
nextBtn = { w = 130, h = 50 }
floorY = 70

function setup()
    supportedOrientations(LANDSCAPE_ANY)
    displayMode(FULLSCREEN_NO_BUTTONS)

    parameter.integer("Level", 1, Levels.count(), 1)
    parameter.action("Restart Stage", function()
        levelIndex = Level
        startLevel(levelIndex)
    end)
    parameter.action("Next Stage", function()
        advanceLevel()
    end)

    physics.continuous = true
    physics.iterations(14, 10)
    physics.gravity(0, -980)

    startLevel(levelIndex)
end

function advanceLevel()
    if levelIndex >= Levels.count() then
        levelIndex = 1
    else
        levelIndex = levelIndex + 1
    end
    Level = levelIndex
    startLevel(levelIndex)
end

function clearWorld()
    physics.pause()
    if ball then ball:destroy(); ball = nil end
    if ground then ground:destroy(); ground = nil end
    if anchor then anchor:destroy(); anchor = nil end
    for _, b in ipairs(blocks) do
        if b.body then b.body:destroy() end
    end
    blocks = {}
    particles = {}
    physics.resume()
end

function startLevel(index)
    local data
    data, levelIndex = Levels.get(index)
    Level = levelIndex
    clearWorld()

    shotsLeft = data.shots or SHOTS_PER_STAGE
    score = 0
    state = "aim"
    dragging = false
    dragStart, dragNow = nil, nil
    settleTimer = 0
    message = data.name
    messageTimer = 2.5

    floorY = 70
    -- Ground
    local gw, gh = WIDTH + 200, 40
    ground = physics.body(POLYGON,
        vec2(-gw * 0.5, -gh * 0.5),
        vec2(gw * 0.5, -gh * 0.5),
        vec2(gw * 0.5, gh * 0.5),
        vec2(-gw * 0.5, gh * 0.5))
    ground.x = WIDTH * 0.5
    ground.y = floorY - gh * 0.5
    ground.type = STATIC
    ground.friction = 0.85
    ground.restitution = 0.05
    ground.info = "ground"

    -- Left backstop so ball doesn't fly forever left
    anchor = physics.body(POLYGON,
        vec2(-20, -HEIGHT),
        vec2(20, -HEIGHT),
        vec2(20, HEIGHT),
        vec2(-20, HEIGHT))
    anchor.x = -30
    anchor.y = HEIGHT * 0.5
    anchor.type = STATIC
    anchor.friction = 0.4
    anchor.info = "wall"

    buildStructure(data)
    spawnBallReady()
    initialBlockCount = #blocks
end

function buildStructure(data)
    local map = data.map
    local rows = #map
    local cols = #map[1]
    local baseX = data.baseX or (WIDTH * 0.62)
    local baseY = floorY + BLOCK * 0.5 + 2

    for r = rows, 1, -1 do
        local line = map[r]
        local rowFromBottom = rows - r
        for c = 1, cols do
            local ch = line:sub(c, c)
            if ch ~= "." and ch ~= " " then
                local kind = blockKind(ch)
                local cx = baseX + (c - (cols + 1) * 0.5) * BLOCK
                local cy = baseY + rowFromBottom * BLOCK
                local body = physics.body(POLYGON,
                    vec2(-BLOCK * 0.48, -BLOCK * 0.48),
                    vec2(BLOCK * 0.48, -BLOCK * 0.48),
                    vec2(BLOCK * 0.48, BLOCK * 0.48),
                    vec2(-BLOCK * 0.48, BLOCK * 0.48))
                body.x = cx
                body.y = cy
                body.type = DYNAMIC
                body.density = kind.density
                body.friction = kind.friction
                body.restitution = kind.restitution
                body.linearDamping = 0.08
                body.angularDamping = 0.12
                body.sleepingAllowed = true
                body.info = "block"
                table.insert(blocks, {
                    body = body,
                    kind = kind.id,
                    color = kind.color,
                    points = kind.points,
                    scored = false,
                    hp = kind.hp,
                })
            end
        end
    end
end

function blockKind(ch)
    if ch == "C" then -- concrete
        return {
            id = "concrete", density = 1.6, friction = 0.7, restitution = 0.08,
            color = color(160, 165, 175), points = 40, hp = 2,
        }
    elseif ch == "B" then -- brick
        return {
            id = "brick", density = 1.2, friction = 0.75, restitution = 0.1,
            color = color(190, 85, 55), points = 55, hp = 1,
        }
    elseif ch == "G" then -- glass
        return {
            id = "glass", density = 0.55, friction = 0.2, restitution = 0.05,
            color = color(140, 210, 230), points = 80, hp = 1,
        }
    elseif ch == "S" then -- steel
        return {
            id = "steel", density = 2.4, friction = 0.45, restitution = 0.2,
            color = color(120, 130, 145), points = 30, hp = 3,
        }
    elseif ch == "W" then -- wood
        return {
            id = "wood", density = 0.7, friction = 0.65, restitution = 0.15,
            color = color(150, 105, 55), points = 45, hp = 1,
        }
    end
    return {
        id = "brick", density = 1.2, friction = 0.7, restitution = 0.1,
        color = color(190, 85, 55), points = 50, hp = 1,
    }
end

function spawnBallReady()
    if ball then ball:destroy() end
    ball = physics.body(CIRCLE, BALL_R)
    ball.x = 130
    ball.y = floorY + BALL_R + 8
    ball.type = DYNAMIC
    ball.density = 3.2
    ball.friction = 0.35
    ball.restitution = 0.35
    ball.linearDamping = 0.05
    ball.angularDamping = 0.2
    ball.sleepingAllowed = false
    ball.info = "ball"
    ball.interpolate = true
    -- Hold still until launch
    ball.linearVelocity = vec2(0, 0)
    ball.type = STATIC
    state = "aim"
end

function touched(touch)
    local x, y = touch.x, touch.y

    if touch.state == ENDED then
        if hitBtn(resetBtn, x, y) then
            startLevel(levelIndex)
            return
        end
        if hitBtn(nextBtn, x, y) then
            if state == "won" or state == "lost" then
                advanceLevel()
            else
                advanceLevel()
            end
            return
        end
    end

    if state == "won" or state == "lost" then
        if touch.state == BEGAN then
            advanceLevel()
        end
        return
    end

    if state ~= "aim" or not ball then return end

    if touch.state == BEGAN then
        if dist(x, y, ball.x, ball.y) < 90 then
            dragging = true
            dragStart = vec2(ball.x, ball.y)
            dragNow = vec2(x, y)
        end
    elseif touch.state == MOVING and dragging then
        dragNow = vec2(x, y)
    elseif touch.state == ENDED and dragging then
        dragging = false
        launchBall()
        dragStart, dragNow = nil, nil
    end
end

function hitBtn(btn, x, y)
    return x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h
end

function launchBall()
    if not ball or not dragStart or not dragNow then return end
    if shotsLeft <= 0 then return end

    local pull = dragStart - dragNow
    local power = math.min(980, pull:len() * 3.4)
    if power < 120 then
        message = "Pull farther"
        messageTimer = 1
        return
    end

    ball.type = DYNAMIC
    ball.x = dragNow.x
    ball.y = dragNow.y
    local dir = pull:normalize()
    ball.linearVelocity = dir * power
    ball.angularVelocity = (math.random() - 0.5) * 8
    shotsLeft = shotsLeft - 1
    state = "flying"
    settleTimer = 0
    message = "IMPACT"
    messageTimer = 0.7
    burst(ball.x, ball.y, color(220, 230, 255), 10)
end

function collide(contact)
    if not contact or not contact.bodyA or not contact.bodyB then return end
    local a = contact.bodyA
    local b = contact.bodyB
    local speed = 0
    if a.linearVelocity and b.linearVelocity then
        local rx = a.linearVelocity.x - b.linearVelocity.x
        local ry = a.linearVelocity.y - b.linearVelocity.y
        speed = math.sqrt(rx * rx + ry * ry)
    end
    if speed < 180 then return end

    local bx = (a.x + b.x) * 0.5
    local by = (a.y + b.y) * 0.5
    local col = color(200, 190, 170)
    if (a.info == "ball" or b.info == "ball") then
        col = color(255, 220, 120)
        burst(bx, by, col, 14)
    else
        burst(bx, by, col, 6)
    end
end

function draw()
    local dt = DeltaTime
    if dt > 0.05 then dt = 0.05 end

    background(22, 26, 34)
    drawSkyline()
    drawGround()
    drawBlocks()
    drawBall()
    drawSling()
    drawParticles(dt)
    updateDemo(dt)
    drawHUD()

    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        fontSize(26)
        fill(255, 235, 200)
        textMode(CENTER)
        text(message, WIDTH * 0.5, HEIGHT * 0.58)
    end

    if state == "won" then
        drawBanner("STRUCTURE DOWN", "Tap for next demolition")
    elseif state == "lost" then
        drawBanner("STILL STANDING", "Tap to retry stage")
    elseif state == "aim" then
        fontSize(16)
        fill(180, 200, 220)
        textMode(CENTER)
        text("Drag the ball back · release to fling", WIDTH * 0.28, 130)
    end
end

function updateDemo(dt)
    updateParticlesOnly(dt)
    if state == "flying" or state == "settled" then
        scoreStandingBlocks()
        if state == "flying" then
            if ballSleeping() then
                settleTimer = settleTimer + dt
            else
                settleTimer = 0
            end
            if settleTimer > 1.15 then
                state = "settled"
                evaluateStage()
            end
            -- Ball fell off screen
            if ball and ball.y < -80 then
                settleTimer = settleTimer + dt
                if settleTimer > 0.6 then
                    state = "settled"
                    evaluateStage()
                end
            end
        end
    end
end

function ballSleeping()
    if not ball then return true end
    local v = ball.linearVelocity
    if not v then return true end
    local spd = math.sqrt(v.x * v.x + v.y * v.y)
    local w = math.abs(ball.angularVelocity or 0)
    return spd < 28 and w < 0.4
end

function scoreStandingBlocks()
    for _, b in ipairs(blocks) do
        if b.body and not b.scored then
            local fallen = b.body.y < floorY + BLOCK * 0.2
                or math.abs(b.body.angle or 0) > 55
                or b.body.x < 40 or b.body.x > WIDTH - 20
            if fallen then
                b.scored = true
                score = score + b.points
                burst(b.body.x, b.body.y, b.color, 8)
            end
        end
    end
end

function destructionRatio()
    if initialBlockCount <= 0 then return 1 end
    local down = 0
    for _, b in ipairs(blocks) do
        if b.scored then down = down + 1 end
    end
    return down / initialBlockCount
end

function evaluateStage()
    local ratio = destructionRatio()
    if ratio >= WIN_RATIO then
        state = "won"
        message = string.format("Cleared %.0f%%", ratio * 100)
        messageTimer = 2.5
        burst(WIDTH * 0.62, HEIGHT * 0.45, color(255, 200, 80), 36)
    elseif shotsLeft <= 0 then
        state = "lost"
        message = string.format("Only %.0f%% down", ratio * 100)
        messageTimer = 2.5
    else
        -- Prepare next shot
        spawnBallReady()
        message = shotsLeft .. " shots left"
        messageTimer = 1.4
    end
end

function drawSkyline()
    noStroke()
    fill(30, 36, 48)
    for i = 1, 12 do
        local x = i * 90 - 40
        local h = 80 + (i * 37) % 160
        rect(x, floorY, 50, h)
    end
    fill(255, 200, 90, 40)
    ellipse(WIDTH * 0.82, HEIGHT * 0.78, 120)
end

function drawGround()
    noStroke()
    fill(48, 52, 58)
    rect(0, 0, WIDTH, floorY)
    fill(70, 78, 70)
    rect(0, floorY - 8, WIDTH, 10)
    stroke(90, 100, 90)
    strokeWidth(2)
    line(0, floorY, WIDTH, floorY)
    noStroke()
end

function drawBlocks()
    rectMode(CENTER)
    for _, b in ipairs(blocks) do
        if b.body then
            pushMatrix()
            translate(b.body.x, b.body.y)
            rotate(b.body.angle or 0)
            local c = b.color
            local a = b.scored and 120 or 255
            fill(c.r, c.g, c.b, a)
            rect(0, 0, BLOCK * 0.92, BLOCK * 0.92, 3)
            -- edge
            stroke(20, 20, 25, 100)
            strokeWidth(1)
            noFill()
            rect(0, 0, BLOCK * 0.92, BLOCK * 0.92, 3)
            noStroke()
            if b.kind == "glass" then
                fill(255, 255, 255, 50)
                rect(0, 6, BLOCK * 0.5, 6, 2)
            elseif b.kind == "brick" then
                stroke(120, 50, 30, 150)
                strokeWidth(1)
                line(-BLOCK * 0.35, 0, BLOCK * 0.35, 0)
                noStroke()
            elseif b.kind == "steel" then
                fill(220, 230, 240, 80)
                rect(0, 0, BLOCK * 0.7, 4)
            end
            popMatrix()
        end
    end
    rectMode(CORNER)
end

function drawBall()
    if not ball then return end
    local x, y = ball.x, ball.y
    if state == "aim" and dragging and dragNow then
        x = dragNow.x
        y = dragNow.y
        -- visual only while aiming (body stays at rest until launch)
    end
    noStroke()
    fill(40, 45, 55, 80)
    ellipse(x + 4, y - 4, BALL_R * 2.2)
    fill(70, 78, 90)
    ellipse(x, y, BALL_R * 2)
    fill(160, 170, 185)
    ellipse(x - 5, y + 6, BALL_R * 0.9)
    fill(230, 235, 245)
    ellipse(x - 7, y + 8, BALL_R * 0.35)
end

function drawSling()
    if state ~= "aim" or not ball then return end
    local ax, ay = 130, floorY + BALL_R + 8
    -- posts
    stroke(90, 70, 45)
    strokeWidth(8)
    line(95, floorY, 95, floorY + 110)
    line(165, floorY, 165, floorY + 110)
    noStroke()
    fill(110, 85, 50)
    rect(85, floorY + 100, 90, 14, 4)

    local bx, by = ax, ay
    if dragging and dragNow then
        bx, by = dragNow.x, dragNow.y
        -- rubber bands
        stroke(180, 60, 50)
        strokeWidth(4)
        line(100, floorY + 105, bx, by)
        line(160, floorY + 105, bx, by)
        -- power ghost
        local pull = vec2(ax - bx, ay - by)
        local power = math.min(980, pull:len() * 3.4)
        local dir = pull:normalize()
        stroke(255, 220, 100, 120)
        strokeWidth(2)
        line(bx, by, bx + dir.x * power * 0.18, by + dir.y * power * 0.18)
        noStroke()
    else
        stroke(180, 60, 50)
        strokeWidth(3)
        line(100, floorY + 105, bx, by)
        line(160, floorY + 105, bx, by)
        noStroke()
    end
end

function burst(x, y, col, n)
    for i = 1, n do
        local ang = math.random() * math.pi * 2
        local spd = 60 + math.random() * 280
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd,
            life = 0.35 + math.random() * 0.55,
            r = 2 + math.random() * 4,
            col = col,
        })
    end
end

function updateParticlesOnly(dt)
    local next = {}
    for _, p in ipairs(particles) do
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy - 600 * dt
        p.life = p.life - dt
        if p.life > 0 then table.insert(next, p) end
    end
    particles = next
end

function drawParticles(dt)
    -- dt handled in updateDemo
    noStroke()
    for _, p in ipairs(particles) do
        local a = math.floor(255 * math.max(0, math.min(1, p.life)))
        fill(p.col.r, p.col.g, p.col.b, a)
        ellipse(p.x, p.y, p.r * 2)
    end
end

function drawHUD()
    fontSize(18)
    fill(230, 235, 245)
    textMode(CORNER)
    text("SCORE  " .. score, 20, HEIGHT - 28)
    text("SHOTS  " .. shotsLeft, 20, HEIGHT - 54)
    textMode(CENTER)
    text("STAGE  " .. levelIndex .. "/" .. Levels.count() .. "  ·  need " .. math.floor(WIN_RATIO * 100) .. "%", WIDTH * 0.5, HEIGHT - 28)
    local pct = math.floor(destructionRatio() * 100)
    fill(255, 200, 120)
    text("DOWN  " .. pct .. "%", WIDTH * 0.5, HEIGHT - 54)

    resetBtn.x = WIDTH - 150
    resetBtn.y = 18
    nextBtn.x = WIDTH - 150
    nextBtn.y = 78
    drawBtn(resetBtn, "RESET")
    drawBtn(nextBtn, "NEXT")
end

function drawBtn(btn, label)
    noStroke()
    fill(45, 52, 68)
    rect(btn.x, btn.y, btn.w, btn.h, 10)
    fill(220, 230, 245)
    fontSize(18)
    textMode(CENTER)
    text(label, btn.x + btn.w * 0.5, btn.y + btn.h * 0.5)
end

function drawBanner(title, sub)
    noStroke()
    fill(8, 10, 16, 200)
    rect(WIDTH * 0.5 - 240, HEIGHT * 0.5 - 70, 480, 140, 16)
    fontSize(34)
    fill(255, 210, 110)
    textMode(CENTER)
    text(title, WIDTH * 0.5, HEIGHT * 0.5 + 18)
    fontSize(17)
    fill(180, 200, 220)
    text(sub, WIDTH * 0.5, HEIGHT * 0.5 - 28)
end

function dist(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end
