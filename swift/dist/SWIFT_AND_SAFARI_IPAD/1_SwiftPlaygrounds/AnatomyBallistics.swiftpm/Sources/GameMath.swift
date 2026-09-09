import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Vec3

struct Vec3 {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vec3(x: 0, y: 0, z: 0)

    func length() -> Double { sqrt(x * x + y * y + z * z) }
    func normalized() -> Vec3 {
        let L = max(1e-9, length())
        return Vec3(x: x / L, y: y / L, z: z / L)
    }
    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: Vec3, s: Double) -> Vec3 { Vec3(x: a.x * s, y: a.y * s, z: a.z * s) }
    static func dot(_ a: Vec3, _ b: Vec3) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
    static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 {
        Vec3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
    }
}

// MARK: - .22 LR tables (same as Codea / browser)

enum TwentyTwo {
    static let grain = 40.0
    static let rangeFeet = [40, 35, 30, 25, 20, 15]
    static let wallDV = 2.0 * 45.0 + 180.0
    /// yards, fps, ft·lbf
    static let hvTable: [(Double, Double, Double)] = [
        (0, 1255, 140), (8.33, 1234, 135), (16.67, 1212, 131), (25, 1192, 126), (50, 1133, 114)
    ]

    static func interp(feet: Double) -> (fps: Double, ftlb: Double) {
        let yd = feet / 3.0
        let tab = hvTable
        if yd <= tab[0].0 { return (tab[0].1, tab[0].2) }
        for i in 0..<(tab.count - 1) {
            let a = tab[i], b = tab[i + 1]
            if yd <= b.0 {
                let t = (yd - a.0) / (b.0 - a.0)
                return (a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
            }
        }
        let L = tab[tab.count - 1]
        return (L.1, L.2)
    }

    struct Stage {
        var index: Int
        var maxIndex: Int
        var rangeFeet: Double
        var throughWall: Bool
        var impactFps: Double
        var impactFtlb: Double
        var preWallFps: Double
        var wallDelta: Double
        var label: String
    }

    static func stage(_ indexIn: Int) -> Stage {
        let max = rangeFeet.count + 1
        let index = min(max, max(1, indexIn))
        let throughWall = index > rangeFeet.count
        let feet = throughWall ? 12.0 : Double(rangeFeet[index - 1])
        var ball = interp(feet: feet)
        let pre = ball.fps
        var wallDelta = 0.0
        if throughWall {
            wallDelta = wallDV
            ball.fps = max(200, ball.fps - wallDV)
            // Keep energy roughly proportional to v² after barrier loss
            ball.ftlb = ball.ftlb * pow(ball.fps / max(1, pre), 2)
        }
        let label = throughWall
            ? String(format: "WALL @ %.0fft (−%.0f fps)", feet, wallDelta)
            : String(format: "OPEN @ %.0fft", feet)
        return Stage(
            index: index, maxIndex: max, rangeFeet: feet, throughWall: throughWall,
            impactFps: ball.fps, impactFtlb: ball.ftlb, preWallFps: pre,
            wallDelta: wallDelta, label: label
        )
    }

    static func camDist(_ feet: Double) -> Double {
        2.2 + (feet / 40.0) * 6.5
    }
}

// MARK: - Soft body

struct SoftNode {
    var x, y, z: Double
    var ox, oy, oz: Double
    var inv: Double
    var kind: String
    var organ: String?
    var crack: Double = 0
    var wet: Double = 0
    var broken: Bool = false
    var anchor: Vec3?

    var pos: Vec3 {
        get { Vec3(x: x, y: y, z: z) }
        set { x = newValue.x; y = newValue.y; z = newValue.z }
    }
}

struct SoftSpring {
    var i: Int
    var j: Int
    var rest: Double
    var stiff: Double
    var breakStrain: Double
    var kind: String
    var alive: Bool = true
}

struct SoftBody {
    var nodes: [SoftNode] = []
    var springs: [SoftSpring] = []

