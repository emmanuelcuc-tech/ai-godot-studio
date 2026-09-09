-- Anatomy Ballistics
-- Codea sandbox: .22 LR staged ranges (40→15 ft, then drywall+wood wall),
-- soft-body anatomy with functioning organs, bone density fracture thresholds,
-- circulating blood / bile, cinematic bullet cameras.
--
-- Controls:
--   Drag finger — red semi-opaque aim dot
--   Double-tap — fire (.22 LR, 3s cooldown)
--   RESET — rebuild body; stages restart at 40 ft
--   NEXT / N — advance range stage manually
--
-- Stages auto-advance after impact: 40,35,30,25,20,15 ft → house wall

DISPLAYED_NAME = "Anatomy Ballistics"
APP_VERSION = "1.1.0"

-- Tunables (sidebar)
AimSensitivity = 1
ShowBones = true
ShowOrgans = true
ShowBlood = true
GoreIntensity = 1
AutoAdvance = true

-- Runtime
cam = nil
body = nil
blood = nil
meta = nil
bullet = nil
stage = nil
organState = nil
cooldownLeft = 0
timeScale = 1
impactDone = false
pendingAdvance = false
message = "Stage 1 · 40 ft .22 LR · Double-tap to fire"
messageTimer = 4
aimScreen = nil
lastTapT, lastTapX, lastTapY = nil, nil, nil
resetBtn = { x = 0, y = 0, w = 140, h = 52 }
nextBtn = { x = 0, y = 0, w = 140, h = 52 }
cooldownFlash = 0
woundSparks = {}
wallDebris = {}
wallZ = 1.85
wallBroken = false

function setup()
    supportedOrientations(LANDSCAPE_ANY)
    displayMode(FULLSCREEN_NO_BUTTONS)

    parameter.number("AimSensitivity", 0.4, 2.0, 1)
    parameter.number("GoreIntensity", 0.4, 1.6, 1)
    parameter.boolean("ShowBones", true)
    parameter.boolean("ShowOrgans", true)
    parameter.boolean("ShowBlood", true)
    parameter.boolean("AutoAdvance", true)
    parameter.action("Reset Body", function()
        resetScene()
    end)
    parameter.action("Next Stage", function()
        advanceStage(true)
    end)
    parameter.action("Fire Test Shot", function()
        tryFire(WIDTH * 0.5, HEIGHT * 0.55)
    end)

    resetScene()
    aimScreen = { x = WIDTH * 0.5, y = HEIGHT * 0.55 }
end

function applyStageCamera()
    local snap = stage.snap
    stage.autoAdvance = AutoAdvance
    Camera.setAim(cam, meta.bodyCenter, snap.rangeFeet)
    wallBroken = false
    wallDebris = {}
end

function resetScene()
    body, blood, meta = Anatomy.build()
    organState = Organs.newState()
    stage = Stages.new(TwentyTwo.DEFAULT_LOAD)
    cam = Camera.new()
    applyStageCamera()
    bullet = nil
    cooldownLeft = 0
    timeScale = 1
    impactDone = false
    pendingAdvance = false
    woundSparks = {}
    message = "40 ft · .22 LR HV 40gr · " .. string.format("%.0f fps / %.0f ft·lbf", stage.snap.impactFps, stage.snap.impactFtlb)
    messageTimer = 3
end

function advanceStage(manual)
    local ok, snap = Stages.advance(stage)
    if ok then
        applyStageCamera()
        message = snap.label .. " · " .. string.format("%.0f fps / %.0f ft·lbf", snap.impactFps, snap.impactFtlb)
        messageTimer = 2.8
    elseif manual then
        message = "Final stage (house wall) — RESET to restart ranges"
        messageTimer = 2
    end
    pendingAdvance = false
end

