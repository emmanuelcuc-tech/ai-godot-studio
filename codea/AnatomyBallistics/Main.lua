-- Anatomy Ballistics
-- Codea sandbox: shoot a soft-body anatomy figure with cinematic bullet cameras,
-- fabric-like skin tear, elastic muscle, cracking bones, and circulating blood.
--
-- Controls:
--   Drag finger — move red semi-opaque aim dot
--   Double-tap — fire one bullet (3s discharge cooldown)
--   RESET button / R — rebuild body + blood
--
-- Shot cameras: 2D side trail (red path) → overhead contact → slow-mo follow to impact

DISPLAYED_NAME = "Anatomy Ballistics"
APP_VERSION = "1.0.0"

-- Tunables (sidebar)
AimSensitivity = 1
ShowBones = true
ShowOrgans = true
ShowBlood = true
GoreIntensity = 1

-- Runtime
cam = nil
body = nil
blood = nil
meta = nil
bullet = nil
cooldownLeft = 0
timeScale = 1
impactDone = false
message = "Drag aim · Double-tap to fire · 3s cooldown"
messageTimer = 4
aimScreen = nil -- {x,y}
lastTapT, lastTapX, lastTapY = nil, nil, nil
resetBtn = { x = 0, y = 0, w = 140, h = 52 }
cooldownFlash = 0
woundSparks = {}

function setup()
    supportedOrientations(LANDSCAPE_ANY)
    displayMode(FULLSCREEN_NO_BUTTONS)

    parameter.number("AimSensitivity", 0.4, 2.0, 1)
    parameter.number("GoreIntensity", 0.4, 1.6, 1)
    parameter.boolean("ShowBones", true)
    parameter.boolean("ShowOrgans", true)
    parameter.boolean("ShowBlood", true)
    parameter.action("Reset Body", function()
        resetScene()
    end)
    parameter.action("Fire Test Shot", function()
        tryFire(WIDTH * 0.5, HEIGHT * 0.55)
    end)

    resetScene()
    aimScreen = { x = WIDTH * 0.5, y = HEIGHT * 0.55 }
end

function resetScene()
    body, blood, meta = Anatomy.build()
    cam = Camera.new()
    Camera.setAim(cam, meta.bodyCenter)
    bullet = nil
    cooldownLeft = 0
    timeScale = 1
    impactDone = false
    woundSparks = {}
    message = "Body reset · Aim with touch · Double-tap to shoot"
    messageTimer = 2.5
end

function tryFire(sx, sy)
    if not Ballistics.canFire(cooldownLeft) then
        message = string.format("Chambering… %.1fs", cooldownLeft)
        messageTimer = 1.2
        cooldownFlash = 0.35
        return false
    end
    if cam.mode ~= "aim" and cam.mode ~= "impact" then
        -- Allow fire only from aim (or after impact hold ends)
        if (cam.hold or 0) > 0 then
            return false
        end
    end
    Camera.setAim(cam, meta.bodyCenter)
    local origin, dir = Camera.lookRay(cam, sx, sy, WIDTH, HEIGHT)
    -- Start bullet slightly in front of camera
    local spawn = Vec3.add(origin, Vec3.scale(dir, 0.35))
    bullet = Ballistics.spawn(spawn, dir, Ballistics.MUZZLE_SPEED)
    cam.cine = {}
    cam.impactComplete = false
    cooldownLeft = Ballistics.COOLDOWN
    impactDone = false
    message = "Round away — cinematic tracking"
    messageTimer = 1.5
    return true
end

function touched(touch)
    -- Codea touch states: BEGAN, MOVING, ENDED
    local state = touch.state
    local x, y = touch.x, touch.y

    if insideReset(x, y) then
        if state == BEGAN or state == ENDED then
            -- fire on ENDED to avoid accidental drag
            if state == ENDED then
                resetScene()
            end
        end
        return
    end

    if state == MOVING or state == BEGAN then
        if cam.mode == "aim" or not bullet then
            aimScreen.x = aimScreen.x + (x - (aimScreen._lx or x)) * AimSensitivity
            aimScreen.y = aimScreen.y + (y - (aimScreen._ly or y)) * AimSensitivity
            -- Also absolute tracking feels better for aim dot
            aimScreen.x = x
            aimScreen.y = y
            aimScreen.x = math.max(40, math.min(WIDTH - 40, aimScreen.x))
            aimScreen.y = math.max(40, math.min(HEIGHT - 40, aimScreen.y))
        end
        aimScreen._lx, aimScreen._ly = x, y
    end

    if state == ENDED then
        aimScreen._lx, aimScreen._ly = nil, nil
        local now = ElapsedTime
        if Ballistics.doubleTap(lastTapT, lastTapX, lastTapY, now, x, y, 0.32, 56) then
            tryFire(aimScreen.x, aimScreen.y)
            lastTapT = nil
        else
            lastTapT, lastTapX, lastTapY = now, x, y
        end
    end
