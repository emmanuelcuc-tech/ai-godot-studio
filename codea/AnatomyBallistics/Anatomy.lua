-- Anatomy.lua
-- Builds a stylized human soft-body: skin fabric, muscle, bones, organs, vessels.

Anatomy = {}

local function ring(body, cx, cy, cz, radius, count, yAxis, opts)
    opts = opts or {}
    local ids = {}
    for i = 1, count do
        local a = (i - 1) / count * math.pi * 2
        local x = cx + math.cos(a) * radius
        local z = cz + math.sin(a) * radius
        local y = cy
        if yAxis then
            -- ring in XZ by default; yAxis unused beyond clarity
        end
        ids[i] = SoftBody.addNode(body, x, y, z, opts)
    end
    return ids
end

local function connectRings(body, a, b, kind, stiff)
    local n = #a
    for i = 1, n do
        SoftBody.addSpring(body, a[i], b[i], { kind = kind, stiffness = stiff })
        SoftBody.addSpring(body, a[i], b[(i % n) + 1], { kind = kind, stiffness = stiff * 0.85 })
        SoftBody.addSpring(body, a[(i % n) + 1], b[i], { kind = kind, stiffness = stiff * 0.85 })
        if kind == "skin" then
            SoftBody.addTriangle(body, a[i], b[i], b[(i % n) + 1], "skin")
            SoftBody.addTriangle(body, a[i], b[(i % n) + 1], a[(i % n) + 1], "skin")
        end
    end
    for i = 1, n do
        SoftBody.addSpring(body, a[i], a[(i % n) + 1], { kind = kind, stiffness = stiff })
        SoftBody.addSpring(body, b[i], b[(i % n) + 1], { kind = kind, stiffness = stiff })
    end
end

local function boneChain(body, points, boneType)
    boneType = boneType or "long"
    local ids = {}
    local br = Bones.breakStrainFor(boneType)
    for i, p in ipairs(points) do
        ids[i] = SoftBody.addNode(body, p.x, p.y, p.z, {
            kind = "bone",
            mass = 0.9 + (Bones.TYPES[boneType].density or 1.5) * 0.35,
            pinned = p.pinned,
        })
        Bones.applyToNode(body.nodes[ids[i]], boneType)
    end
    for i = 1, #ids - 1 do
        SoftBody.addSpring(body, ids[i], ids[i + 1], {
            kind = "bone",
            stiffness = 0.95,
            breakStrain = br,
        })
    end
    for i = 1, #ids - 2 do
        SoftBody.addSpring(body, ids[i], ids[i + 2], {
            kind = "bone",
            stiffness = 0.8,
            breakStrain = br * 1.05,
        })
    end
    return ids
end

local function organCluster(body, cx, cy, cz, name, scale)
    scale = scale or 0.18
    local def = Organs.DEFS[name] or { rgb = { 0.7, 0.3, 0.3 }, fluid = "blood" }
    local ids = {}
    local offsets = {
        { 0, 0, 0 },
        { 1, 0.2, 0.3 }, { -1, 0.1, 0.2 }, { 0.4, -0.8, 0.1 },
        { -0.3, 0.7, -0.4 }, { 0.6, 0.3, -0.6 }, { -0.7, -0.4, -0.2 },
    }
    for _, o in ipairs(offsets) do
        ids[#ids + 1] = SoftBody.addNode(body, cx + o[1] * scale, cy + o[2] * scale, cz + o[3] * scale, {
            kind = "organ",
            organ = name,
            fluid = def.fluid or "blood",
            mass = 0.9,
        })
    end
    for i = 1, #ids do
        for j = i + 1, #ids do
            SoftBody.addSpring(body, ids[i], ids[j], {
                kind = "muscle",
                stiffness = 0.7,
                breakStrain = 1.7,
            })
        end
    end
    return ids, { x = cx, y = cy, z = cz }, def.rgb or { 0.7, 0.3, 0.3 }
end

