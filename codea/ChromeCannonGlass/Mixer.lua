-- Mixer.lua
-- Fruity Loops–style volume bus: Master plus per-channel faders (unity = 0.8).

Mixer = {}
Mixer.UNITY = 0.8
Mixer.MAX = 1.25
Mixer.CHANNELS = { "input", "output", "fire", "hit", "glass" }
Mixer.STRIPS = { "input", "output", "fire", "hit", "glass", "master" }
Mixer.PAGES = { "play", "settings", "mixer" }
Mixer.SETTINGS_TABS = { "input", "output" }

function Mixer.isPage(id)
    for _, p in ipairs(Mixer.PAGES) do
        if p == id then return true end
    end
    return false
end

function Mixer.isSettingsTab(id)
    return id == "input" or id == "output"
end

-- Legacy saves stored uiPage as "input" / "output"; those are now settings tabs.
function Mixer.normalizePage(page, tab)
    if page == "input" or page == "output" then
        return "settings", page
    end
    local p = Mixer.isPage(page) and page or "play"
    local t = Mixer.isSettingsTab(tab) and tab or "input"
    return p, t
end

function Mixer.defaults()
    return {
        master = Mixer.UNITY,
        input = Mixer.UNITY,
        output = Mixer.UNITY,
        fire = Mixer.UNITY,
        hit = Mixer.UNITY,
        glass = Mixer.UNITY,
    }
end

