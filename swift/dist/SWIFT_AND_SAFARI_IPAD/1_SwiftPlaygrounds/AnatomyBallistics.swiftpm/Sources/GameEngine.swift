import Foundation
import SwiftUI
import Combine

@MainActor
final class GameEngine: ObservableObject {
    @Published var size: CGSize = CGSize(width: 800, height: 600)
    @Published var aim = CGPoint(x: 400, y: 330)
    @Published var message = ""
    @Published var messageT: Double = 0
    @Published var cooldown: Double = 0
    @Published var stageIndex = 1
    @Published var snap = TwentyTwo.stage(1)
    @Published var started = false
    @Published var camMode = "aim"
    @Published var timeScale: Double = 1
    @Published var vitals = Vitals()
    @Published var integrity: [String: Double] = [:]
    @Published var frameTick: Int = 0

    var body = SoftBody()
    var meta = AnatomyMeta()
    var blood = BloodSim()
    var organs = OrganState()
    var cam = Cam()
    var bullet: Bullet?
    var impactDone = false
    var pendingAdvance = false
    var wallBroken = false
    var wallDebris: [WallShard] = []
    let wallZ = 1.85
    let cooldownMax = 3.0

    private var lastDate: Date?
    private var displayLink: CADisplayLinkTimer?

    init() {
        resetAll()
    }

