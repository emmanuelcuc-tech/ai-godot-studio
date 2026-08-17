-- Headless smoke test for Chrome Cannon Glass math helpers.
-- Run: lua5.4 codea/ChromeCannonGlass/tests/smoke_test.lua

package.path = package.path .. ";./codea/ChromeCannonGlass/?.lua;../?.lua"

local here = (arg and arg[0] and arg[0]:match("(.*/)") or "./")
dofile(here .. "../Glass.lua")

local fails = 0
local function check(name, cond, detail)
    if cond then
        print("OK  " .. name)
    else
        fails = fails + 1
        print("FAIL " .. name .. (detail and (" — " .. detail) or ""))
    end
end

-- Kinetic energy
check("KE of rest is 0", Glass.kineticEnergy(2, 0) == 0)
check("KE formula 1/2 m v^2", math.abs(Glass.kineticEnergy(2, 10) - 100) < 1e-9)
check("speed from velocity", math.abs(Glass.speedFromVelocity(3, 4) - 5) < 1e-9)
check("circle mass positive", Glass.circleMass(2.2, 16) > 1000)

-- Energy loss after shatter
local m = 10
local v0 = 100
local ke0 = Glass.kineticEnergy(m, v0)
local v1 = Glass.speedAfterEnergyLoss(m, v0, ke0 * 0.5)
check("speed drops after energy loss", v1 < v0 and v1 > 0)
check("half KE => speed / sqrt(2)", math.abs(v1 - v0 / math.sqrt(2)) < 1e-6)

-- Shatter threshold
check("shatter when KE high", Glass.shouldShatter(200000, 180000, 1) == true)
check("no shatter when KE low", Glass.shouldShatter(1000, 180000, 1) == false)

