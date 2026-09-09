-- Demolition
-- Codea: wrecking-ball + TNT demolition with real material fracture physics.
-- Glass shatters, wood splits on shock, concrete spalls, steel bends (ductile).
-- TNT: 4184 J/g reference, Kinney–Graham-style blast falloff.
--
-- Controls:
--   Drag ball back · release to fling
--   TNT button — place a charge on the structure (then auto-detonates)
--   RESET / NEXT

DISPLAYED_NAME = "Demolition"
APP_VERSION = "1.1.0"

SHOTS_PER_STAGE = 4
BLOCK = 36
BALL_R = 22
WIN_RATIO = 0.62
TNT_GRAMS = 25 -- stick-scale charge (game); energy from Materials.TNT_J_PER_G

state = "aim" -- aim | flying | settled | won | lost
levelIndex = 1
shotsLeft = SHOTS_PER_STAGE
tntLeft = 1
score = 0
message = ""
messageTimer = 0

ground = nil
blocks = {}
debris = {}
ball = nil
anchor = nil
particles = {}
cracks = {} -- visual crack lines {x,y,ang,life,col}
charges = {} -- armed TNT {x,y,fuse,grams}
dragging = false
dragStart = nil
dragNow = nil
settleTimer = 0
initialBlockCount = 0
resetBtn = { w = 130, h = 48 }
nextBtn = { w = 130, h = 48 }
tntBtn = { w = 130, h = 48 }
floorY = 70

function setup()
    supportedOrientations(LANDSCAPE_ANY)
    displayMode(FULLSCREEN_NO_BUTTONS)

    parameter.integer("Level", 1, Levels.count(), 1)
    parameter.number("TNT_Grams", 5, 200, TNT_GRAMS)
    parameter.boolean("ShowMaterialCard", true)
    parameter.action("Restart Stage", function()
        levelIndex = Level
        startLevel(levelIndex)
    end)
    parameter.action("Next Stage", function()
        advanceLevel()
    end)
    parameter.action("Detonate TNT", function()
        placeTNT()
    end)

    physics.continuous = true
    physics.iterations(16, 12)
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

function destroyList(list, field)
    for _, item in ipairs(list) do
        local body = field and item[field] or item.body
        if body and body.destroy then body:destroy() end
    end
end

function clearWorld()
    physics.pause()
    if ball then ball:destroy(); ball = nil end
    if ground then ground:destroy(); ground = nil end
    if anchor then anchor:destroy(); anchor = nil end
    destroyList(blocks, "body")
    destroyList(debris, "body")
    blocks = {}
    debris = {}
    particles = {}
    cracks = {}
    charges = {}
    physics.resume()
end

function startLevel(index)
    local data
    data, levelIndex = Levels.get(index)
    Level = levelIndex
    clearWorld()

    shotsLeft = data.shots or SHOTS_PER_STAGE
    tntLeft = data.tnt or 1
    TNT_GRAMS = TNT_Grams or TNT_GRAMS
    score = 0
    state = "aim"
    dragging = false
    dragStart, dragNow = nil, nil
    settleTimer = 0
    message = data.name
    messageTimer = 2.5

    floorY = 70
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

    anchor = physics.body(POLYGON,
        vec2(-20, -HEIGHT), vec2(20, -HEIGHT),
        vec2(20, HEIGHT), vec2(-20, HEIGHT))
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
                local id = Materials.fromChar(ch)
                local mat = Materials.get(id)
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
                body.density = mat.dens
                body.friction = mat.friction
                body.restitution = mat.restitution
                body.linearDamping = 0.08
                body.angularDamping = 0.12
                body.sleepingAllowed = true
                body.info = "block"
                table.insert(blocks, {
                    body = body,
                    kind = id,
                    mat = mat,
                    color = mat.color,
                    points = mat.points,
                    scored = false,
                    broken = false,
                    integrity = 1,
                    bent = 0,
                    crack = 0,
                })
            end
        end
    end
end

