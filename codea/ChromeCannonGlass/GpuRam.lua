-- GpuRam.lua
-- Offscreen GPU textures + CPU grain tables so the project keeps a real
-- RAM / video-memory working set (leather atlas, bloom ping-pong, glow).

GpuRam = {}
GpuRam.LEATHER_MAX = 2048
GpuRam.BLOOM_SIZE = 1024
GpuRam.SCRATCH_COUNT = 4
GpuRam.GRAIN_COUNT = 10000
GpuRam.CHROME_STEPS = 24
GpuRam.ready = false
GpuRam.bytes = 0
GpuRam.width = 0
GpuRam.height = 0

function GpuRam.leatherSize(w, h)
    w = math.max(64, math.floor(w or 1024))
    h = math.max(64, math.floor(h or 768))
    local sw = math.min(GpuRam.LEATHER_MAX, w * 2)
    local sh = math.min(GpuRam.LEATHER_MAX, h * 2)
    return sw, sh
end

-- RGBA8 estimate of the texture pool (bytes). Used by tests and the HUD.
function GpuRam.bytesEstimate(w, h)
    local sw, sh = GpuRam.leatherSize(w, h)
    local leather = sw * sh * 4
    local bloom = GpuRam.BLOOM_SIZE * GpuRam.BLOOM_SIZE * 4 * 2
    local glow = math.max(64, math.floor(w or 1024)) * math.max(64, math.floor(h or 768)) * 4
    local scratch = GpuRam.BLOOM_SIZE * GpuRam.BLOOM_SIZE * 4 * GpuRam.SCRATCH_COUNT
    local grain = GpuRam.GRAIN_COUNT * 16
    return leather + bloom + glow + scratch + grain
end

function GpuRam.megabytes(w, h)
    return GpuRam.bytesEstimate(w, h) / (1024 * 1024)
end

function GpuRam.tryImage(w, h)
    if not image then
        return nil
    end
    local ok, img = pcall(image, w, h)
    if ok and img then
        return img
    end
    return nil
end

function GpuRam.buildGrain(count)
    count = count or GpuRam.GRAIN_COUNT
    local g = {}
    local a, b = 73, 47
    for i = 1, count do
        a = (a * 1103515245 + 12345) % 2147483648
        b = (b * 1664525 + 1013904223) % 2147483648
        g[i] = {
            u = (a % 10000) / 10000,
            v = (b % 10000) / 10000,
            s = 8 + (i % 9) * 2,
            shade = 10 + (i % 12),
        }
    end
    return g
end

function GpuRam.paintLeather(w, h, grain)
    background(5, 3, 4)
    noStroke()
    for i = 0, 48 do
        local gx = (i * 137 + 19) % (w + 80) - 40
        local gy = (i * 89 + 7) % (h + 60) - 30
        fill(12 + (i % 5), 8, 9, 70)
        ellipse(gx, gy, 220 - (i % 6) * 18, 110)
    end
    grain = grain or GpuRam.grain
    if grain then
        local n = #grain
        local step = 1
        if n > 2500 then
            step = math.floor(n / 2500)
        end
        for i = 1, n, step do
            local g = grain[i]
            local x = g.u * w
            local y = g.v * h
            fill(18, 12, 12, 40)
            ellipse(x, y, g.s + 6, g.s)
            fill(3, 1, 2, 50)
            ellipse(x + 3, y - 2, 7, 5)
        end
    else
        for i = 0, 90 do
            local x = (i * 73 + 11) % w
            local y = (i * 47 + 23) % h
            fill(18, 12, 12, 40)
            ellipse(x, y, 16 + (i % 6) * 3, 11 + (i % 4) * 2)
        end
    end
    fill(42, 30, 32, 18)
    ellipse(w * 0.38, h * 0.72, w * 0.85, h * 0.28)
    fill(28, 20, 22, 14)
    ellipse(w * 0.7, h * 0.25, w * 0.5, h * 0.2)
    stroke(32, 22, 20, 90)
    strokeWidth(1.2)
    line(14, 14, w - 14, 14)
    line(14, h - 14, w - 14, h - 14)
    line(14, 14, 14, h - 14)
    line(w - 14, 14, w - 14, h - 14)
    noStroke()