-- Five panes spaced apart
local xs = Glass.panePositions(5, 200, 115)
check("five panes", #xs == 5)
check("first pane x", xs[1] == 200)
check("spacing", xs[2] - xs[1] == 115 and xs[5] - xs[4] == 115)
check("last pane far from first", xs[5] - xs[1] == 460)

-- Shard velocities
local shards = Glass.shardVelocities(14, 800, 50, 50000, 0.08)
check("shard count", #shards == 14)
check("shards have outward motion", shards[1].vx ~= 0 or shards[1].vy ~= 0)

-- Slow-mo corridor
check("ready = full speed", Glass.slowMoFactor(100, 200, 600, false, 0, 5) == 1)
check("in corridor = slow", Glass.slowMoFactor(300, 200, 600, true, 0, 5) < 0.35)
check("past corridor = full", Glass.slowMoFactor(800, 200, 600, true, 5, 5) == 1)

-- Cannon muzzle / velocity
local mx, my = Glass.cannonMuzzle(0, 0, 0, 78)
check("muzzle along +x", math.abs(mx - 78) < 1e-9 and math.abs(my) < 1e-9)
local vx, vy = Glass.muzzleVelocity(0, 980)
check("muzzle vel right", math.abs(vx - 980) < 1e-9 and math.abs(vy) < 1e-9)

-- Screen-glass audio
local inn, outt = Glass.audioLevels(0.4, 2, 1, 0.8)
check("input = mic * gain", math.abs(inn - 0.8) < 1e-9)
check("output = peak * volume", math.abs(outt - 0.8) < 1e-9)
local loud, peak, src = Glass.isTooLoud(0.9, 0.2, 0.62)
check("too loud on input", loud == true and src == "input")
local quiet = Glass.isTooLoud(0.1, 0.1, 0.62)
check("quiet is not too loud", quiet == false)
check("tweak input resets", Glass.tweakChanged(1, 0.7, 1.5, 0.7) == true)
check("tweak output resets", Glass.tweakChanged(1, 0.7, 1, 1.2) == true)
check("no tweak when still", Glass.tweakChanged(1, 0.7, 1, 0.7) == false)

local tiles = Glass.screenTileGrid(8, 5, 800, 400)
check("screen grid 8x5", #tiles == 40)
check("first tile centered in cell", math.abs(tiles[1].x - 50) < 1e-6 and math.abs(tiles[1].y - 40) < 1e-6)
local bvx, bvy = Glass.screenBurstVelocity(800, 400, 400, 200, 1)
check("burst flies away from center", bvx > 0 and bvy > 0)

-- FL-style mixer
dofile(here .. "../Mixer.lua")
local vols = Mixer.defaults()
check("unity is 0.8", vols.master == 0.8 and vols.input == 0.8)
check("master effective is master", math.abs(Mixer.effective("master", vols) - 0.8) < 1e-9)
check("unity channel gain is 1", math.abs(Mixer.toGain("output", vols) - 1) < 1e-9)
local boosted = Mixer.copy(vols)
boosted.master = 1.0
check("master boosts all buses", Mixer.toGain("output", boosted) > Mixer.toGain("output", vols))
local all80 = Mixer.setAll(Mixer.copy(vols), 0.8)
check("set all includes master", all80.master == 0.8 and all80.fire == 0.8 and all80.glass == 0.8)
local changed, which = Mixer.anyChanged(vols, boosted)
check("mixer tweak detected", changed == true and which == "master")
check("no mixer tweak when still", Mixer.anyChanged(vols, Mixer.copy(vols)) == false)
local yvol = Mixer.volumeFromFaderY(100, 0, 100)
check("fader top is max", math.abs(yvol - Mixer.MAX) < 1e-9)

local a80 = Mixer.knobAngleFromVolume(0.8)
check("knob angle roundtrip", math.abs(Mixer.volumeFromKnobAngle(a80) - 0.8) < 1e-6)
local twisted = Mixer.twistVolume(0.8, 0, 0.4)
check("twist clockwise raises volume", twisted > 0.8)
local down = Mixer.twistVolume(0.8, 0.4, 0)
check("twist counter-clockwise lowers volume", down < 0.8)
check("knob hit inside", Mixer.hitKnob(10, 10, { x = 10, y = 10, r = 20 }) == true)
check("knob miss outside", Mixer.hitKnob(80, 10, { x = 10, y = 10, r = 20 }) == false)

local hold, lit, h, mode = Mixer.micLamp(0, 0, 0.016, 0.03)
check("mic lamp off when silent", lit == false and mode == "off")
hold, lit, h, mode = Mixer.micLamp(0.5, 0, 0.016, 0.03)
check("mic lamp holds red on loud audio", lit == true and mode == "hold" and h > 0.4)
hold, lit, h, mode = Mixer.micLamp(0.04, 0, 0.016, 0.03)
check("mic lamp flashes on light audio", lit == true and mode == "flash")
local hold2 = Mixer.micLamp(0, 0.2, 0.05, 0.03)
check("mic lamp remains after audio", hold2 > 0)
check("volume height scales", math.abs(Mixer.volumeHeight(0.5, 200) - 100) < 1e-9)
check("volume height silent is 0", Mixer.volumeHeight(0, 200) == 0)

local hr, hg, hb = Mixer.hsv(210, 1, 1)
check("hsv blue is blue-ish", hb > hr and hb > hg)
local rr, rg, rb = Mixer.hsv(0, 1, 1)
check("hsv red is red", rr > 200 and rg < 40 and rb < 40)
local h0 = Mixer.neonHue(0)
local h1 = Mixer.neonHue(math.pi / (2 * Mixer.NEON_SPEED))
check("neon speed is slow", Mixer.NEON_SPEED <= 0.25)
check("neon cycle lasts tens of seconds", (2 * math.pi / Mixer.NEON_SPEED) > 20)
check("neon hue in blue-pink-red arc", h0 >= 205 and h0 <= 360 and h1 >= 205 and h1 <= 360)
check("neon hue travels over a slow cycle", math.abs(h1 - h0) > 20)
local hSoon = Mixer.neonHue(0.5)
check("hue barely moves in half a second", math.abs(hSoon - h0) < 25)
check("settings is a page", Mixer.isPage("settings") == true)
check("play is a page", Mixer.isPage("play") == true)
check("unknown page rejected", Mixer.isPage("foo") == false)
check("settings tabs are input/output", Mixer.isSettingsTab("input") and Mixer.isSettingsTab("output"))
check("mixer is not a settings tab", Mixer.isSettingsTab("mixer") == false)
local np, nt = Mixer.normalizePage("input", nil)
check("legacy input page migrates to settings tab", np == "settings" and nt == "input")
np, nt = Mixer.normalizePage("output", "glass")
check("legacy output page migrates", np == "settings" and nt == "output")
np, nt = Mixer.normalizePage("settings", "output")
check("settings + output tab kept", np == "settings" and nt == "output")
np, nt = Mixer.normalizePage("mixer", "bogus")
check("bad tab defaults to input", np == "mixer" and nt == "input")

dofile(here .. "../GpuRam.lua")
check("gpu pool is tens of MB", GpuRam.megabytes(1024, 768) > 24)
check("gpu bytes scale with resolution", GpuRam.bytesEstimate(2048, 1536) > GpuRam.bytesEstimate(1024, 768))
check("leather atlas is 2x capped", (function()
    local sw, sh = GpuRam.leatherSize(1024, 768)
    return sw == 2048 and sh == 1536
end)())
local grain = GpuRam.buildGrain(100)
check("grain table fills RAM", #grain == 100 and grain[1].u >= 0 and grain[1].u <= 1)
GpuRam.boot(320, 240)
check("gpu boot records byte estimate", GpuRam.ready == true and GpuRam.bytes > 0)
check("default profile is high", GpuRam.profile == "high")
check("nil flag is high performance", GpuRam.isHigh(nil) == true)
check("zero flag is normal", GpuRam.isHigh(0) == false)
local hi = GpuRam.bytesEstimate(1024, 768)
GpuRam.applyProfile("normal")
local lo = GpuRam.bytesEstimate(1024, 768)
check("normal profile uses less vram", lo < hi)
GpuRam.applyProfile("high")
check("high profile restored", GpuRam.profile == "high")
check("high profile physics is heavier", GpuRam.physicsVel >= 20 and GpuRam.CHROME_STEPS >= 24)

if fails > 0 then
    print("\n" .. fails .. " failure(s)")
    os.exit(1)
end
print("\nAll smoke checks passed.")