function tryFire(sx, sy)
    if not Ballistics.canFire(cooldownLeft) then
        message = string.format("Chambering… %.1fs", cooldownLeft)
        messageTimer = 1.2
        cooldownFlash = 0.35
        return false
    end
    if cam.mode ~= "aim" and cam.mode ~= "impact" then
        if (cam.hold or 0) > 0 then
            return false
        end
    end
    local snap = stage.snap
    Camera.setAim(cam, meta.bodyCenter, snap.rangeFeet)
    local origin, dir = Camera.lookRay(cam, sx, sy, WIDTH, HEIGHT)
    local spawnPos = Vec3.add(origin, Vec3.scale(dir, 0.35))
    local cineSpeed = TwentyTwo.cinematicSpeed(snap.impactFps)
    bullet = Ballistics.spawn(spawnPos, dir, cineSpeed, {
        realFps = snap.impactFps,
        realFtlb = snap.impactFtlb,
        grain = snap.grain,
        caliber = snap.caliber,
        throughWall = snap.throughWall,
        stageLabel = snap.label,
    })
    cam.cine = {}
    cam.impactComplete = false
    cooldownLeft = Ballistics.COOLDOWN
    impactDone = false
    pendingAdvance = false
    Stages.onShotFired(stage)
    if snap.throughWall then
        message = string.format("Through wall · pre %.0f fps → impact %.0f fps", snap.preWallFps, snap.impactFps)
    else
        message = string.format(".22 LR @ %dft · %.0f fps · %.0f ft·lbf", snap.rangeFeet, snap.impactFps, snap.impactFtlb)
    end
    messageTimer = 1.6
    return true
end

function touched(touch)
    local state = touch.state
    local x, y = touch.x, touch.y

    if insideBtn(resetBtn, x, y) then
        if state == ENDED then
            resetScene()
        end
        return
    end
    if insideBtn(nextBtn, x, y) then
        if state == ENDED then
            advanceStage(true)
        end
        return
    end

    if state == MOVING or state == BEGAN then
        if cam.mode == "aim" or not bullet then
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

function insideBtn(b, x, y)
    return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

function insideReset(x, y)
    return insideBtn(resetBtn, x, y)
end