function spawnBallReady()
    if ball then ball:destroy() end
    ball = physics.body(CIRCLE, BALL_R)
    ball.x = 130
    ball.y = floorY + BALL_R + 8
    ball.type = STATIC
    ball.density = 3.2
    ball.friction = 0.35
    ball.restitution = 0.35
    ball.linearDamping = 0.05
    ball.angularDamping = 0.2
    ball.sleepingAllowed = false
    ball.info = "ball"
    ball.interpolate = true
    ball.linearVelocity = vec2(0, 0)
    state = "aim"
end

function findBlock(body)
    for _, b in ipairs(blocks) do
        if b.body == body then return b end
    end
    return nil
end

function touched(touch)
    local x, y = touch.x, touch.y

    if touch.state == ENDED then
        if hitBtn(resetBtn, x, y) then startLevel(levelIndex); return end
        if hitBtn(nextBtn, x, y) then advanceLevel(); return end
        if hitBtn(tntBtn, x, y) then placeTNT(); return end
    end

    if state == "won" or state == "lost" then
        if touch.state == BEGAN then advanceLevel() end
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
    return btn.x and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h
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

function placeTNT()
    if tntLeft <= 0 then
        message = "No TNT left"
        messageTimer = 1.2
        return
    end
    if state == "won" or state == "lost" then return end

    -- Place on nearest intact block to structure center
    local tx = WIDTH * 0.62
    local ty = floorY + BLOCK * 3
    local best, bestD = nil, 1e9
    for _, b in ipairs(blocks) do
        if b.body and not b.broken then
            local d = dist(tx, ty, b.body.x, b.body.y)
            if d < bestD then bestD = d; best = b end
        end
    end
    if not best then return end

    tntLeft = tntLeft - 1
    local grams = TNT_Grams or TNT_GRAMS
    table.insert(charges, {
        x = best.body.x,
        y = best.body.y,
        fuse = 0.85,
        grams = grams,
    })
    message = string.format("TNT armed · %.0fg (%.0f kJ)", grams, grams * 4.184)
    messageTimer = 1.6
    if state == "aim" then
        state = "flying"
        settleTimer = 0
    end
end

function detonate(charge)
    local grams = charge.grams or TNT_GRAMS
    local tntKg = grams / 1000
    local yieldJ = grams * Materials.TNT_J_PER_G
    burst(charge.x, charge.y, color(255, 180, 60), 42)
    burst(charge.x, charge.y, color(255, 80, 40), 24)
    message = string.format("BLAST · %.2f MJ", yieldJ / 1e6)
    messageTimer = 1.4

    -- Flash shockwave ring (visual)
    table.insert(cracks, {
        x = charge.x, y = charge.y, ang = 0, life = 0.45,
        col = color(255, 220, 120), ring = true, r0 = 20,
    })

    for _, b in ipairs(blocks) do
        if b.body and not b.broken then
            local dx = b.body.x - charge.x
            local dy = b.body.y - charge.y
            local distPx = math.max(8, math.sqrt(dx * dx + dy * dy))
            local distM = distPx / 80 -- ~80 px ≈ 1 m game scale
            local pKpa = Materials.blastImpulseAt(distM, tntKg)
            local mat = b.mat
            -- Blast creates rapid compression then tension (spall) — bias tensile
            local energy = pKpa * 12 * mat.blastWeak
            local stress = Materials.failureStress(mat, energy, 0.85)
            -- Impulse shove
            local inv = distPx
            local nx, ny = dx / inv, dy / inv
            local push = pKpa * 2.2 / mat.dens
            local v = b.body.linearVelocity or vec2(0, 0)
            b.body.linearVelocity = vec2(v.x + nx * push, v.y + ny * push)
            b.body.angularVelocity = (b.body.angularVelocity or 0) + (math.random() - 0.5) * pKpa * 0.05

            applyMaterialDamage(b, stress, energy, 0.9, nx, ny)
        end
    end
end