    func start() {
        started = true
        lastDate = Date()
        displayLink = CADisplayLinkTimer { [weak self] in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit {}

    func resetAll() {
        let built = buildAnatomy()
        body = built.0
        meta = built.1
        blood = BloodSim()
        organs = OrganState()
        stageIndex = 1
        snap = TwentyTwo.stage(stageIndex)
        setAim()
        bullet = nil
        cooldown = 0
        impactDone = false
        pendingAdvance = false
        wallBroken = false
        wallDebris = []
        message = String(format: "%@ · .22 LR %.0f fps / %.0f ft·lbf", snap.label, snap.impactFps, snap.impactFtlb)
        messageT = 3
        publishVitals()
    }

    func advanceStage() {
        if stageIndex >= snap.maxIndex {
            message = "Final wall stage — RESET to restart"
            messageT = 2
            return
        }
        stageIndex += 1
        snap = TwentyTwo.stage(stageIndex)
        setAim()
        wallBroken = false
        wallDebris = []
        message = String(format: "%@ · %.0f fps / %.0f ft·lbf", snap.label, snap.impactFps, snap.impactFtlb)
        messageT = 2.5
        pendingAdvance = false
    }

    func setAim() {
        cam.mode = "aim"
        cam.rangeFeet = snap.rangeFeet
        cam.eye = Vec3(x: 0.15, y: 0.55, z: TwentyTwo.camDist(snap.rangeFeet))
        cam.target = meta.bodyCenter
        cam.up = Vec3(x: 0, y: 1, z: 0)
        cam.fov = 48
        cam.hold = 0
        cam.impactComplete = false
        camMode = "aim"
        timeScale = 1
    }

    func tryFire() {
        guard started else { return }
        if cooldown > 0 {
            message = String(format: "Chambering… %.1fs", cooldown)
            messageT = 1
            return
        }
        if cam.mode != "aim" && cam.hold > 0 { return }
        setAim()
        let W = Double(size.width), H = Double(size.height)
        let ray = lookRay(cam, Double(aim.x), Double(aim.y), W, H)
        let spawn = ray.origin + ray.dir * 0.35
        let cine = 8 + (snap.impactFps / 1255) * 10
        bullet = Bullet(
            pos: spawn, vel: ray.dir * cine, alive: true, age: 0,
            trail: [spawn], hit: false, hitPos: nil,
            realFps: snap.impactFps, realFtlb: snap.impactFtlb,
            throughWall: snap.throughWall, wallHit: false
        )
        cooldown = cooldownMax
        impactDone = false
        pendingAdvance = false
        cam.impactComplete = false
        message = snap.throughWall
            ? String(format: "Through wall · pre %.0f → %.0f fps", snap.preWallFps, snap.impactFps)
            : String(format: ".22 LR @ %.0fft · %.0f fps", snap.rangeFeet, snap.impactFps)
        messageT = 1.5
    }

    private func publishVitals() {
        vitals = organs.vitals
        integrity = organs.integrity
        objectWillChange.send()
    }

    private func tick() {
        guard started else { return }
        let now = Date()
        let dtRaw = min(0.033, now.timeIntervalSince(lastDate ?? now))
        lastDate = now
        let dt = dtRaw * timeScale
        if messageT > 0 { messageT -= dtRaw }
        if cooldown > 0 { cooldown = max(0, cooldown - dtRaw) }

        organs.vitals.pulse = (organs.vitals.pulse + dtRaw * (max(20, organs.vitals.hr) / 60) * .pi * 2)
            .truncatingRemainder(dividingBy: .pi * 2)

        cinematicUpdate(dtRaw)
        body.step(dt: dt)
        blood.step(dt: dt)
        updateWallDebris(dt: dt)
        if let b = bullet, b.alive || !impactDone {
            stepBullet(dt: dt)
        }
        if cam.impactComplete && impactDone && pendingAdvance {
            pendingAdvance = false
            advanceStage()
        }
        publishVitals()
        camMode = cam.mode
        frameTick &+= 1
    }

    private func cinematicUpdate(_ dt: Double) {
        guard let b = bullet else { timeScale = 1; return }
        if cam.impactComplete && impactDone {
            setAim()
            timeScale = 1
            return
        }
        if cam.mode == "impact" && cam.hold > 0 {
            cam.hold -= dt
            timeScale = 0.18
            if cam.hold <= 0 {
                cam.impactComplete = true
                setAim()
                timeScale = 1
            }
            return
        }
        if !b.alive && impactDone { return }

        var desired = "side_trail"
        if impactDone || b.hit { desired = "impact" }
        else if b.age > 0.12 { desired = "follow" }
        else if b.age > 0.04 { desired = "overhead" }

        if desired == "side_trail" {
            cam.mode = "side_trail"
            cam.eye = Vec3(x: -3.2, y: 0.6, z: b.pos.z * 0.4 + 2)
            cam.target = b.pos
            cam.fov = 42
            timeScale = 0.55
        } else if desired == "overhead" {
            cam.mode = "overhead"
            cam.eye = Vec3(x: b.pos.x, y: 3.4, z: b.pos.z + 0.2)
            cam.target = b.pos
            cam.up = Vec3(x: 0, y: 0, z: -1)
            cam.fov = 50
            timeScale = 0.4
        } else if desired == "follow" {
            cam.mode = "follow"
            let back = b.vel.normalized() * -1.4
            cam.eye = b.pos + back + Vec3(x: 0.1, y: 0.35, z: 0)
            cam.target = b.pos + b.vel.normalized() * 0.8
            cam.up = Vec3(x: 0, y: 1, z: 0)
            cam.fov = 55
            timeScale = 0.28
        } else if desired == "impact" {
            cam.mode = "impact"
            if cam.hold <= 0 { cam.hold = 1.15 }
            if let hp = b.hitPos {
                cam.eye = hp + Vec3(x: 0.9, y: 0.55, z: 1.4)
                cam.target = hp
            }
            cam.fov = 40
            timeScale = 0.18
        }
    }

    private func stepBullet(dt: Double) {
        guard var b = bullet else { return }
        if !b.alive { bullet = b; return }
        b.age += dt
        let next = b.pos + b.vel * dt

        if b.throughWall && !b.wallHit && b.pos.z > wallZ && next.z <= wallZ {
            b.wallHit = true
            wallBroken = true
            spawnWallDebris(at: Vec3(x: next.x, y: next.y, z: wallZ))
            message = String(format: "Barrier punch · −%.0f fps", snap.wallDelta)
            messageT = 1.2
        }

        // sphere hits vs nodes
        var bestD = 0.22
        var hitIdx: Int?
        for (i, n) in body.nodes.enumerated() {
            let d = (n.pos - next).length()
            let rad = n.kind == "organ" ? 0.16 : (n.kind == "bone" ? 0.12 : 0.14)
            if d < rad && d < bestD {
                bestD = d
                hitIdx = i
            }
        }

        if let hi = hitIdx {
            let n = body.nodes[hi]
            b.alive = false
            b.hit = true
            b.hitPos = n.pos
            impactDone = true
            pendingAdvance = true
            let ke = min(1.0, b.realFtlb / 140.0)
            body.impulse(at: n.pos, ke: ke)
            blood.gush(at: n.pos, dir: b.vel, amount: Int(12 + ke * 28))
            if let organ = n.organ {
                organs.integrity[organ] = max(0, (organs.integrity[organ] ?? 1) - ke * 0.55)
                applyOrganDamage(organ, ke: ke)
                if organ == "gallbladder" {
                    blood.gush(at: n.pos, dir: b.vel, amount: 10, fluid: "bile")
                }
                if organ == "stomach" {
                    blood.gush(at: n.pos, dir: b.vel, amount: 8, fluid: "gastric")
                }
            }
            message = String(format: "Impact · %.0f ft·lbf @ %.0f fps", b.realFtlb, b.realFps)
            messageT = 2
            bullet = b
            return
        }

        if next.z < -2.5 || b.age > 4 {
            b.alive = false
            impactDone = true
            message = "Miss"
            messageT = 1.2
            bullet = b
            return
        }

        b.pos = next
        b.trail.append(next)
        if b.trail.count > 48 { b.trail.removeFirst(b.trail.count - 48) }
        bullet = b
    }

    private func applyOrganDamage(_ organ: String, ke: Double) {
        var v = organs.vitals
        switch organ {
        case "heart":
            v.hr = max(0, v.hr - ke * 40)
            v.sys = max(40, v.sys - ke * 35)
            v.dia = max(25, v.dia - ke * 20)
        case "brain":
            v.brain = max(0, v.brain - ke * 0.7)
            v.hr += ke * 25
        case "lungL", "lungR":
            v.spo2 = max(0.4, v.spo2 - ke * 0.25)
            v.hr += ke * 15
        case "liver", "spleen", "kidneyL", "kidneyR":
            v.sys = max(50, v.sys - ke * 18)
        case "gallbladder":
            v.bile = max(0, v.bile - ke * 0.8)
        default:
            break
        }
        organs.vitals = v
    }

    private func spawnWallDebris(at p: Vec3) {
        for i in 0..<28 {
            let wood = i % 4 == 0
            wallDebris.append(WallShard(
                x: p.x + Double.random(in: -0.2...0.2),
                y: p.y + Double.random(in: -0.25...0.25),
                z: p.z,
                vx: Double.random(in: -1.2...1.2),
                vy: Double.random(in: 0.2...2.0),
                vz: Double.random(in: -2.5 ... -0.4),
                life: Double.random(in: 0.6...1.4),
                wood: wood
            ))
        }
    }

    private func updateWallDebris(dt: Double) {
        var next: [WallShard] = []
        for var s in wallDebris {
            s.vy -= 4 * dt
            s.x += s.vx * dt; s.y += s.vy * dt; s.z += s.vz * dt
            s.life -= dt
            if s.life > 0 { next.append(s) }
        }
        wallDebris = next
    }
}

/// Lightweight timer for Playgrounds / iOS without needing UIKit display link wiring in every target.
final class CADisplayLinkTimer {
    private var timer: Timer?
    init(tick: @escaping () -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in tick() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}
