-- Headless smoke test for Metallic Labyrinth level data + hole logic.
-- Run: lua5.4 codea/MetallicLabyrinth/tests/smoke_test.lua

package.path = package.path .. ";./codea/MetallicLabyrinth/?.lua;../?.lua"

-- Minimal Codea stubs so Levels.lua loads cleanly
vec2 = function(x, y) return { x = x or 0, y = y or 0 } end

dofile((arg and arg[0] and arg[0]:match("(.*/)") or "./") .. "../Levels.lua")

local fails = 0
local function check(name, cond, detail)
    if cond then
        print("OK  " .. name)
    else
        fails = fails + 1
        print("FAIL " .. name .. (detail and (" — " .. detail) or ""))
    end
end

check("at least one level", Levels.count() >= 1)
check("four crafted mazes", Levels.count() == 4)

for i = 1, Levels.count() do
    local data, idx = Levels.get(i)
    check("level " .. i .. " index", idx == i)
    check("level " .. i .. " has name", type(data.name) == "string" and #data.name > 0)
    check("level " .. i .. " has map", type(data.map) == "table" and #data.map > 0)

    local width = #data.map[1]
    local starts, goals, traps = 0, 0, 0
    for r, line in ipairs(data.map) do
        check("level " .. i .. " row " .. r .. " width", #line == width, "got " .. #line)
        for c = 1, #line do
            local ch = line:sub(c, c)
            if ch == "S" then starts = starts + 1 end
            if ch == "G" then goals = goals + 1 end
            if ch == "T" then traps = traps + 1 end
        end
    end
    check("level " .. i .. " one start", starts == 1, "starts=" .. starts)
    check("level " .. i .. " one goal", goals == 1, "goals=" .. goals)
    check("level " .. i .. " has traps near goal", traps >= 1, "traps=" .. traps)

    -- Goal must share a row or neighboring cell with a trap (adjacency in map space)
    local gx, gy, near = 0, 0, false
    for r, line in ipairs(data.map) do
        for c = 1, #line do
            if line:sub(c, c) == "G" then gx, gy = c, r end
        end
    end
    for r = gy - 1, gy + 1 do
        for c = gx - 1, gx + 1 do
            if data.map[r] and c >= 1 and c <= #data.map[r] then
                if data.map[r]:sub(c, c) == "T" then near = true end
            end
        end
    end
    check("level " .. i .. " trap adjacent to goal", near)
end

-- Hole overlap math used by the game
local function dist(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local BALL_RADIUS = 14
local trap = { x = 100, y = 100, r = 18 }
local goal = { x = 140, y = 100, r = 20 }

check("ball falls in trap when centered",
    dist(100, 100, trap.x, trap.y) < trap.r - BALL_RADIUS * 0.25)
check("ball not in trap when far",
    not (dist(200, 200, trap.x, trap.y) < trap.r - BALL_RADIUS * 0.25))
check("ball wins when in goal cup",
    dist(140, 100, goal.x, goal.y) < goal.r - BALL_RADIUS * 0.35)
check("goal and trap are distinct positions",
    dist(goal.x, goal.y, trap.x, trap.y) > 1)

-- Wrap-around level index
local _, wrap = Levels.get(Levels.count() + 1)
check("level index wraps", wrap == 1)

if fails > 0 then
    print("\n" .. fails .. " failure(s)")
    os.exit(1)
end
print("\nAll smoke checks passed.")