function collide(contact)
    if not contact or not contact.bodyA or not contact.bodyB then return end
    local a = contact.bodyA
    local b = contact.bodyB
    local speed = 0
    local rvx, rvy = 0, 0
    if a.linearVelocity and b.linearVelocity then
        rvx = a.linearVelocity.x - b.linearVelocity.x
        rvy = a.linearVelocity.y - b.linearVelocity.y
        speed = math.sqrt(rvx * rvx + rvy * rvy)
    end
    if speed < 120 then return end

    local bx = (a.x + b.x) * 0.5
    local by = (a.y + b.y) * 0.5
    local densA = a.density or 1
    local densB = b.density or 1
    local energy = Materials.impactEnergy(speed, densA, densB)

    -- Estimate tension factor from impact direction (glancing = more shear/tension)
    local nx = (b.x - a.x)
    local ny = (b.y - a.y)
    local nlen = math.max(1e-3, math.sqrt(nx * nx + ny * ny))
    nx, ny = nx / nlen, ny / nlen
    local closing = -(rvx * nx + rvy * ny)
    local tangential = math.abs(rvx * -ny + rvy * nx)
    local tensionFactor = 0.35 + 0.5 * (tangential / math.max(1, speed))
    if a.info == "ball" or b.info == "ball" then
        tensionFactor = tensionFactor + 0.15
        burst(bx, by, color(255, 220, 120), 12)
    else
        burst(bx, by, color(200, 190, 170), 5)
    end

    local blkA = findBlock(a)
    local blkB = findBlock(b)
    if blkA then applyMaterialDamage(blkA, Materials.failureStress(blkA.mat, energy, tensionFactor), energy, tensionFactor, -nx, -ny) end
    if blkB then applyMaterialDamage(blkB, Materials.failureStress(blkB.mat, energy, tensionFactor), energy, tensionFactor, nx, ny) end
end

function applyMaterialDamage(blk, stress, energy, tensionFactor, nx, ny)
    if not blk or blk.broken or not blk.body then return end
    local mat = blk.mat

    -- Steel: plastic bend absorbs energy instead of shattering
    if mat.mode == "bend" then
        local bendAdd = math.min(1, stress * 0.55)
        blk.bent = math.min(1, blk.bent + bendAdd)
        blk.integrity = math.max(0.15, 1 - blk.bent * 0.7)
        -- Soften restitution / add damping as it yields
        blk.body.restitution = mat.restitution * (1 - blk.bent * 0.5)
        blk.body.angularDamping = 0.12 + blk.bent * 0.5
        -- Visual warp via angle nudge
        blk.body.angularVelocity = (blk.body.angularVelocity or 0) + (math.random() - 0.5) * blk.bent * 3
        if stress < 1.15 then
            -- Survives: ductile energy sink
            score = score + math.floor(mat.points * 0.15 * bendAdd)
            return
        end
        -- Extreme overload finally snaps
    end

    -- Accumulate crack for brittle materials
    blk.crack = math.min(1, blk.crack + stress * (1.1 - mat.ductility))
    blk.integrity = math.max(0, 1 - blk.crack)

    if blk.crack > 0.25 then
        table.insert(cracks, {
            x = blk.body.x, y = blk.body.y,
            ang = math.random() * 180,
            life = 0.8,
            col = color(30, 30, 35),
            ring = false,
        })
    end

    local breakThreshold = 0.92
    if mat.mode == "shatter" then breakThreshold = 0.55 end
    if mat.mode == "split" then breakThreshold = 0.7 end
    if mat.mode == "spall" then breakThreshold = 0.75 end
    if mat.mode == "crumble" then breakThreshold = 0.8 end

    if stress >= breakThreshold or blk.crack >= 1 then
        fractureBlock(blk, energy, nx or 1, ny or 0)
    end
end