end

function GpuRam.paintBloom(size)
    background(0, 0, 0, 0)
    noStroke()
    fill(40, 28, 32, 40)
    ellipse(size * 0.5, size * 0.55, size * 0.9, size * 0.7)
    fill(22, 16, 18, 28)
    ellipse(size * 0.3, size * 0.3, size * 0.5, size * 0.4)
end

function GpuRam.bake()
    if not setContext then
        return
    end
    if GpuRam.leather then
        pcall(function()
            setContext(GpuRam.leather)
            GpuRam.paintLeather(GpuRam.leatherW, GpuRam.leatherH, GpuRam.grain)
            setContext()
        end)
    end
    if GpuRam.bloomA then
        pcall(function()
            setContext(GpuRam.bloomA)
            GpuRam.paintBloom(GpuRam.BLOOM_SIZE)
            setContext()
        end)
    end
    if GpuRam.bloomB then
        pcall(function()
            setContext(GpuRam.bloomB)
            GpuRam.paintBloom(GpuRam.BLOOM_SIZE)
            setContext()
        end)
    end
    if GpuRam.glow then
        pcall(function()
            setContext(GpuRam.glow)
            background(0, 0, 0, 0)
            setContext()
        end)
    end
    if GpuRam.scratch then
        for i = 1, #GpuRam.scratch do
            pcall(function()
                setContext(GpuRam.scratch[i])
                GpuRam.paintBloom(GpuRam.BLOOM_SIZE)
                setContext()
            end)
        end
    end
end

function GpuRam.boot(w, h)
    w = math.max(64, math.floor(w or 1024))
    h = math.max(64, math.floor(h or 768))
    GpuRam.width = w
    GpuRam.height = h
    GpuRam.grain = GpuRam.buildGrain(GpuRam.GRAIN_COUNT)
    local sw, sh = GpuRam.leatherSize(w, h)
    GpuRam.leatherW, GpuRam.leatherH = sw, sh
    GpuRam.leather = GpuRam.tryImage(sw, sh)
    GpuRam.bloomA = GpuRam.tryImage(GpuRam.BLOOM_SIZE, GpuRam.BLOOM_SIZE)
    GpuRam.bloomB = GpuRam.tryImage(GpuRam.BLOOM_SIZE, GpuRam.BLOOM_SIZE)
    GpuRam.glow = GpuRam.tryImage(w, h)
    GpuRam.scratch = {}
    for i = 1, GpuRam.SCRATCH_COUNT do
        GpuRam.scratch[i] = GpuRam.tryImage(GpuRam.BLOOM_SIZE, GpuRam.BLOOM_SIZE)
    end
    GpuRam.bake()
    GpuRam.bytes = GpuRam.bytesEstimate(w, h)
    GpuRam.ready = true
    return GpuRam.bytes
end

function GpuRam.ensure(w, h)
    w = math.floor(w or 0)
    h = math.floor(h or 0)
    if w < 64 or h < 64 then
        return
    end
    if (not GpuRam.ready) or GpuRam.width ~= w or GpuRam.height ~= h then
        GpuRam.boot(w, h)
    end
end

function GpuRam.drawCached()
    if not GpuRam.leather or not sprite then
        return false
    end
    spriteMode(CORNER)
    sprite(GpuRam.leather, 0, 0, WIDTH, HEIGHT)
    pcall(function()
        if GpuRam.bloomA then
            tint(255, 255, 255, 10)
            sprite(GpuRam.bloomA, 0, 0, WIDTH, HEIGHT)
            noTint()
        end
        if GpuRam.bloomB then
            tint(255, 255, 255, 8)
            sprite(GpuRam.bloomB, WIDTH * 0.08, HEIGHT * 0.06, WIDTH, HEIGHT)
            noTint()
        end
    end)
    return true
end