    @discardableResult
    mutating func addNode(_ x: Double, _ y: Double, _ z: Double, kind: String = "muscle", inv: Double = 1, organ: String? = nil, anchor: Bool = false) -> Int {
        let a = anchor ? Vec3(x: x, y: y, z: z) : nil
        nodes.append(SoftNode(x: x, y: y, z: z, ox: x, oy: y, oz: z, inv: inv, kind: kind, organ: organ, anchor: a))
        return nodes.count - 1
    }

    mutating func addSpring(_ i: Int, _ j: Int, kind: String = "muscle", stiffness: Double? = nil, breakStrain: Double? = nil) {
        let a = nodes[i].pos, b = nodes[j].pos
        let rest = (a - b).length()
        var stiff = stiffness ?? 0.35
        var br = breakStrain ?? 1.85
        if kind == "bone" { stiff = stiffness ?? 0.92; br = breakStrain ?? 1.16 }
        if kind == "skin" { stiff = stiffness ?? 0.55; br = breakStrain ?? 1.55 }
        springs.append(SoftSpring(i: i, j: j, rest: max(0.01, rest), stiff: stiff, breakStrain: br, kind: kind))
    }

    mutating func ring(cx: Double, cy: Double, cz: Double, r: Double, count: Int, kind: String, inv: Double = 1) -> [Int] {
        var ids: [Int] = []
        for i in 0..<count {
            let a = Double(i) / Double(count) * .pi * 2
            ids.append(addNode(cx + cos(a) * r, cy, cz + sin(a) * r, kind: kind, inv: inv))
        }
        return ids
    }

    mutating func connectRings(_ A: [Int], _ B: [Int], kind: String, stiff: Double) {
        let n = A.count
        for i in 0..<n {
            addSpring(A[i], B[i], kind: kind, stiffness: stiff)
            addSpring(A[i], B[(i + 1) % n], kind: kind, stiffness: stiff * 0.85)
            addSpring(A[i], A[(i + 1) % n], kind: kind, stiffness: stiff)
            addSpring(B[i], B[(i + 1) % n], kind: kind, stiffness: stiff)
        }
    }

    mutating func step(dt: Double) {
        let g = -1.6
        for i in nodes.indices {
            if nodes[i].inv <= 0 { continue }
            var n = nodes[i]
            let vx = (n.x - n.ox) / max(1e-6, dt)
            let vy = (n.y - n.oy) / max(1e-6, dt)
            let vz = (n.z - n.oz) / max(1e-6, dt)
            n.ox = n.x; n.oy = n.y; n.oz = n.z
            n.x += vx * dt
            n.y += vy * dt + g * dt * dt * n.inv
            n.z += vz * dt
            if n.y < -1.35 { n.y = -1.35; n.oy = n.y }
            nodes[i] = n
        }
        for _ in 0..<2 {
            for s in springs.indices where springs[s].alive {
                var sp = springs[s]
                let i = sp.i, j = sp.j
                var a = nodes[i], b = nodes[j]
                let dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z
                let dist = max(1e-6, sqrt(dx * dx + dy * dy + dz * dz))
                let strain = dist / sp.rest
                if strain > sp.breakStrain {
                    sp.alive = false
                    springs[s] = sp
                    if sp.kind == "bone" {
                        nodes[i].crack = min(1, nodes[i].crack + 0.55)
                        nodes[j].crack = min(1, nodes[j].crack + 0.55)
                    }
                    continue
                }
                let diff = (dist - sp.rest) / dist
                let im = a.inv + b.inv
                if im <= 0 { continue }
                let corr = diff * sp.stiff
                let cx = dx * corr, cy = dy * corr, cz = dz * corr
                if a.inv > 0 {
                    a.x += cx * (a.inv / im)
                    a.y += cy * (a.inv / im)
                    a.z += cz * (a.inv / im)
                    nodes[i] = a
                }
                if b.inv > 0 {
                    b.x -= cx * (b.inv / im)
                    b.y -= cy * (b.inv / im)
                    b.z -= cz * (b.inv / im)
                    nodes[j] = b
                }
            }
        }
    }