function fractureBlock(blk, energy, nx, ny)
    if blk.broken or not blk.body then return end
    blk.broken = true
    blk.scored = true
    score = score + blk.points
    local mat = blk.mat
    local x, y = blk.body.x, blk.body.y
    local vx = (blk.body.linearVelocity and blk.body.linearVelocity.x) or 0
    local vy = (blk.body.linearVelocity and blk.body.linearVelocity.y) or 0

    message = string.upper(mat.mode) .. " · " .. mat.label
    messageTimer = 0.9

    local n = mat.shards
    if mat.mode == "shatter" then
        burst(x, y, mat.color, 28)
        n = n + 3
    elseif mat.mode == "split" then
        burst(x, y, mat.color, 14)
        -- Prefer fragments along grain (horizontal split bias)
        nx, ny = 1, 0.15
    elseif mat.mode == "spall" then
        burst(x, y, color(180, 180, 185), 18)
    elseif mat.mode == "bend" then
        burst(x, y, color(160, 170, 190), 10)
        n = 2
    else
        burst(x, y, mat.color, 12)
    end

    -- Spawn physical debris shards
    for i = 1, n do
        local ang = (i / n) * math.pi * 2 + math.random() * 0.4
        local size = BLOCK * (0.12 + math.random() * 0.22)
        if mat.mode == "split" then
            size = BLOCK * (0.2 + (i % 2) * 0.15)
            ang = (i % 2 == 0) and 0.1 or math.pi + 0.1
        end
        local body = physics.body(POLYGON,
            vec2(-size, -size * 0.7),
            vec2(size, -size * 0.7),
            vec2(size, size * 0.7),
            vec2(-size, size * 0.7))
        body.x = x + math.cos(ang) * 6
        body.y = y + math.sin(ang) * 6
        body.type = DYNAMIC
        body.density = mat.dens * (mat.mode == "shatter" and 0.7 or 1)
        body.friction = mat.friction
        body.restitution = mat.mode == "shatter" and 0.02 or mat.restitution
        body.linearDamping = 0.1
        body.angularDamping = 0.08
        body.info = "debris"
        local speed = 80 + energy * 0.15 + math.random() * 120
        if mat.mode == "shatter" then speed = speed * 1.4 end
        body.linearVelocity = vec2(
            vx * 0.4 + math.cos(ang) * speed * (0.6 + math.abs(nx)),
            vy * 0.4 + math.sin(ang) * speed * (0.6 + math.abs(ny))
        )
        body.angularVelocity = (math.random() - 0.5) * 14
        table.insert(debris, {
            body = body,
            color = mat.color,
            kind = mat.mode,
            life = mat.mode == "shatter" and 4.5 or 8,
        })
    end

    blk.body:destroy()
    blk.body = nil
end

function draw()
    local dt = DeltaTime
    if dt > 0.05 then dt = 0.05 end

    background(22, 26, 34)
    drawSkyline()
    drawGround()
    drawBlocks()
    drawDebris()
    drawBall()
    drawSling()
    drawCharges()
    updateSim(dt)
    drawParticles()
    drawCracks()
    drawHUD()
    if ShowMaterialCard then
        drawMaterialCard()
    end

    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        fontSize(24)
        fill(255, 235, 200)
        textMode(CENTER)
        text(message, WIDTH * 0.5, HEIGHT * 0.58)
    end

    if state == "won" then
        drawBanner("STRUCTURE DOWN", "Materials failed · tap for next")
    elseif state == "lost" then
        drawBanner("STILL STANDING", "Steel held / not enough break")
    elseif state == "aim" then
        fontSize(15)
        fill(180, 200, 220)
        textMode(CENTER)
        text("Drag ball · TNT places blast charge", WIDTH * 0.28, 130)
    end
end

function updateSim(dt)
    -- TNT fuses
    local kept = {}
    for _, c in ipairs(charges) do
        c.fuse = c.fuse - dt
        if c.fuse <= 0 then
            detonate(c)
        else
            table.insert(kept, c)
        end
    end
    charges = kept

    -- Crack FX + debris lifetime
    local nextCracks = {}
    for _, c in ipairs(cracks) do
        c.life = c.life - dt
        if c.ring then c.r0 = (c.r0 or 20) + dt * 420 end
        if c.life > 0 then table.insert(nextCracks, c) end
    end
    cracks = nextCracks

    local nextDebris = {}
    for _, d in ipairs(debris) do
        d.life = d.life - dt
        if d.life <= 0 then
            if d.body then d.body:destroy() end
        else
            table.insert(nextDebris, d)
        end
    end
    debris = nextDebris

    updateParticlesOnly(dt)
    if state == "flying" or state == "settled" then
        scoreStandingBlocks()
        if state == "flying" then
            if ballSleeping() and #charges == 0 then
                settleTimer = settleTimer + dt
            else
                if #charges > 0 then settleTimer = 0 end
            end
            if settleTimer > 1.2 then
                state = "settled"
                evaluateStage()
            end
            if ball and ball.y < -80 then
                settleTimer = settleTimer + dt
                if settleTimer > 0.7 and #charges == 0 then
                    state = "settled"
                    evaluateStage()
                end
            end
        end
    end
