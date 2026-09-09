-- CameraOrbit.lua
-- Touch-drag orbit (360°) + zoom for Craft camera.

CameraOrbit = {}

function CameraOrbit.new(cam, opts)
    opts = opts or {}
    local rig = {
        cam = cam,
        target = opts.target or vec3(0, 2, 0),
        yaw = opts.yaw or 35,
        pitch = opts.pitch or 28,
        distance = opts.distance or opts.dist or 18,
        minDist = opts.minDist or 6,
        maxDist = opts.maxDist or 42,
        dragging = false,
        last = nil,
    }
    CameraOrbit.apply(rig)
    return rig
end

-- Legacy alias
function CameraOrbit.make(cam, target)
    return CameraOrbit.new(cam, { target = target })
end

function CameraOrbit.apply(rig)
    local yaw = math.rad(rig.yaw)
    local pitch = math.rad(math.max(-80, math.min(80, rig.pitch)))
    local x = rig.target.x + rig.distance * math.cos(pitch) * math.sin(yaw)
    local y = rig.target.y + rig.distance * math.sin(pitch)
    local z = rig.target.z + rig.distance * math.cos(pitch) * math.cos(yaw)
    rig.cam.x, rig.cam.y, rig.cam.z = x, y, z
    if rig.cam.eulerAngles then
        rig.cam.eulerAngles = vec3(rig.pitch, rig.yaw, 0)
    end
    if rig.cam.entity and rig.cam.entity.lookAt then
        rig.cam.entity:lookAt(rig.target)
    end
end

function CameraOrbit.update(rig, dt)
    -- reserved for inertia; apply keeps Craft cam in sync
    CameraOrbit.apply(rig)
end

function CameraOrbit.focus(rig, target)
    rig.target = target
    CameraOrbit.apply(rig)
end

function CameraOrbit.setDistance(rig, d)
    rig.distance = math.max(rig.minDist, math.min(rig.maxDist, d))
    CameraOrbit.apply(rig)
end

function CameraOrbit.zoom(rig, delta)
    CameraOrbit.setDistance(rig, rig.distance + delta)
end

function CameraOrbit.pullExterior(rig, bounds)
    local h = (bounds and bounds.h) or 6
    local w = (bounds and bounds.w) or 8
    CameraOrbit.focus(rig, vec3(0, h * 0.45, 0))
    rig.yaw = 40
    rig.pitch = 22
    CameraOrbit.setDistance(rig, math.max(12, 10 + h * 1.3 + w * 0.4))
end

function CameraOrbit.touchBegan(rig, touch)
    rig.dragging = true
    rig.last = vec2(touch.x, touch.y)
end

function CameraOrbit.touchMoved(rig, touch)
    if not rig.dragging or not rig.last then return end
    local dx = touch.x - rig.last.x
    local dy = touch.y - rig.last.y
    rig.yaw = rig.yaw - dx * 0.25
    rig.pitch = math.max(-80, math.min(80, rig.pitch + dy * 0.2))
    rig.last = vec2(touch.x, touch.y)
    CameraOrbit.apply(rig)
end

function CameraOrbit.touchEnded(rig, touch)
    rig.dragging = false
    rig.last = nil
end
