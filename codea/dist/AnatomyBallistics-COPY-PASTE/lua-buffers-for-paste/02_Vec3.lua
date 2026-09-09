-- Vec3.lua
-- Tiny 3D vector helpers (pure Lua; smoke-testable outside Codea).

Vec3 = {}

function Vec3.new(x, y, z)
    return { x = x or 0, y = y or 0, z = z or 0 }
end

function Vec3.copy(v)
    return { x = v.x, y = v.y, z = v.z }
end

function Vec3.add(a, b)
    return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

function Vec3.sub(a, b)
    return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

function Vec3.scale(a, s)
    return { x = a.x * s, y = a.y * s, z = a.z * s }
end

function Vec3.dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

function Vec3.cross(a, b)
    return {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x,
    }
end

function Vec3.length(a)
    return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end

function Vec3.length2(a)
    return a.x * a.x + a.y * a.y + a.z * a.z
end

function Vec3.normalize(a)
    local len = Vec3.length(a)
    if len < 1e-8 then
        return { x = 0, y = 0, z = 0 }
    end
    return { x = a.x / len, y = a.y / len, z = a.z / len }
end

function Vec3.lerp(a, b, t)
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = a.z + (b.z - a.z) * t,
    }
end

function Vec3.dist(a, b)
    return Vec3.length(Vec3.sub(a, b))
end

function Vec3.atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    return math.atan(y, x)
end