    mutating func impulse(at hit: Vec3, ke: Double, radius: Double = 0.45) {
        let impulse = 0.015 + ke * 8
        for i in nodes.indices {
            var n = nodes[i]
            if n.inv <= 0 { continue }
            let d = (n.pos - hit).length()
            if d > radius { continue }
            let w = 1 - d / radius
            let dir = (n.pos - hit).normalized()
            let push = impulse * w * n.inv
            n.ox -= dir.x * push
            n.oy -= dir.y * push
            n.oz -= dir.z * push
            if n.kind == "bone" { n.crack = min(1, n.crack + ke * w * 4) }
            if n.kind == "skin" || n.kind == "muscle" { n.wet = min(1, n.wet + 0.4 * w) }
            nodes[i] = n
        }
        for s in springs.indices where springs[s].alive {
            let a = nodes[springs[s].i].pos, b = nodes[springs[s].j].pos
            let mid = (a + b) * 0.5
            if (mid - hit).length() < radius * 0.85 && springs[s].kind != "bone" {
                if ke > 0.08 { springs[s].alive = false }
            }
        }
    }
}

// MARK: - Organs / blood

struct OrganDef {
    var rgb: (Double, Double, Double)
    var vital: Bool
}

let ORGAN_DEFS: [String: OrganDef] = [
    "brain": OrganDef(rgb: (0.85, 0.55, 0.65), vital: true),
    "heart": OrganDef(rgb: (0.85, 0.15, 0.2), vital: true),
    "lungL": OrganDef(rgb: (0.75, 0.45, 0.5), vital: true),
    "lungR": OrganDef(rgb: (0.75, 0.45, 0.5), vital: true),
    "liver": OrganDef(rgb: (0.55, 0.2, 0.25), vital: true),
    "gallbladder": OrganDef(rgb: (0.35, 0.75, 0.25), vital: false),
    "stomach": OrganDef(rgb: (0.7, 0.55, 0.35), vital: false),
    "kidneyL": OrganDef(rgb: (0.65, 0.25, 0.3), vital: true),
    "kidneyR": OrganDef(rgb: (0.65, 0.25, 0.3), vital: true),
    "spleen": OrganDef(rgb: (0.55, 0.2, 0.4), vital: true),
]

struct OrganState {
    var integrity: [String: Double] = [:]
    var vitals = Vitals()
    init() {
        for k in ORGAN_DEFS.keys { integrity[k] = 1 }
    }
}

struct Vitals {
    var hr: Double = 72
    var sys: Double = 118
    var dia: Double = 76
    var brain: Double = 1
    var spo2: Double = 0.98
    var bile: Double = 1
    var pulse: Double = 0
}

struct BloodParticle {
    var x, y, z: Double
    var vx, vy, vz: Double
    var life: Double
    var r: Double
    var free: Bool
    var fluid: String
}

struct BloodSim {
    var particles: [BloodParticle] = []

    mutating func gush(at p: Vec3, dir: Vec3, amount: Int, fluid: String = "blood") {
        for _ in 0..<amount {
            let jitter = Vec3(x: Double.random(in: -0.3...0.3), y: Double.random(in: -0.2...0.4), z: Double.random(in: -0.3...0.3))
            let v = (dir.normalized() + jitter) * Double.random(in: 0.8...2.2)
            particles.append(BloodParticle(
                x: p.x, y: p.y, z: p.z, vx: v.x, vy: v.y, vz: v.z,
                life: Double.random(in: 1.2...2.8), r: Double.random(in: 0.025...0.06),
                free: true, fluid: fluid
            ))
        }
    }