end

function ballSleeping()
    if not ball or ball.type == STATIC then return true end
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
            -- Heavily bent steel counts partially destroyed
            if b.bent and b.bent > 0.85 then fallen = true end
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
        if b.scored or b.broken then down = down + 1 end
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
    elseif shotsLeft <= 0 and tntLeft <= 0 then
        state = "lost"
        message = string.format("Only %.0f%% down", ratio * 100)
        messageTimer = 2.5
    else
        spawnBallReady()
        message = shotsLeft .. " shots · " .. tntLeft .. " TNT"
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
        if b.body and not b.broken then
            pushMatrix()
            translate(b.body.x, b.body.y)
            local ang = (b.body.angle or 0) + b.bent * 18
            rotate(ang)
            local c = b.color
            local a = 255 * (0.45 + 0.55 * b.integrity)
            fill(c.r, c.g, c.b, a)
            local sx = BLOCK * 0.92 * (1 + b.bent * 0.15)
            local sy = BLOCK * 0.92 * (1 - b.bent * 0.25)
            rect(0, 0, sx, sy, 3)
            -- cracks
            if b.crack > 0.2 then
                stroke(25, 25, 30, 180 * b.crack)
                strokeWidth(1.5)
                line(-sx * 0.3, -sy * 0.2, sx * 0.25, sy * 0.35)
                if b.crack > 0.5 then
                    line(-sx * 0.1, sy * 0.35, sx * 0.35, -sy * 0.15)
                end
                noStroke()
            end
            if b.kind == "glass" then
                fill(255, 255, 255, 55)
                rect(0, 6, BLOCK * 0.5, 6, 2)
            elseif b.kind == "brick" then
                stroke(120, 50, 30, 150)
                strokeWidth(1)
                line(-BLOCK * 0.35, 0, BLOCK * 0.35, 0)
                noStroke()
            elseif b.kind == "steel" or b.kind == "rebar" then
                fill(220, 230, 240, 70 + b.bent * 40)
                rect(0, 0, BLOCK * 0.7, 4)
                if b.kind == "rebar" then
                    stroke(80, 90, 100, 160)
                    strokeWidth(2)
                    line(-BLOCK * 0.3, -BLOCK * 0.25, BLOCK * 0.3, BLOCK * 0.25)
                    line(-BLOCK * 0.3, BLOCK * 0.25, BLOCK * 0.3, -BLOCK * 0.25)
                    noStroke()
                end
            elseif b.kind == "wood" then
                stroke(90, 60, 30, 120)
                strokeWidth(1)
                line(-BLOCK * 0.3, -6, BLOCK * 0.3, -6)
                line(-BLOCK * 0.3, 6, BLOCK * 0.3, 6)
                noStroke()
            elseif b.kind == "concrete" then
                fill(120, 120, 125, 60)
                ellipse(-6, 4, 5)
                ellipse(8, -5, 4)
            elseif b.kind == "glass_safe" then
                fill(255, 255, 255, 40)
                rect(0, 0, BLOCK * 0.75, BLOCK * 0.75, 2)
                stroke(80, 160, 180, 150)
                strokeWidth(2)
                rect(0, 0, BLOCK * 0.85, BLOCK * 0.85, 2)
                noStroke()
            end
            popMatrix()
        end
    end
    rectMode(CORNER)
end

function drawDebris()
    rectMode(CENTER)
    for _, d in ipairs(debris) do
        if d.body then
            pushMatrix()
            translate(d.body.x, d.body.y)
            rotate(d.body.angle or 0)
            local c = d.color
            fill(c.r, c.g, c.b, 220)
            rect(0, 0, 12, 9, 2)
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
        stroke(180, 60, 50)
        strokeWidth(4)
        line(100, floorY + 105, bx, by)
        line(160, floorY + 105, bx, by)
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