function keyboard(key)
    if key == "r" or key == "R" then
        resetScene()
    elseif key == "n" or key == "N" then
        advanceStage(true)
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
    local hb = Organs.heartbeatScale(organState)
    -- Gentle heartbeat pulse on heart organ nodes
    for _, org in ipairs(meta.organs) do
        if org.name == "heart" then
            for _, id in ipairs(org.ids) do
                local n = body.nodes[id]
                if n and n.ox then
                    local k = (hb - 1) * 0.15
                    n.x = n.ox + (n.x - n.ox) * 0.9
                    n.y = n.oy + (n.y - n.oy) * 0.9 + k * 0.02
                end
            end
        end
    end
    Organs.step(organState, dt * timeScale)

    if bullet and (bullet.alive or not impactDone) then
        local phase
        phase, timeScale = Camera.updateCinematic(cam, bullet, bodyCenter, impactDone, dt)
        if bullet.alive then
            -- Wall perforation FX (energy already reduced in stage snapshot)
            if bullet.throughWall and not bullet.wallHit and bullet.pos.z <= wallZ then
                bullet.wallHit = true
                wallBroken = true
                for _ = 1, 18 do
                    wallDebris[#wallDebris + 1] = {
                        x = bullet.pos.x + (math.random() - 0.5) * 0.4,
                        y = bullet.pos.y + (math.random() - 0.5) * 0.6,
                        z = wallZ,
                        vx = (math.random() - 0.5) * 2,
                        vy = math.random() * 1.5,
                        vz = -1 - math.random(),
                        life = 0.8 + math.random() * 0.5,
                        wood = math.random() > 0.45,
                    }
                end
            end
            Ballistics.integrate(bullet, dt * timeScale)
            local hitIdx = Ballistics.hitNodeIndex(bullet, body.nodes, 0.22)
            if hitIdx then
                local n = body.nodes[hitIdx]
                local hitPos = Vec3.new(n.x, n.y, n.z)
                local realFtlb = bullet.realFtlb or stage.snap.impactFtlb
                local realFps = bullet.realFps or stage.snap.impactFps
                -- Map real ft·lbf into soft-body KE scale + tissue radius
                local ke = (realFtlb / 140) * 0.012 * GoreIntensity
                local cavity = TwentyTwo.tempCavityScale(realFps)
                local radius = (0.42 + cavity) * GoreIntensity
                local torn, _, fractured = SoftBody.applyBulletImpact(
                    body, hitPos, bullet.vel, ke, radius, realFtlb * GoreIntensity
                )
                local organName, odist = Organs.nearestOrgan(meta.organs, hitPos)
                local quality = Organs.hitQualityFromDistance(odist, 0.32)
                local boneBlocked = n.kind == "bone" and (n.boneType == "skull" or n.boneType == "rib")
                local fluid = "blood"
                if organName then
                    Organs.applyHit(organState, organName, realFtlb, quality, boneBlocked)
                    fluid = (Organs.DEFS[organName] and Organs.DEFS[organName].fluid) or "blood"
                    -- Also damage nearby organs slightly (crush path)
                    for _, org in ipairs(meta.organs) do
                        if org.name ~= organName then
                            local d = Vec3.dist(hitPos, Vec3.new(org.cx, org.cy, org.cz))
                            if d < 0.35 then
                                Organs.applyHit(organState, org.name, realFtlb * 0.35, Organs.hitQualityFromDistance(d, 0.35), false)
                            end
                        end
                    end
                end
                Blood.ruptureNear(blood, body, torn, bullet.vel)
                Blood.gushAt(blood, hitPos, bullet.vel, math.floor(10 + realFtlb / 12), fluid)
                if fluid ~= "blood" then
                    Blood.gushAt(blood, hitPos, bullet.vel, 6, "blood")
                end
                Ballistics.markHit(bullet, hitPos, Vec3.normalize(bullet.vel))
                impactDone = true
                pendingAdvance = AutoAdvance
                Camera.setImpact(cam, hitPos, bodyCenter)
                local hitLabel = organName and (Organs.DEFS[organName].label or organName) or (n.kind or "tissue")
                local boneNote = ""
                if fractured and #fractured > 0 then
                    boneNote = " · bone fracture"
                end
                message = string.format(
                    "Hit %s · %.0f ft·lbf @ %.0f fps%s",
                    hitLabel, realFtlb, realFps, boneNote
                )
                messageTimer = 2.5
                for _ = 1, 12 do
                    woundSparks[#woundSparks + 1] = {
                        x = hitPos.x, y = hitPos.y, z = hitPos.z,
                        vx = (math.random() - 0.5) * 2,
                        vy = math.random() * 2,
                        vz = (math.random() - 0.5) * 2 - 1,
                        life = 0.6 + math.random() * 0.5,
                    }
                end
            elseif bullet.age > 8 or bullet.pos.y < -3 or Vec3.dist(bullet.pos, bodyCenter) > 16 then
                bullet.alive = false
                impactDone = true
                Camera.setAim(cam, bodyCenter, stage.snap.rangeFeet)
                message = "Miss — double-tap to fire again"
                messageTimer = 2
            end
        end
    else
        timeScale = 1
        if cam.mode == "impact" then
            cam.hold = (cam.hold or 0) - dt
            if cam.hold <= 0 then
                cam.impactComplete = true
                Camera.setAim(cam, bodyCenter, stage.snap.rangeFeet)
                if pendingAdvance then
                    advanceStage(false)
                end
            end
        elseif cam.mode ~= "aim" and (not bullet or impactDone) and (cam.hold or 0) <= 0 then
            Camera.setAim(cam, bodyCenter, stage.snap.rangeFeet)
        end
    end

    local tore = SoftBody.step(body, dt, timeScale)
    if #tore > 0 and bullet and bullet.hitPos then
        Blood.ruptureNear(blood, body, tore, bullet.vel or Vec3.new(0, 0, -1))
    end
    -- Sync blood pump rate to heart
    if blood then
        blood.pumpT = (blood.pumpT or 0)
        -- Organs.step already advanced vitals; Blood.step adds its own pumpT
    end
    if ShowBlood then
        Blood.step(blood, dt, timeScale * (0.85 + 0.3 * (organState.vitals.cardiacOutput or 1)), body.nodes)
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
    for i = #wallDebris, 1, -1 do
        local s = wallDebris[i]
        s.life = s.life - dt
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        s.z = s.z + s.vz * dt
        s.vy = s.vy - 8 * dt
        if s.life <= 0 then
            table.remove(wallDebris, i)
        end
    end
end