end

function insideReset(x, y)
    local b = resetBtn
    return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

-- Keyboard helpers for desktop Viewer
function keyboard(key)
    if key == "r" or key == "R" then
        resetScene()
    elseif key == " " or key == "\t" then
        tryFire(aimScreen.x, aimScreen.y)
    end
end

function draw()
    updateSim()
    drawWorld()
    drawHUD()
end

function updateSim()
    local dt = DeltaTime
    if dt > 0.05 then
        dt = 0.05
    end
    cooldownLeft = Ballistics.tickCooldown(cooldownLeft, dt)
    if messageTimer > 0 then
        messageTimer = messageTimer - dt
    end
    if cooldownFlash > 0 then
        cooldownFlash = cooldownFlash - dt
    end

    local bodyCenter = SoftBody.center(body)
    meta.bodyCenter = bodyCenter

    if bullet and (bullet.alive or not impactDone) then
        local phase
        phase, timeScale = Camera.updateCinematic(cam, bullet, bodyCenter, impactDone, dt)
        if bullet.alive then
            Ballistics.integrate(bullet, dt * timeScale)
            local hitIdx = Ballistics.hitNodeIndex(bullet, body.nodes, 0.22)
            if hitIdx then
                local n = body.nodes[hitIdx]
                local hitPos = Vec3.new(n.x, n.y, n.z)
                local ke = Ballistics.kineticEnergy(bullet.mass, Ballistics.speed(bullet.vel))
                ke = ke * GoreIntensity
                local torn = SoftBody.applyBulletImpact(body, hitPos, bullet.vel, ke, 0.5 * GoreIntensity)
                Blood.ruptureNear(blood, body, torn, bullet.vel)
                Blood.gushAt(blood, hitPos, bullet.vel, math.floor(14 * GoreIntensity))
                Ballistics.markHit(bullet, hitPos, Vec3.normalize(bullet.vel))
                impactDone = true
                Camera.setImpact(cam, hitPos, bodyCenter)
                message = "Impact — tissue / bone / blood reacting"
                messageTimer = 2
                for _ = 1, 12 do
                    woundSparks[#woundSparks + 1] = {
                        x = hitPos.x, y = hitPos.y, z = hitPos.z,
                        vx = (math.random() - 0.5) * 2,
                        vy = math.random() * 2,
                        vz = (math.random() - 0.5) * 2 - 1,
                        life = 0.6 + math.random() * 0.5,
                    }
                end
            elseif bullet.age > 6 or bullet.pos.y < -3 or Vec3.dist(bullet.pos, bodyCenter) > 14 then
                bullet.alive = false
                impactDone = true
                Camera.setAim(cam, bodyCenter)
                message = "Miss — double-tap to fire again"
                messageTimer = 2
            end
        end
    else
        timeScale = 1
        if cam.mode ~= "aim" and (not bullet or impactDone) and (cam.hold or 0) <= 0 then
            Camera.setAim(cam, bodyCenter)
        elseif cam.mode == "impact" then
            cam.hold = (cam.hold or 0) - dt
            if cam.hold <= 0 then
                Camera.setAim(cam, bodyCenter)
            end
        end
    end

    local tore = SoftBody.step(body, dt, timeScale)
    if #tore > 0 and bullet and bullet.hitPos then
        Blood.ruptureNear(blood, body, tore, bullet.vel or Vec3.new(0, 0, -1))
    end
    if ShowBlood then
        Blood.step(blood, dt, timeScale, body.nodes)
    end

    for i = #woundSparks, 1, -1 do
        local s = woundSparks[i]
        s.life = s.life - dt
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        s.z = s.z + s.vz * dt
        s.vy = s.vy - 6 * dt
        if s.life <= 0 then
            table.remove(woundSparks, i)
        end
    end
end

