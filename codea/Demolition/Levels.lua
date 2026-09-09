-- Demolition stage blueprints
-- Legend (each cell is one physics block):
--   . empty
--   B brick   C concrete   G glass   S steel   W wood
-- Maps are top → bottom rows (first line is the roof).

Levels = {}

local DATA = {
    {
        name = "Starter Shed",
        shots = 3,
        baseX = nil,
        map = {
            ".BBBB.",
            ".BWWB.",
            ".BWWB.",
            ".BBBB.",
        },
    },
    {
        name = "Brick Stack",
        shots = 4,
        map = {
            "..BBBB..",
            ".BBBBBB.",
            ".BBBBBB.",
            ".BBCCBB.",
            ".BBBBBB.",
        },
    },
    {
        name = "Glass Office",
        shots = 4,
        map = {
            ".CCCCCCC.",
            ".CGGGGGC.",
            ".CGGGGGC.",
            ".CWWWWWC.",
            ".CCCCCCC.",
            ".CCCCCCC.",
        },
    },
    {
        name = "Steel Spine",
        shots = 5,
        map = {
            "..BBBBB..",
            ".BBSBSBB.",
            ".BBSSSSB.",
            ".BBSBSBB.",
            ".BBBBBBB.",
            ".WWCCCWW.",
        },
    },
    {
        name = "Highrise Razing",
        shots = 5,
        map = {
            "...GGG...",
            "..CGGGC..",
            ".CCSSSCC.",
            ".CBBBBBC.",
            ".CGGGGGC.",
            ".CSSSSSC.",
            ".CBBBBBC.",
            ".CCCCCCC.",
            ".WWWWWWW.",
        },
    },
}

function Levels.count()
    return #DATA
end

function Levels.get(index)
    if index < 1 then index = 1 end
    if index > #DATA then index = #DATA end
    return DATA[index], index
end