function drawWorld()
    background(18, 16, 20)
    drawFloorGrid()
    if stage and stage.snap.throughWall then
        drawHouseWall()
    end

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

    strokeWidth(0)
    for _, tri in ipairs(body.triangles) do
        local a, b, c = body.nodes[tri.i], body.nodes[tri.j], body.nodes[tri.k]
        local sx1, sy1, d1, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
        local sx2, sy2, d2, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
        local sx3, sy3, d3, v3 = Camera.project(cam, c, WIDTH, HEIGHT)
        if v1 and v2 and v3 then
            local wet = (a.wet + b.wet + c.wet) / 3
            fill(170 + wet * 50, 90 - wet * 40, 80 - wet * 30, 55 + wet * 40)
            triangle(sx1, sy1, sx2, sy2, sx3, sy3)
        end
    end

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

    if ShowOrgans then
        noStroke()
        local hb = Organs.heartbeatScale(organState)
        for _, org in ipairs(meta.organs) do
            local integ = organState.integrity[org.name] or 1
            for _, id in ipairs(org.ids) do
                local n = body.nodes[id]
                local sx, sy, depth, vis = Camera.project(cam, n, WIDTH, HEIGHT)
                if vis then
                    local r = (7 + 40 / depth) * (org.name == "heart" and hb or 1)
                    local alpha = 100 + integ * 100
                    fill(org.rgb[1] * 255, org.rgb[2] * 255, org.rgb[3] * 255, alpha)
                    ellipse(sx, sy, r * 2, r * 2)
                end
            end
        end
    end

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

    if ShowBlood then
        noStroke()
        for _, p in ipairs(blood.particles) do
            local sx, sy, depth, vis = Camera.project(cam, p, WIDTH, HEIGHT)
            if vis then
                local r = (p.r or 0.04) * (220 / math.max(0.4, depth))
                local a = p.free and (200 * math.max(0.2, p.life)) or 160
                local cr, cg, cb = Organs.fluidColor(p.fluid or "blood")
                fill(cr, cg, cb, a)
                ellipse(sx, sy, r * 2.4, r * 2.4)
            end
        end
    end

    noStroke()
    for _, s in ipairs(woundSparks) do
        local sx, sy, _, vis = Camera.project(cam, s, WIDTH, HEIGHT)
        if vis then
            fill(160, 40, 40, 200 * s.life)
            ellipse(sx, sy, 5, 5)
        end
    end
    for _, s in ipairs(wallDebris) do
        local sx, sy, _, vis = Camera.project(cam, s, WIDTH, HEIGHT)
        if vis then
            if s.wood then
                fill(120, 85, 45, 220 * s.life)
            else
                fill(220, 220, 210, 200 * s.life)
            end
            ellipse(sx, sy, 6, 6)
        end
    end

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