function Anatomy.build()
    local body = SoftBody.new()
    local meta = {
        organs = {},
        boneIds = {},
        skinRings = {},
        feet = {},
    }

    -- === Skeleton (Y up, facing -Z toward camera) ===
    local spine = boneChain(body, {
        { x = 0, y = -0.95, z = 0, pinned = true }, -- pelvis anchor
        { x = 0, y = -0.55, z = 0.02 },
        { x = 0, y = -0.15, z = 0.04 },
        { x = 0, y = 0.25, z = 0.02 },
        { x = 0, y = 0.55, z = 0 },
        { x = 0, y = 0.78, z = 0 }, -- neck
    }, "vertebra")
    meta.boneIds.spine = spine
    Bones.applyToNode(body.nodes[spine[1]], "pelvis")

    local skull = boneChain(body, {
        { x = 0, y = 0.88, z = 0 },
        { x = 0, y = 1.05, z = 0.02 },
        { x = 0, y = 1.18, z = 0 },
    }, "skull")
    SoftBody.addSpring(body, spine[#spine], skull[1], {
        kind = "bone",
        stiffness = 0.9,
        breakStrain = Bones.breakStrainFor("skull"),
    })
    meta.boneIds.skull = skull

    -- Ribs (simple pairs)
    local ribs = {}
    for i = 1, 4 do
        local y = 0.45 - (i - 1) * 0.14
        local left = SoftBody.addNode(body, -0.28 - i * 0.02, y, 0.05, { kind = "bone", mass = 1.0 })
        local right = SoftBody.addNode(body, 0.28 + i * 0.02, y, 0.05, { kind = "bone", mass = 1.0 })
        Bones.applyToNode(body.nodes[left], "rib")
        Bones.applyToNode(body.nodes[right], "rib")
        local br = Bones.breakStrainFor("rib")
        SoftBody.addSpring(body, spine[5 - math.min(i, 3)], left, { kind = "bone", stiffness = 0.88, breakStrain = br })
        SoftBody.addSpring(body, spine[5 - math.min(i, 3)], right, { kind = "bone", stiffness = 0.88, breakStrain = br })
        SoftBody.addSpring(body, left, right, { kind = "bone", stiffness = 0.75, breakStrain = br })
        ribs[#ribs + 1] = { left, right }
    end
    meta.boneIds.ribs = ribs

    -- Arms
    local function limbBones(side)
        local s = side
        local shoulder = SoftBody.addNode(body, 0.32 * s, 0.48, 0, { kind = "bone", mass = 1.2 })
        Bones.applyToNode(body.nodes[shoulder], "long")
        SoftBody.addSpring(body, spine[5], shoulder, {
            kind = "bone", stiffness = 0.9, breakStrain = Bones.breakStrainFor("long"),
        })
        local chain = boneChain(body, {
            { x = 0.38 * s, y = 0.25, z = 0.02 },
            { x = 0.42 * s, y = -0.05, z = 0.04 },
            { x = 0.45 * s, y = -0.35, z = 0.02 },
        }, "long")
        SoftBody.addSpring(body, shoulder, chain[1], {
            kind = "bone", stiffness = 0.9, breakStrain = Bones.breakStrainFor("long"),
        })
        return { shoulder, chain[1], chain[2], chain[3] }
    end
    meta.boneIds.leftArm = limbBones(-1)
    meta.boneIds.rightArm = limbBones(1)

    -- Legs
    local function legBones(side)
        local s = side
        local hip = SoftBody.addNode(body, 0.14 * s, -0.95, 0, { kind = "bone", mass = 1.3, pinned = true })
        Bones.applyToNode(body.nodes[hip], "pelvis")
        SoftBody.addSpring(body, spine[1], hip, {
            kind = "bone", stiffness = 0.95, breakStrain = Bones.breakStrainFor("pelvis"),
        })
        local chain = boneChain(body, {
            { x = 0.16 * s, y = -1.35, z = 0.02 },
            { x = 0.15 * s, y = -1.75, z = 0.04 },
            { x = 0.15 * s, y = -2.05, z = 0.06, pinned = true },
        }, "long")
        SoftBody.addSpring(body, hip, chain[1], {
            kind = "bone", stiffness = 0.92, breakStrain = Bones.breakStrainFor("long"),
        })
        meta.feet[#meta.feet + 1] = chain[#chain]
        return { hip, chain[1], chain[2], chain[3] }
    end
    meta.boneIds.leftLeg = legBones(-1)
    meta.boneIds.rightLeg = legBones(1)

    -- === Organs (functional + fluids) ===
    local function addOrgan(name, x, y, z, scale)
        local ids, center, rgb = organCluster(body, x, y, z, name, scale)
        meta.organs[#meta.organs + 1] = {
            ids = ids,
            name = name,
            rgb = rgb,
            cx = center.x, cy = center.y, cz = center.z,
            fluid = (Organs.DEFS[name] and Organs.DEFS[name].fluid) or "blood",
        }
        return ids
    end
    meta.organs = {}
    addOrgan("brain", 0, 1.05, 0.02, 0.14)
    addOrgan("heart", -0.06, 0.28, 0.06, 0.12)
    addOrgan("lungL", -0.2, 0.32, -0.02, 0.16)
    addOrgan("lungR", 0.2, 0.32, -0.02, 0.16)
    addOrgan("liver", 0.12, -0.05, 0.04, 0.17)
    addOrgan("gallbladder", 0.18, -0.12, 0.06, 0.07)
    addOrgan("stomach", -0.08, -0.12, 0.05, 0.14)
    addOrgan("kidneyL", -0.14, -0.25, -0.06, 0.09)
    addOrgan("kidneyR", 0.14, -0.25, -0.06, 0.09)
    addOrgan("spleen", -0.22, -0.02, 0.02, 0.1)

    -- Muscle bind organs to spine
    for _, org in ipairs(meta.organs) do
        local bind = (org.name == "brain") and spine[#spine] or spine[3]
        for _, id in ipairs(org.ids) do
            SoftBody.addSpring(body, id, bind, { kind = "muscle", stiffness = 0.55, breakStrain = 1.9 })
            SoftBody.addSpring(body, id, spine[4], { kind = "muscle", stiffness = 0.5, breakStrain = 1.9 })
        end
    end

    -- === Skin fabric cages (tight springs) + muscle underlayer ===
    local function torsoCage(y0, y1, layers, radius, segs)
        local ringsSkin, ringsMuscle = {}, {}
        for li = 1, layers do
            local t = (li - 1) / (layers - 1)
            local y = y0 + (y1 - y0) * t
            local r = radius * (0.85 + 0.2 * math.sin(t * math.pi))
            local skin = ring(body, 0, y, 0, r, segs, true, { kind = "skin", mass = 0.55 })
            local muscle = ring(body, 0, y, 0, r * 0.78, segs, true, { kind = "flesh", mass = 0.8 })
            ringsSkin[li] = skin
            ringsMuscle[li] = muscle
            -- Skin to muscle radial fabric
            for i = 1, segs do
                SoftBody.addSpring(body, skin[i], muscle[i], {
                    kind = "skin",
                    stiffness = 0.62,
                    breakStrain = 1.48,
                })
                SoftBody.addSpring(body, muscle[i], spine[math.min(#spine, 2 + math.floor(t * 3))], {
                    kind = "muscle",
                    stiffness = 0.48,
                    breakStrain = 2.0,
                })
            end
            if li > 1 then
                connectRings(body, ringsSkin[li - 1], skin, "skin", 0.58)
                connectRings(body, ringsMuscle[li - 1], muscle, "muscle", 0.5)
            end
        end
        meta.skinRings[#meta.skinRings + 1] = ringsSkin
        return ringsSkin, ringsMuscle
    end

    torsoCage(-0.85, 0.55, 7, 0.34, 8)

    -- Head skin
    local headRings = {}
    for li = 1, 4 do
        local t = (li - 1) / 3
        local y = 0.9 + t * 0.32
        local r = 0.16 * math.sin(math.pi * (0.25 + t * 0.7)) + 0.08
        headRings[li] = ring(body, 0, y, 0, r, 6, true, { kind = "skin", mass = 0.45 })
        if li > 1 then
            connectRings(body, headRings[li - 1], headRings[li], "skin", 0.6)
        end
        for i = 1, 6 do
            SoftBody.addSpring(body, headRings[li][i], skull[math.min(#skull, 1 + math.floor(t * 2))], {
                kind = "muscle",
                stiffness = 0.55,
                breakStrain = 1.85,
            })
        end
    end

    -- Limb soft sleeves
    local function sleeve(boneIds, radius, segs)
        local prev
        for bi, bid in ipairs(boneIds) do
            local bn = body.nodes[bid]
            local skin = ring(body, bn.x, bn.y, bn.z, radius, segs, true, { kind = "skin", mass = 0.4 })
            for i = 1, segs do
                SoftBody.addSpring(body, skin[i], bid, { kind = "muscle", stiffness = 0.55, breakStrain = 1.95 })
            end
            if prev then
                connectRings(body, prev, skin, "skin", 0.55)
            end
            prev = skin
        end
    end
    sleeve(meta.boneIds.leftArm, 0.09, 5)
    sleeve(meta.boneIds.rightArm, 0.09, 5)
    sleeve(meta.boneIds.leftLeg, 0.12, 6)
    sleeve(meta.boneIds.rightLeg, 0.12, 6)

    -- Blood vessels (paths in world space sampled from anatomy)
    local blood = Blood.new()
    Blood.addVessel(blood, {
        { x = 0, y = -0.9, z = 0.05 },
        { x = 0, y = -0.4, z = 0.06 },
        { x = 0, y = 0.1, z = 0.07 },
        { x = -0.05, y = 0.28, z = 0.08 }, -- toward heart
        { x = 0, y = 0.5, z = 0.04 },
        { x = 0, y = 0.75, z = 0.02 },
    })
    Blood.addVessel(blood, {
        { x = -0.05, y = 0.28, z = 0.08 },
        { x = -0.22, y = 0.35, z = 0.02 },
        { x = -0.35, y = 0.2, z = 0.02 },
        { x = -0.42, y = -0.1, z = 0.03 },
    })
    Blood.addVessel(blood, {
        { x = -0.05, y = 0.28, z = 0.08 },
        { x = 0.22, y = 0.35, z = 0.02 },
        { x = 0.35, y = 0.2, z = 0.02 },
        { x = 0.42, y = -0.1, z = 0.03 },
    })
    Blood.addVessel(blood, {
        { x = 0, y = -0.9, z = 0.05 },
        { x = -0.14, y = -1.3, z = 0.04 },
        { x = -0.15, y = -1.7, z = 0.05 },
    })
    Blood.addVessel(blood, {
        { x = 0, y = -0.9, z = 0.05 },
        { x = 0.14, y = -1.3, z = 0.04 },
        { x = 0.15, y = -1.7, z = 0.05 },
    })
    Blood.seedCirculation(blood, 10)

    meta.bodyCenter = Vec3.new(0, 0.05, 0)
    return body, blood, meta
end

function Anatomy.bounds(body)
    local minv = Vec3.new(1e9, 1e9, 1e9)
    local maxv = Vec3.new(-1e9, -1e9, -1e9)
    for _, n in ipairs(body.nodes) do
        if n.x < minv.x then minv.x = n.x end
        if n.y < minv.y then minv.y = n.y end
        if n.z < minv.z then minv.z = n.z end
        if n.x > maxv.x then maxv.x = n.x end
        if n.y > maxv.y then maxv.y = n.y end
        if n.z > maxv.z then maxv.z = n.z end
    end
    return minv, maxv
end
