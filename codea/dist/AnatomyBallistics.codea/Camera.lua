-- Camera.lua
-- Perspective camera + cinematic shot modes for Anatomy Ballistics.

Camera = {}

function Camera.new()
    return {
        eye = Vec3.new(0, 0.4, 5.2),
        target = Vec3.new(0, 0.2, 0),
        up = Vec3.new(0, 1, 0),
        fov = 55,
        mode = "aim", -- aim | side_trail | overhead | follow_slow | impact
        hold = 0,
    }
end

function Camera.basis(cam)
    local forward = Vec3.normalize(Vec3.sub(cam.target, cam.eye))
    local right = Vec3.normalize(Vec3.cross(forward, cam.up))
    -- If degenerate, pick fallback
    if Vec3.length2(right) < 1e-8 then
        right = Vec3.new(1, 0, 0)
    end
    local up = Vec3.normalize(Vec3.cross(right, forward))
    return forward, right, up
end

-- Project world point to screen. Returns x, y, depth (positive in front), visible.
function Camera.project(cam, world, width, height)
    width = width or 1024
    height = height or 768
    local forward, right, up = Camera.basis(cam)
    local rel = Vec3.sub(world, cam.eye)
    local z = Vec3.dot(rel, forward)
    if z < 0.05 then
        return 0, 0, z, false
    end
    local x = Vec3.dot(rel, right)
    local y = Vec3.dot(rel, up)
    local focal = (height * 0.5) / math.tan(math.rad((cam.fov or 55) * 0.5))
    local sx = width * 0.5 + x * focal / z
    local sy = height * 0.5 + y * focal / z
    return sx, sy, z, true
end

function Camera.lookRay(cam, screenX, screenY, width, height)
    width = width or 1024
    height = height or 768
    local forward, right, up = Camera.basis(cam)
    local focal = (height * 0.5) / math.tan(math.rad((cam.fov or 55) * 0.5))
    local nx = (screenX - width * 0.5) / focal
    local ny = (screenY - height * 0.5) / focal
    local dir = Vec3.normalize(Vec3.add(Vec3.add(forward, Vec3.scale(right, nx)), Vec3.scale(up, ny)))
    return cam.eye, dir
end

function Camera.setAim(cam, bodyCenter)
    cam.mode = "aim"
    cam.eye = Vec3.new(0.15, 0.55, 7.8)
    cam.target = Vec3.copy(bodyCenter or Vec3.new(0, 0.2, 0))
    cam.fov = 48
    cam.hold = 0
end

function Camera.setSideTrail(cam, bullet, bodyCenter)
    cam.mode = "side_trail"
    local p = bullet and bullet.pos or bodyCenter
    cam.eye = Vec3.new(p.x + 4.8, p.y + 0.3, p.z)
    cam.target = Vec3.new(p.x, p.y, (bodyCenter and bodyCenter.z) or 0)
    cam.fov = 48
end

function Camera.setOverhead(cam, bullet, bodyCenter)
    cam.mode = "overhead"
    local p = bullet and bullet.pos or bodyCenter
    local c = bodyCenter or Vec3.new()
    local mid = Vec3.lerp(p, c, 0.45)
    cam.eye = Vec3.new(mid.x, math.max(c.y, mid.y) + 6.2, mid.z + 0.15)
    cam.target = Vec3.new(mid.x, c.y, mid.z)
    cam.up = Vec3.new(0, 0, -1)
    cam.fov = 55
end

function Camera.setFollowSlow(cam, bullet)
    cam.mode = "follow_slow"
    if not bullet then
        return
    end
    local back = Vec3.normalize(bullet.vel)
    -- Camera behind bullet looking forward
    cam.eye = Vec3.sub(bullet.pos, Vec3.scale(back, 1.35))
    cam.eye.y = cam.eye.y + 0.25
    cam.target = Vec3.add(bullet.pos, Vec3.scale(back, 2.5))
    cam.up = Vec3.new(0, 1, 0)
    cam.fov = 42
end

function Camera.setImpact(cam, hitPos, bodyCenter)
    cam.mode = "impact"
    local p = hitPos or bodyCenter or Vec3.new()
    cam.eye = Vec3.new(p.x - 0.4, p.y + 0.9, p.z + 2.2)
    cam.target = Vec3.copy(p)
    cam.up = Vec3.new(0, 1, 0)
    cam.fov = 45
    cam.hold = 1.4
    cam.impactComplete = false
end

function Camera.updateCinematic(cam, bullet, bodyCenter, impactDone, dt)
    cam.cine = cam.cine or {}
    if cam.impactComplete and impactDone then
        Camera.setAim(cam, bodyCenter)
        return "aim", 1
    end
    local phase = Ballistics.cinematicPhase(bullet, bodyCenter, impactDone, cam.cine, dt)
    if cam.mode == "impact" and (cam.hold or 0) > 0 then
        cam.hold = cam.hold - (dt or 0)
        if cam.hold <= 0 then
            cam.impactComplete = true
            Camera.setAim(cam, bodyCenter)
            cam.cine = {}
            return "aim", 1
        end
        return "impact", Ballistics.timeScaleForPhase("impact")
    end

    if phase == "side_trail" then
        cam.up = Vec3.new(0, 1, 0)
        Camera.setSideTrail(cam, bullet, bodyCenter)
    elseif phase == "overhead" then
        cam.up = Vec3.new(0, 0, -1)
        Camera.setOverhead(cam, bullet, bodyCenter)
    elseif phase == "follow_slow" then
        cam.up = Vec3.new(0, 1, 0)
        Camera.setFollowSlow(cam, bullet)
    elseif phase == "impact" then
        local hp = (bullet and bullet.hitPos) or bodyCenter
        Camera.setImpact(cam, hp, bodyCenter)
        cam.cine = {}
    else
        cam.up = Vec3.new(0, 1, 0)
        Camera.setAim(cam, bodyCenter)
        cam.cine = {}
    end
    return phase, Ballistics.timeScaleForPhase(phase)
end

function Camera.mathRad(deg)
    return (deg or 0) * math.pi / 180
end

-- Polyfill if Codea math.rad missing in headless tests
if not math.rad then
    function math.rad(d)
        return d * math.pi / 180
    end
end