function drawHouseWall()
    -- Two drywall sheets + wood studs (schematic in 3D)
    local z1, z2 = wallZ + 0.08, wallZ - 0.08
    local corners = {
        { -1.2, -0.4, z1 }, { 1.2, -0.4, z1 }, { 1.2, 1.6, z1 }, { -1.2, 1.6, z1 },
    }
    local pts = {}
    local allVis = true
    for i, c in ipairs(corners) do
        local sx, sy, _, vis = Camera.project(cam, Vec3.new(c[1], c[2], c[3]), WIDTH, HEIGHT)
        pts[i] = { x = sx, y = sy }
        if not vis then allVis = false end
    end
    if allVis then
        local alpha = wallBroken and 70 or 140
        fill(210, 205, 195, alpha)
        noStroke()
        triangle(pts[1].x, pts[1].y, pts[2].x, pts[2].y, pts[3].x, pts[3].y)
        triangle(pts[1].x, pts[1].y, pts[3].x, pts[3].y, pts[4].x, pts[4].y)
        -- Studs
        stroke(110, 75, 40, 180)
        strokeWidth(3)
        for sx = -0.8, 0.8, 0.4 do
            local a = Vec3.new(sx, -0.3, wallZ)
            local b = Vec3.new(sx, 1.5, wallZ)
            local x1, y1, _, v1 = Camera.project(cam, a, WIDTH, HEIGHT)
            local x2, y2, _, v2 = Camera.project(cam, b, WIDTH, HEIGHT)
            if v1 and v2 then
                line(x1, y1, x2, y2)
            end
        end
        if wallBroken then
            stroke(40, 40, 40, 200)
            strokeWidth(2)
            local hx, hy = Camera.project(cam, Vec3.new(0, 0.5, wallZ), WIDTH, HEIGHT)
            line(hx - 18, hy - 10, hx + 16, hy + 12)
            line(hx - 12, hy + 14, hx + 20, hy - 8)
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

    resetBtn.x = WIDTH - 160
    resetBtn.y = HEIGHT - 70
    resetBtn.w = 140
    resetBtn.h = 48
    nextBtn.x = WIDTH - 160
    nextBtn.y = HEIGHT - 130
    nextBtn.w = 140
    nextBtn.h = 48
    noStroke()
    fill(50, 48, 58, 220)
    rect(resetBtn.x, resetBtn.y, resetBtn.w, resetBtn.h)
    fill(60, 70, 90, 220)
    rect(nextBtn.x, nextBtn.y, nextBtn.w, nextBtn.h)
    fill(230, 230, 235)
    fontSize(18)
    textAlign(CENTER)
    textMode(CENTER)
    text("RESET", resetBtn.x + resetBtn.w * 0.5, resetBtn.y + resetBtn.h * 0.5)
    text("NEXT", nextBtn.x + nextBtn.w * 0.5, nextBtn.y + nextBtn.h * 0.5)

    local cx, cy = 90, HEIGHT - 46
    fill(35, 34, 42, 220)
    rect(20, HEIGHT - 72, 150, 52)
    local ready = Ballistics.canFire(cooldownLeft)
    if ready then
        fill(80, 200, 110, 230)
        text("READY", cx, cy)
    else
        fill(220, 90, 70, 230)
        text(string.format("%.1fs", cooldownLeft), cx, cy)
        local w = 120 * (1 - cooldownLeft / Ballistics.COOLDOWN)
        fill(200, 70, 60, 180)
        rect(30, HEIGHT - 28, w, 6)
    end
    if cooldownFlash > 0 then
        fill(255, 80, 80, 80 * cooldownFlash / 0.35)
        rect(0, 0, WIDTH, HEIGHT)
    end

    -- Stage + ballistics card
    fill(20, 22, 28, 210)
    rect(20, 70, 360, 78)
    fill(230, 230, 240)
    fontSize(13)
    textAlign(LEFT)
    textMode(CORNER)
    local snap = stage.snap
    text(string.format("STAGE %d/%d  %s", snap.index, snap.maxIndex, snap.label), 30, 88)
    text(string.format(".22 LR %dgr  %.0f fps  %.0f ft·lbf  (%.0f J)",
        snap.grain, snap.impactFps, snap.impactFtlb, snap.impactJoules), 30, 108)
    if snap.throughWall then
        fill(220, 180, 120)
        text(string.format("Barrier −%.0f fps  (pre-wall %.0f fps)", snap.wallDeltaFps, snap.preWallFps), 30, 128)
    else
        fill(160, 200, 160)
        text("Open air · HV Thunderbolt-class reference", 30, 128)
    end

    -- Vitals
    fill(20, 22, 28, 210)
    rect(20, 158, 360, 72)
    fill(200, 220, 255)
    fontSize(12)
    text(Organs.summaryLine(organState), 30, 178)
    local v = organState.vitals
    -- Heartbeat bar
    local pulse = 0.5 + 0.5 * math.max(0, math.sin(v.pulseWave))
    fill(200, 50, 60, 180)
    rect(30, 198, 200 * pulse * (organState.integrity.heart or 1), 10)
    fill(180, 180, 190)
    text(string.format("Heart integ %.0f%%  Brain %.0f%%  Cardiac out %.0f%%",
        (organState.integrity.heart or 1) * 100,
        (organState.integrity.brain or 1) * 100,
        v.cardiacOutput * 100), 30, 220)

    fill(255, 255, 255, 160)
    fontSize(14)
    local modeLabel = string.upper(cam.mode or "aim")
    text(modeLabel .. string.format("  ·  x%.2f  ·  %dft", timeScale, snap.rangeFeet), 24, 28)
    text("Anatomy Ballistics " .. APP_VERSION, 24, 48)

    if messageTimer > 0 then
        fill(255, 240, 240, 220)
        fontSize(15)
        textAlign(CENTER)
        textMode(CENTER)
        text(message, WIDTH * 0.5, 36)
    end

    textAlign(CENTER)
    textMode(CENTER)
    fontSize(15)
    if cam.mode == "side_trail" then
        fill(255, 80, 80, 200)
        text("BULLET TRAIL", WIDTH * 0.5, HEIGHT - 36)
    elseif cam.mode == "overhead" then
        fill(200, 220, 255, 200)
        text("OVERHEAD CONTACT", WIDTH * 0.5, HEIGHT - 36)
    elseif cam.mode == "follow_slow" then
        fill(255, 220, 120, 200)
        text("SLOW-MO FOLLOW", WIDTH * 0.5, HEIGHT - 36)
    end
end