    mutating func step(dt: Double) {
        var next: [BloodParticle] = []
        for var p in particles {
            p.vy -= 3.2 * dt
            p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt
            p.life -= dt
            if p.y < -1.35 { p.y = -1.35; p.vy *= -0.2; p.vx *= 0.7; p.vz *= 0.7 }
            if p.life > 0 { next.append(p) }
        }
        particles = next
    }
}

// MARK: - Anatomy build

struct AnatomyMeta {
    var bodyCenter = Vec3(x: 0, y: 0.05, z: 0)
    var organNodes: [String: Int] = [:]
}

func buildAnatomy() -> (SoftBody, AnatomyMeta) {
    var body = SoftBody()
    var meta = AnatomyMeta()

    // Legs
    let footL = body.addNode(-0.22, -1.25, 0.05, kind: "bone", inv: 0.2)
    let footR = body.addNode(0.22, -1.25, 0.05, kind: "bone", inv: 0.2)
    let kneeL = body.addNode(-0.2, -0.7, 0.02, kind: "bone", inv: 0.35)
    let kneeR = body.addNode(0.2, -0.7, 0.02, kind: "bone", inv: 0.35)
    let hipL = body.addNode(-0.18, -0.15, 0, kind: "bone", inv: 0.4)
    let hipR = body.addNode(0.18, -0.15, 0, kind: "bone", inv: 0.4)
    body.addSpring(footL, kneeL, kind: "bone")
    body.addSpring(kneeL, hipL, kind: "bone")
    body.addSpring(footR, kneeR, kind: "bone")
    body.addSpring(kneeR, hipR, kind: "bone")
    body.addSpring(hipL, hipR, kind: "bone")

    // Torso rings
    let pelvis = body.ring(cx: 0, cy: -0.05, cz: 0, r: 0.28, count: 8, kind: "bone", inv: 0.45)
    let waist = body.ring(cx: 0, cy: 0.25, cz: 0, r: 0.26, count: 8, kind: "muscle", inv: 0.7)
    let chest = body.ring(cx: 0, cy: 0.55, cz: 0, r: 0.3, count: 8, kind: "muscle", inv: 0.65)
    let sh = body.ring(cx: 0, cy: 0.85, cz: 0, r: 0.32, count: 8, kind: "bone", inv: 0.4)
    body.connectRings(pelvis, waist, kind: "muscle", stiff: 0.45)
    body.connectRings(waist, chest, kind: "muscle", stiff: 0.4)
    body.connectRings(chest, sh, kind: "muscle", stiff: 0.42)
    body.addSpring(hipL, pelvis[6], kind: "bone")
    body.addSpring(hipR, pelvis[2], kind: "bone")

    // Skin shell
    let skinLow = body.ring(cx: 0, cy: 0.15, cz: 0, r: 0.36, count: 10, kind: "skin", inv: 0.9)
    let skinHi = body.ring(cx: 0, cy: 0.7, cz: 0, r: 0.38, count: 10, kind: "skin", inv: 0.9)
    body.connectRings(skinLow, skinHi, kind: "skin", stiff: 0.5)

    // Arms
    let shL = body.addNode(-0.42, 0.82, 0, kind: "bone", inv: 0.4)
    let shR = body.addNode(0.42, 0.82, 0, kind: "bone", inv: 0.4)
    let elL = body.addNode(-0.55, 0.35, 0.05, kind: "bone", inv: 0.5)
    let elR = body.addNode(0.55, 0.35, 0.05, kind: "bone", inv: 0.5)
    let handL = body.addNode(-0.58, -0.05, 0.08, kind: "bone", inv: 0.55)
    let handR = body.addNode(0.58, -0.05, 0.08, kind: "bone", inv: 0.55)
    body.addSpring(sh[6], shL, kind: "bone")
    body.addSpring(sh[2], shR, kind: "bone")
    body.addSpring(shL, elL, kind: "bone")
    body.addSpring(elL, handL, kind: "bone")
    body.addSpring(shR, elR, kind: "bone")
    body.addSpring(elR, handR, kind: "bone")

    // Neck / head
    let neck = body.addNode(0, 1.05, 0, kind: "bone", inv: 0.35)
    let head = body.addNode(0, 1.28, 0.02, kind: "bone", inv: 0.3)
    body.addSpring(sh[0], neck, kind: "bone")
    body.addSpring(sh[4], neck, kind: "bone")
    body.addSpring(neck, head, kind: "bone")

    func organ(_ name: String, _ x: Double, _ y: Double, _ z: Double) {
        let id = body.addNode(x, y, z, kind: "organ", inv: 0.25, organ: name)
        meta.organNodes[name] = id
        // tether to nearest chest node
        body.addSpring(id, chest[0], kind: "muscle", stiffness: 0.55)
        body.addSpring(id, chest[4], kind: "muscle", stiffness: 0.45)
    }
    organ("brain", 0, 1.3, 0.02)
    organ("heart", 0.05, 0.58, 0.06)
    organ("lungL", -0.14, 0.62, 0.02)
    organ("lungR", 0.14, 0.62, 0.02)
    organ("liver", 0.1, 0.32, 0.04)
    organ("gallbladder", 0.16, 0.28, 0.06)
    organ("stomach", -0.06, 0.3, 0.05)
    organ("kidneyL", -0.12, 0.22, -0.08)
    organ("kidneyR", 0.12, 0.22, -0.08)
    organ("spleen", -0.18, 0.4, 0.02)

    meta.bodyCenter = Vec3(x: 0, y: 0.35, z: 0)
    return (body, meta)
}

// MARK: - Camera / projection

struct Cam {
    var eye = Vec3(x: 0.15, y: 0.55, z: 8)
    var target = Vec3.zero
    var up = Vec3(x: 0, y: 1, z: 0)
    var fov: Double = 48
    var mode: String = "aim"
    var hold: Double = 0
    var impactComplete = false
    var rangeFeet: Double = 40
}

func project(_ cam: Cam, _ W: Double, _ H: Double, _ p: Vec3) -> (x: Double, y: Double, z: Double)? {
    let f = (cam.target - cam.eye).normalized()
    let r = Vec3.cross(f, cam.up).normalized()
    let u = Vec3.cross(r, f)
    let v = p - cam.eye
    let x = Vec3.dot(v, r)
    let y = Vec3.dot(v, u)
    let z = Vec3.dot(v, f)
    if z < 0.15 { return nil }
    let scale = (min(W, H) * 0.55) / tan(cam.fov * .pi / 180 / 2) / z
    return (W * 0.5 + x * scale, H * 0.55 - y * scale, z)
}

func lookRay(_ cam: Cam, _ sx: Double, _ sy: Double, _ W: Double, _ H: Double) -> (origin: Vec3, dir: Vec3) {
    let f = (cam.target - cam.eye).normalized()
    let r = Vec3.cross(f, cam.up).normalized()
    let u = Vec3.cross(r, f)
    let aspect = W / max(1, H)
    let tanHalf = tan(cam.fov * .pi / 180 / 2)
    let nx = ((sx / W) * 2 - 1) * tanHalf * aspect
    let ny = (1 - (sy / H) * 2) * tanHalf
    let dir = (f + r * nx + u * ny).normalized()
    return (cam.eye, dir)
}

struct Bullet {
    var pos: Vec3
    var vel: Vec3
    var alive: Bool
    var age: Double
    var trail: [Vec3]
    var hit: Bool
    var hitPos: Vec3?
    var realFps: Double
    var realFtlb: Double
    var throughWall: Bool
    var wallHit: Bool
}

struct WallShard {
    var x, y, z: Double
    var vx, vy, vz: Double
    var life: Double
    var wood: Bool
}