function drawCharges()
    for _, c in ipairs(charges) do
        noStroke()
        fill(40, 90, 45)
        rectMode(CENTER)
        rect(c.x, c.y, 22, 28, 3)
        fill(200, 40, 40)
        ellipse(c.x, c.y + 16, 8)
        -- fuse spark
        if (ElapsedTime * 12) % 2 < 1 then
            fill(255, 200, 80)
            ellipse(c.x, c.y + 22, 6)
        end
        rectMode(CORNER)
        fontSize(10)
        fill(255)
        textMode(CENTER)
        text(string.format("%.0fg", c.grams), c.x, c.y - 2)
    end
end

function drawCracks()
    for _, c in ipairs(cracks) do
        if c.ring then
            noFill()
            stroke(c.col.r, c.col.g, c.col.b, 180 * c.life)
            strokeWidth(3)
            ellipse(c.x, c.y, c.r0 * 2)
            noStroke()
        end
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

function drawParticles()
    noStroke()
    for _, p in ipairs(particles) do
        local a = math.floor(255 * math.max(0, math.min(1, p.life)))
        fill(p.col.r, p.col.g, p.col.b, a)
        ellipse(p.x, p.y, p.r * 2)
    end
end

function drawHUD()
    fontSize(16)
    fill(230, 235, 245)
    textMode(CORNER)
    text("SCORE  " .. score, 20, HEIGHT - 26)
    text("SHOTS  " .. shotsLeft .. "   TNT  " .. tntLeft, 20, HEIGHT - 50)
    textMode(CENTER)
    text("STAGE  " .. levelIndex .. "/" .. Levels.count() .. "  ·  need " .. math.floor(WIN_RATIO * 100) .. "%", WIDTH * 0.5, HEIGHT - 26)
    local pct = math.floor(destructionRatio() * 100)
    fill(255, 200, 120)
    text("DOWN  " .. pct .. "%", WIDTH * 0.5, HEIGHT - 50)

    resetBtn.x = WIDTH - 150; resetBtn.y = 16
    tntBtn.x = WIDTH - 150; tntBtn.y = 72
    nextBtn.x = WIDTH - 150; nextBtn.y = 128
    drawBtn(resetBtn, "RESET")
    drawBtn(tntBtn, "TNT")
    drawBtn(nextBtn, "NEXT")
end

function drawMaterialCard()
    local rows = Materials.comparisonRows()
    local h = 28 + #rows * 18
    noStroke()
    fill(8, 10, 16, 200)
    rect(16, HEIGHT - 86 - h, 420, h, 10)
    fontSize(12)
    fill(255, 210, 120)
    textMode(CORNER)
    text("MATERIAL COMPARISON (blast / force)", 28, HEIGHT - 100)
    fill(200, 210, 230)
    local y = HEIGHT - 118
    for _, row in ipairs(rows) do
        text(row[1] .. "  ·  " .. row[4], 28, y)
        y = y - 18
    end
end

function drawBtn(btn, label)
    noStroke()
    local bg = 45
    if label == "TNT" then bg = 70 end
    fill(bg, 52, 68)
    if label == "TNT" then fill(70, 95, 55) end
    rect(btn.x, btn.y, btn.w, btn.h, 10)
    fill(220, 230, 245)
    fontSize(17)
    textMode(CENTER)
    text(label, btn.x + btn.w * 0.5, btn.y + btn.h * 0.5)
end

function drawBanner(title, sub)
    noStroke()
    fill(8, 10, 16, 200)
    rect(WIDTH * 0.5 - 250, HEIGHT * 0.5 - 70, 500, 140, 16)
    fontSize(32)
    fill(255, 210, 110)
    textMode(CENTER)
    text(title, WIDTH * 0.5, HEIGHT * 0.5 + 18)
    fontSize(16)
    fill(180, 200, 220)
    text(sub, WIDTH * 0.5, HEIGHT * 0.5 - 28)
end

function dist(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end