function Mixer.clamp(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > Mixer.MAX then return Mixer.MAX end
    return v
end

function Mixer.copy(vols)
    local o = Mixer.defaults()
    if type(vols) ~= "table" then return o end
    for _, k in ipairs(Mixer.STRIPS) do
        if vols[k] ~= nil then
            o[k] = Mixer.clamp(vols[k])
        end
    end
    return o
end

-- Channel level after Master. Unity master leaves the channel unchanged.
function Mixer.effective(channel, vols)
    vols = vols or Mixer.defaults()
    local master = Mixer.clamp(vols.master or Mixer.UNITY)
    if channel == "master" then
        return master
    end
    local ch = Mixer.clamp(vols[channel] or Mixer.UNITY)
    return master * ch / Mixer.UNITY
end

-- Map mixer faders onto the game's InputGain / OutputVolume (unity → 1.0).
function Mixer.toGain(channel, vols)
    return Mixer.effective(channel, vols) / Mixer.UNITY
end

function Mixer.fromGain(gain)
    return Mixer.clamp((tonumber(gain) or 1) * Mixer.UNITY)
end

-- Set every strip, including Master, to the same level (FL "all volumes").
function Mixer.setAll(vols, value)
    value = Mixer.clamp(value)
    vols = vols or Mixer.defaults()
    for _, k in ipairs(Mixer.STRIPS) do
        vols[k] = value
    end
    return vols
end

function Mixer.anyChanged(prev, now, epsilon)
    epsilon = epsilon or 0.008
    prev = prev or {}
    now = now or {}
    for _, k in ipairs(Mixer.STRIPS) do
        local a = prev[k] or 0
        local b = now[k] or 0
        if math.abs(a - b) > epsilon then
            return true, k
        end
    end
    return false, nil
end

-- Fader y → volume. y0 is bottom of travel, y1 is top.
function Mixer.volumeFromFaderY(y, y0, y1)
    if y1 == y0 then return 0 end
    local t = (y - y0) / (y1 - y0)
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    return Mixer.clamp(t * Mixer.MAX)
end

function Mixer.faderYFromVolume(vol, y0, y1)
    local t = Mixer.clamp(vol) / Mixer.MAX
    return y0 + t * (y1 - y0)
end

-- Rotary knobs: -135° (min) … +135° (max), 270° twist like FL / hardware pots.
Mixer.KNOB_MIN = -2.356194490192345  -- -135°
Mixer.KNOB_MAX = 2.356194490192345   -- +135°

function Mixer.knobAngleFromVolume(vol)
    local t = Mixer.clamp(vol) / Mixer.MAX
    return Mixer.KNOB_MIN + t * (Mixer.KNOB_MAX - Mixer.KNOB_MIN)
end

function Mixer.volumeFromKnobAngle(ang)
    local span = Mixer.KNOB_MAX - Mixer.KNOB_MIN
    local t = ((ang or 0) - Mixer.KNOB_MIN) / span
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    return Mixer.clamp(t * Mixer.MAX)
end

-- Apply a twist: shortest signed delta between two atan2 angles.
function Mixer.twistVolume(vol, prevAng, newAng)
    local d = (newAng or 0) - (prevAng or 0)
    while d > math.pi do d = d - 2 * math.pi end
    while d < -math.pi do d = d + 2 * math.pi end
    local span = Mixer.KNOB_MAX - Mixer.KNOB_MIN
    return Mixer.clamp((vol or 0) + d / span * Mixer.MAX)
end

function Mixer.hitKnob(px, py, knob)
    if not knob then return false end
    local dx = px - knob.x
    local dy = py - knob.y
    local r = (knob.r or 36) + 10
    return dx * dx + dy * dy <= r * r
end

function Mixer.stripLabel(id)
    local names = {
        master = "MASTER",
        input = "IN",
        output = "OUT",
        fire = "FIRE",
        hit = "HIT",
        glass = "GLASS",
    }
    return names[id] or string.upper(tostring(id))
end

-- Mic lamp: flash on transients, remain red while audio holds.
-- Returns hold, lit, height 0–1, mode "off"|"flash"|"hold".
function Mixer.micLamp(level, hold, dt, floor)
    floor = floor or 0.03
    dt = math.max(0, dt or 0.016)
    level = math.max(0, level or 0)
    hold = math.max(0, hold or 0)
    if level >= floor then
        hold = math.max(hold, 0.28)
    else
        hold = math.max(0, hold - dt)
    end
    local lit = hold > 0
    local height = math.min(1, level)
    local mode = "off"
    if lit then
        if level >= floor * 2.5 then
            mode = "hold"
        else
            mode = "flash"
        end
    end
    return hold, lit, height, mode
end

-- Map a 0–1 audio level to a pixel column height.
function Mixer.volumeHeight(level, maxH)
    maxH = maxH or 1
    local t = math.min(1, math.max(0, level or 0))
    return t * maxH
end

-- HSV → r,g,b in 0–255. Hue in degrees.
function Mixer.hsv(h, s, v)
    h = (h or 0) % 360
    if h < 0 then h = h + 360 end
    s = math.min(1, math.max(0, s or 1))
    v = math.min(1, math.max(0, v or 1))
    local c = v * s
    local hp = h / 60
    local x = c * (1 - math.abs(hp % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    if hp < 1 then
        r, g, b = c, x, 0
    elseif hp < 2 then
        r, g, b = x, c, 0
    elseif hp < 3 then
        r, g, b = 0, c, x
    elseif hp < 4 then
        r, g, b = 0, x, c
    elseif hp < 5 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    return (r + m) * 255, (g + m) * 255, (b + m) * 255
end

-- Neon bulb hue: bright blue → pink → red → blue (all hues on that arc).
-- Speed is rad/s of the sine; 0.2 ≈ 31s per full tube cycle (was 1.35 ≈ 4.7s).
Mixer.NEON_SPEED = 0.2

function Mixer.neonHue(elapsed, speed)
    elapsed = elapsed or 0
    speed = speed or Mixer.NEON_SPEED or 0.2
    local wave = 0.5 + 0.5 * math.sin(elapsed * speed)
    return 205 + 155 * wave
end

function Mixer.neonRGB(elapsed, value)
    local h = Mixer.neonHue(elapsed)
    return Mixer.hsv(h, 1, value or 1)
end
