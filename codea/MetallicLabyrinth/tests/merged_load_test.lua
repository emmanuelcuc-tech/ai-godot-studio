-- Load the packed single-file game and reuse maze + hole checks.
-- Run: lua5.4 codea/MetallicLabyrinth/tests/merged_load_test.lua

local here = arg and arg[0] and arg[0]:match("(.*/)") or "./"
local repo = here .. "../../../"
local packed = repo .. "codea/dist/MetallicLabyrinth.lua"

vec2 = function(x, y) return { x = x or 0, y = y or 0 } end
assert(loadfile(packed), "packed lua failed to parse: " .. packed)
dofile(packed)

local fails = 0
local function check(name, cond, detail)
    if cond then
        print("OK  " .. name)
    else
        fails = fails + 1
        print("FAIL " .. name .. (detail and (" — " .. detail) or ""))
    end
end

check("packed Levels table", type(Levels) == "table")
check("packed four mazes", Levels.count() == 4)
check("packed setup exists", type(setup) == "function")
check("packed draw exists", type(draw) == "function")
check("packed collide exists", type(collide) == "function")

for i = 1, Levels.count() do
    local data, idx = Levels.get(i)
    check("packed level " .. i .. " index", idx == i)
    local starts, goals, traps = 0, 0, 0
    local gx, gy, near = 0, 0, false
    for r, line in ipairs(data.map) do
        for c = 1, #line do
            local ch = line:sub(c, c)
            if ch == "S" then starts = starts + 1 end
            if ch == "G" then goals = goals + 1; gx, gy = c, r end
            if ch == "T" then traps = traps + 1 end
        end
    end
    check("packed level " .. i .. " start/goal/traps", starts == 1 and goals == 1 and traps >= 1,
        string.format("S=%d G=%d T=%d", starts, goals, traps))
    for r = gy - 1, gy + 1 do
        for c = gx - 1, gx + 1 do
            if data.map[r] and c >= 1 and c <= #data.map[r] then
                if data.map[r]:sub(c, c) == "T" then near = true end
            end
        end
    end
    check("packed level " .. i .. " trap beside goal", near)
end

if fails > 0 then
    print("\n" .. fails .. " failure(s)")
    os.exit(1)
end
print("\nPacked single-file load checks passed.")