function drawWorld()
    -- Atmospheric backdrop
    background(18, 16, 20)
    drawFloorGrid()

    -- Depth-sort soft nodes for painter's algorithm (simple)
    local order = {}
    for i, n in ipairs(body.nodes) do
        local _, _, depth, vis = Camera.project(cam, n, WIDTH, HEIGHT)
        if vis then
            order[#order + 1] = { i = i, depth = depth }
        end
    end
    table.sort(order, function(a, b)
        return a.depth > b.depth
    end)

    -- Skin triangles (semi-transparent flesh)
    strokeWidth(0)
    for _, tri in ipairs(body.triangles) do
        local a, b, c = body.nodes[tri.i], body.nodes[tri.j], body.nodes[tri.k]
        -- Only draw if springs still connect loosely (any related spring alive heuristic)
        local sx1, sy1, d1, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local sx2, sy2, d2, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
        local sx3, sy3, d3, v3 = Camera.project(cam, c, WIDTH, HEIGHT)
        if v1 and v2 and v3 then
            local wet = (a.wet + b.wet + c.wet) / 3
            fill(170 + wet * 50, 90 - wet * 40, 80 - wet * 30, 55 + wet * 40)
            triangle(sx1, sy1, sx2, sy2, sx3, sy3)
        end
    end

    -- Springs: skin / muscle / bone
    for _, s in ipairs(body.springs) do
        if s.alive then
            local a, b = body.nodes[s.i], body.nodes[s.j]
            local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
            local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
            if v1 and v2 then
                local drawLine = true
                if s.kind == "skin" then
                    stroke(210, 140, 120, 90)
                    strokeWidth(1.2)
                elseif s.kind == "muscle" then
                    stroke(150, 45, 55, 110)
                    strokeWidth(1.6)
                elseif s.kind == "bone" then
                    if ShowBones then
                        local cr = math.max(a.crack, b.crack)
                        stroke(230 - cr * 80, 220 - cr * 100, 200 - cr * 120, 200)
                        strokeWidth(2.4)
                    else
                        drawLine = false
                    end
                else
                    stroke(180, 80, 90, 80)
                    strokeWidth(1)
                end
                if drawLine then
                    line(x1, y1, x2, y2)
                end
            end
        else
            -- Torn fabric strands (dangling)
            local a, b = body.nodes[s.i], body.nodes[s.j]
            local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
            local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
            if v1 and v2 and s.kind == "skin" then
                stroke(120, 30, 35, 70)
                strokeWidth(1)
                line(x1, y1, (x1 + x2) * 0.5, (y1 + y2) * 0.5)
            end
        end
    end

    -- Organs
    if ShowOrgans then
        noStroke()
        for _, org in ipairs(meta.organs) do
            for _, id in ipairs(org.ids) do
                local n = body.nodes[id]
                local sx, sy, depth, vis = Camera.project(cam, n, WIDTH, HEIGHT)
                if vis then
                    local r = 7 + 40 / depth
                    fill(org.rgb[1] * 255, org.rgb[2] * 255, org.rgb[3] * 255, 180)
                    ellipse(sx, sy, r * 2, r * 2)
                end
            end
        end
    end

    -- Bone joints highlight when cracked
    if ShowBones then
        noStroke()
        for _, n in ipairs(body.nodes) do
            if n.kind == "bone" then
                local sx, sy, depth, vis = Camera.project(cam, n, WIDTH, HEIGHT)
                if vis then
                    local r = 4 + 28 / depth
                    if n.crack > 0.4 then
                        fill(255, 230, 180, 220)
                    else
                        fill(235, 225, 210, 160)
                    end
                    ellipse(sx, sy, r * 2, r * 2)
                end
            end
        end
    end

    -- Blood
    if ShowBlood then
        noStroke()
        for _, p in ipairs(blood.particles) do
            local sx, sy, depth, vis = Camera.project(cam, p, WIDTH, HEIGHT)
            if vis then
                local r = (p.r or 0.04) * (220 / math.max(0.4, depth))
                local a = p.free and (200 * math.max(0.2, p.life)) or 160
                fill(170, 10, 22, a)
                ellipse(sx, sy, r * 2.4, r * 2.4)
                if p.free then
                    fill(220, 30, 40, a * 0.5)
                    ellipse(sx, sy, r, r)
                end
            end
        end
    end

    -- Wound sparks (tissue flecks)
    noStroke()
    for _, s in ipairs(woundSparks) do
        local sx, sy, _, vis = Camera.project(cam, s, WIDTH, HEIGHT)
        if vis then
            fill(160, 40, 40, 200 * s.life)
            ellipse(sx, sy, 5, 5)
        end
    end

    -- Bullet + red trajectory trail
    if bullet then
        drawBulletTrail(bullet)
        if bullet.alive or bullet.hit then
            local p = bullet.alive and bullet.pos or bullet.hitPos
            local sx, sy, depth, vis = Camera.project(cam, p, WIDTH, HEIGHT)
            if vis then
                fill(240, 220, 80, 230)
                local r = 5 + 30 / math.max(0.5, depth)
                ellipse(sx, sy, r * 2, r * 2)
            end
        end
    end
end

function drawBulletTrail(b)
    local trail = b.trail
    if not trail or #trail < 2 then
        return
    end
    -- Side-trail cinematic uses thicker red path
    local thick = (cam.mode == "side_trail") and 3.2 or 2.0
    for i = 2, #trail do
        local a, c = trail[i - 1], trail[i]
        local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local x2, y2, _, v2 = Camera.project(cam, c, WIDTH, HEIGHT)
        if v1 and v2 then
            local t = i / #trail
            stroke(255, 40 + 40 * t, 40, 80 + 140 * t)
            strokeWidth(thick)
            line(x1, y1, x2, y2)
        end
    end
    -- Predicted velocity tick
    if b.alive then
        local tip = Vec3.add(b.pos, Vec3.scale(Vec3.normalize(b.vel), 0.35))
        local x1, y1, _, v1 = Camera.project(cam, b.pos, WIDTH, HEIGHT)
        local x2, y2, _, v2 = Camera.project(cam, tip, WIDTH, HEIGHT)
        if v1 and v2 then
            stroke(255, 80, 80, 220)
            strokeWidth(2)
            line(x1, y1, x2, y2)
        end
    end
end

function drawFloorGrid()
    stroke(40, 38, 48, 120)
    strokeWidth(1)
    for gx = -3, 3 do
        local a = Vec3.new(gx * 0.7, SoftBody.GROUND_Y, -2)
        local b = Vec3.new(gx * 0.7, SoftBody.GROUND_Y, 2)
        local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
        if v1 and v2 then
            line(x1, y1, x2, y2)
        end
    end
    for gz = -3, 3 do
        local a = Vec3.new(-2.5, SoftBody.GROUND_Y, gz * 0.7)
        local b = Vec3.new(2.5, SoftBody.GROUND_Y, gz * 0.7)
        local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
        if v1 and v2 then
            line(x1, y1, x2, y2)
        end
    end
end

function drawHUD()
    -- Aim reticle (partially opaque red)
    if cam.mode == "aim" or not bullet or impactDone then
        local ax, ay = aimScreen.x, aimScreen.y
        noStroke()
        fill(255, 30, 30, 90)
        ellipse(ax, ay, 28, 28)
        fill(255, 40, 40, 160)
        ellipse(ax, ay, 10, 10)
        stroke(255, 60, 60, 180)
        strokeWidth(1.5)
        line(ax - 22, ay, ax - 10, ay)
        line(ax + 10, ay, ax + 22, ay)
        line(ax, ay - 22, ax, ay - 10)
        line(ax, ay + 10, ax, ay + 22)
    end

    -- Reset button
    resetBtn.x = WIDTH - 160
    resetBtn.y = HEIGHT - 70
    resetBtn.w = 140
    resetBtn.h = 48
    noStroke()
    fill(50, 48, 58, 220)
    rect(resetBtn.x, resetBtn.y, resetBtn.w, resetBtn.h)
    fill(230, 230, 235)
    fontSize(18)
    textAlign(CENTER)
    textMode(CENTER)
    text("RESET", resetBtn.x + resetBtn.w * 0.5, resetBtn.y + resetBtn.h * 0.5)

    -- Cooldown pip
    local cx, cy = 90, HEIGHT - 46
    fill(35, 34, 42, 220)
    rect(20, HEIGHT - 72, 150, 52)
    local ready = Ballistics.canFire(cooldownLeft)
    if ready then
        fill(80, 200, 110, 230)
        text("READY", cx, cy)
    else
        fill(220, 90, 70, 230)
        local t = string.format("%.1fs", cooldownLeft)
        text(t, cx, cy)
        -- Bar
        local w = 120 * (1 - cooldownLeft / Ballistics.COOLDOWN)
        fill(200, 70, 60, 180)
        rect(30, HEIGHT - 28, w, 6)
    end
    if cooldownFlash > 0 then
        fill(255, 80, 80, 80 * cooldownFlash / 0.35)
        rect(0, 0, WIDTH, HEIGHT)
    end

    -- Camera mode badge
    fill(255, 255, 255, 160)
    fontSize(14)
    textAlign(LEFT)
    textMode(CORNER)
    local modeLabel = string.upper(cam.mode or "aim")
    text(modeLabel .. string.format("  ·  x%.2f time", timeScale), 24, 28)
    text("Anatomy Ballistics " .. APP_VERSION, 24, 48)

    if messageTimer > 0 then
        fill(255, 240, 240, 220)
        fontSize(16)
        textAlign(CENTER)
        textMode(CENTER)
        text(message, WIDTH * 0.5, 36)
    end

    -- Side-trail helper label
    if cam.mode == "side_trail" then
        fill(255, 80, 80, 200)
        fontSize(15)
        text("BULLET TRAIL", WIDTH * 0.5, HEIGHT - 36)
    elseif cam.mode == "overhead" then
        fill(200, 220, 255, 200)
        text("OVERHEAD CONTACT", WIDTH * 0.5, HEIGHT - 36)
    elseif cam.mode == "follow_slow" then
        fill(255, 220, 120, 200)
        text("SLOW-MO FOLLOW", WIDTH * 0.5, HEIGHT - 36)
    end
end
