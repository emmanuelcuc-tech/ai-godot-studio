-- Blueprints.lua
-- Real-ish building blueprints (plan + elevation cells).
-- Legend per cell: B brick, C concrete, R rebar, W wood, S steel, G glass, L laminated, . empty
-- Each non-empty cell becomes an independent Craft block (brick-by-brick / panel).

Blueprints = {}

Blueprints.LIST = {
    {
        id = "shed",
        name = "Timber Shed",
        -- floors from ground up; each floor is rows (z) of columns (x)
        floors = {
            { -- floor 0 walls footprint ring
                "BBBBBB",
                "BWWWWB",
                "BWWWWB",
                "BBBBBB",
            },
            {
                "BBBBBB",
                "BGGLLB",
                "BWWWWB",
                "BBBBBB",
            },
            {
                "WWWWWW",
                "W....W",
                "W....W",
                "WWWWWW",
            },
        },
        storyHeight = 1.0,
        cell = 0.55,
    },
    {
        id = "office",
        name = "Glass Office",
        floors = {
            {
                "CCCCCCCC",
                "C......C",
                "C......C",
                "C......C",
                "CCCCCCCC",
            },
            {
                "CGGGGGGC",
                "G......G",
                "G......G",
                "G......G",
                "CGGGGGGC",
            },
            {
                "CLLLLLLC",
                "L......L",
                "L......L",
                "L......L",
                "CLLLLLLC",
            },
            {
                "CRRRRRRC",
                "R......R",
                "R......R",
                "R......R",
                "CRRRRRRC",
            },
            {
                "CSSSSSSC",
                "S......S",
                "S......S",
                "S......S",
                "CSSSSSSC",
            },
        },
        storyHeight = 1.1,
        cell = 0.6,
    },
    {
        id = "highrise",
        name = "Brick Highrise",
        floors = {
            {
                "BBBBBBBB",
                "BCCCCCCB",
                "BC....CB",
                "BC....CB",
                "BCCCCCCB",
                "BBBBBBBB",
            },
            {
                "BBBBBBBB",
                "BGGGGGGG",
                "BG....GB",
                "BG....GB",
                "BGGGGGGG",
                "BBBBBBBB",
            },
            {
                "BBBBBBBB",
                "BLLLLLLB",
                "BL....LB",
                "BL....LB",
                "BLLLLLLB",
                "BBBBBBBB",
            },
            {
                "BRRRRRRB",
                "RS....SR",
                "RS....SR",
                "RS....SR",
                "RS....SR",
                "BRRRRRRB",
            },
            {
                "BBBBBBBB",
                "BWWWWWWB",
                "BW....WB",
                "BW....WB",
                "BWWWWWWB",
                "BBBBBBBB",
            },
            {
                "SSSSSSSS",
                "S......S",
                "S......S",
                "S......S",
                "S......S",
                "SSSSSSSS",
            },
        },
        storyHeight = 1.05,
        cell = 0.5,
    },
}

function Blueprints.count()
    return #Blueprints.LIST
end

function Blueprints.get(i)
    if i < 1 then i = 1 end
    if i > #Blueprints.LIST then i = #Blueprints.LIST end
    return Blueprints.LIST[i], i
end
