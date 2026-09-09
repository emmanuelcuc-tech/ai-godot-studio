import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameEngine()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

                GameCanvas(game: game)
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard game.started else { return }
                                game.aim = value.location
                                game.size = geo.size
                            }
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "STAGE %d/%d  %@  ·  .22 LR  %.0f fps / %.0f ft·lbf",
                                game.snap.index, game.snap.maxIndex, game.snap.label,
                                game.snap.impactFps, game.snap.impactFtlb))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(String(format: "HR %.0f  BP %.0f/%.0f  Brain %.0f%%  SpO2 %.0f%%  Bile %.0f%%  Heart %.0f%%",
                                game.vitals.hr, game.vitals.sys, game.vitals.dia,
                                game.vitals.brain * 100, game.vitals.spo2 * 100, game.vitals.bile * 100,
                                (game.integrity["heart"] ?? 1) * 100))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color(red: 0.66, green: 0.75, blue: 0.85))
                    if game.snap.throughWall {
                        Text(String(format: "Barrier Δv −%.0f fps (pre-wall %.0f fps)",
                                    game.snap.wallDelta, game.snap.preWallFps))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(red: 0.66, green: 0.75, blue: 0.85))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)

                if game.messageT > 0 {
                    Text(game.message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 1, green: 0.91, blue: 0.91))
                        .shadow(radius: 2)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                }

                HStack(alignment: .bottom) {
                    Text(game.cooldown <= 0 ? "READY" : String(format: "%.1fs", game.cooldown))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(game.cooldown <= 0 ? Color.green : Color.red.opacity(0.85))
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    Spacer()
                    VStack(spacing: 10) {
                        Button {
                            game.tryFire()
                        } label: {
                            Text(game.cooldown <= 0 ? "FIRE" : String(format: "%.1fs", game.cooldown))
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .frame(minWidth: 120)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.66, green: 0.09, blue: 0.16))
                        .disabled(game.cooldown > 0 || !game.started)

                        Button("NEXT") { game.advanceStage() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(white: 0.22))
                            .disabled(!game.started)

                        Button("RESET") { game.resetAll() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(white: 0.22))
                            .disabled(!game.started)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                Text("Drag aim · Tap FIRE · Swift + Safari")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.gray)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)

                if !game.started {
                    StartOverlay {
                        game.size = geo.size
                        game.aim = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.55)
                        game.start()
                    }
                }
            }
            .onAppear {
                game.size = geo.size
                game.aim = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.55)
            }
            .onChange(of: geo.size) { _, newSize in
                game.size = newSize
            }
        }
    }
}

struct StartOverlay: View {
    var onPlay: () -> Void
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.16, green: 0.12, blue: 0.19), Color(red: 0.05, green: 0.05, blue: 0.07)],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Anatomy Ballistics")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Swift Playgrounds on iPad — drag the red reticle, tap FIRE. Stages from 40 ft to a house wall. Free from Apple.")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Color(white: 0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Button(action: onPlay) {
                    Text("TAP TO PLAY")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.66, green: 0.09, blue: 0.16))
            }
            .padding(28)
        }
    }
}

struct GameCanvas: View {
    @ObservedObject var game: GameEngine

    var body: some View {
        Canvas { context, size in
            let _ = game.frameTick
            draw(context: context, size: size)
        }
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let W = Double(size.width), H = Double(size.height)
        let cam = game.cam

        // floor grid
        for i in -6...6 {
            let z0 = Vec3(x: Double(i) * 0.45, y: -1.35, z: -1)
            let z1 = Vec3(x: Double(i) * 0.45, y: -1.35, z: 4)
            if let a = project(cam, W, H, z0), let b = project(cam, W, H, z1) {
                var path = Path()
                path.move(to: CGPoint(x: a.x, y: a.y))
                path.addLine(to: CGPoint(x: b.x, y: b.y))
                context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
        }

        if game.snap.throughWall {
            let corners = [
                Vec3(x: -1.2, y: -1.35, z: game.wallZ),
                Vec3(x: 1.2, y: -1.35, z: game.wallZ),
                Vec3(x: 1.2, y: 1.6, z: game.wallZ),
                Vec3(x: -1.2, y: 1.6, z: game.wallZ)
            ]
            var path = Path()
            var first = true
            for c in corners {
                if let p = project(cam, W, H, c) {
                    if first { path.move(to: CGPoint(x: p.x, y: p.y)); first = false }
                    else { path.addLine(to: CGPoint(x: p.x, y: p.y)) }
                }
            }
            path.closeSubpath()
            context.fill(path, with: .color(.white.opacity(game.wallBroken ? 0.06 : 0.18)))
            context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
        }

        // springs
        for s in game.body.springs where s.alive {
            let a = game.body.nodes[s.i], b = game.body.nodes[s.j]
            guard let pa = project(cam, W, H, a.pos), let pb = project(cam, W, H, b.pos) else { continue }
            var path = Path()
            path.move(to: CGPoint(x: pa.x, y: pa.y))
            path.addLine(to: CGPoint(x: pb.x, y: pb.y))
            let color: Color
            let width: CGFloat
            switch s.kind {
            case "skin": color = Color(red: 0.82, green: 0.55, blue: 0.47).opacity(0.35); width = 1
            case "muscle": color = Color(red: 0.59, green: 0.18, blue: 0.22).opacity(0.4); width = 1.4
            case "bone":
                let cr = max(a.crack, b.crack)
                color = Color(red: (230 - cr * 80) / 255, green: (220 - cr * 100) / 255, blue: (200 - cr * 120) / 255).opacity(0.75)
                width = 2.2
            default: continue
            }
            context.stroke(path, with: .color(color), lineWidth: width)
        }

        // nodes
        var order: [(Int, (x: Double, y: Double, z: Double))] = []
        for i in game.body.nodes.indices {
            if let p = project(cam, W, H, game.body.nodes[i].pos) {
                order.append((i, p))
            }
        }
        order.sort { $0.1.z > $1.1.z }
        for (i, p) in order {
            let n = game.body.nodes[i]
            var r = 3 + 20 / p.z
            var col: Color
            if n.kind == "bone" {
                col = n.crack > 0.4 ? Color(red: 1, green: 0.9, blue: 0.7).opacity(0.9) : Color(red: 0.92, green: 0.88, blue: 0.82).opacity(0.65)
                r = 4 + 22 / p.z
            } else if n.kind == "organ", let name = n.organ {
                let def = ORGAN_DEFS[name] ?? OrganDef(rgb: (0.7, 0.3, 0.3), vital: false)
                let integ = game.integrity[name] ?? 1
                col = Color(red: def.rgb.0, green: def.rgb.1, blue: def.rgb.2).opacity(0.4 + integ * 0.45)
                if name == "heart" {
                    let pulse = max(0, sin(game.vitals.pulse))
                    r *= 1 + 0.08 * pulse * pulse * pulse
                }
            } else if n.wet > 0.3 {
                col = Color(red: 0.63, green: 0.16, blue: 0.2).opacity(0.7)
            } else {
                col = Color(red: 0.78, green: 0.55, blue: 0.47).opacity(0.45)
            }
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(col))
        }

        // blood
        for p in game.blood.particles {
            guard let sp = project(cam, W, H, Vec3(x: p.x, y: p.y, z: p.z)) else { continue }
            let r = max(1.5, p.r * (180 / max(0.4, sp.z)))
            var col: Color = Color(red: 0.67, green: 0.04, blue: 0.09).opacity(p.free ? 0.7 : 0.45)
            if p.fluid == "bile" { col = Color(red: 0.7, green: 0.78, blue: 0.16).opacity(0.75) }
            if p.fluid == "gastric" { col = Color(red: 0.78, green: 0.75, blue: 0.55).opacity(0.65) }
            context.fill(Path(ellipseIn: CGRect(x: sp.x - r, y: sp.y - r, width: r * 2, height: r * 2)), with: .color(col))
        }

        for s in game.wallDebris {
            guard let p = project(cam, W, H, Vec3(x: s.x, y: s.y, z: s.z)) else { continue }
            let col = s.wood
                ? Color(red: 0.47, green: 0.33, blue: 0.18).opacity(s.life)
                : Color(white: 0.86).opacity(s.life)
            context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(col))
        }

        if let b = game.bullet {
            let tr = b.trail
            if tr.count > 1 {
                for i in 1..<tr.count {
                    guard let a = project(cam, W, H, tr[i - 1]), let c = project(cam, W, H, tr[i]) else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: a.x, y: a.y))
                    path.addLine(to: CGPoint(x: c.x, y: c.y))
                    let t = Double(i) / Double(tr.count)
                    context.stroke(path, with: .color(Color(red: 1, green: (40 + 40 * t) / 255, blue: 40 / 255).opacity(0.35 + 0.55 * t)),
                                   lineWidth: cam.mode == "side_trail" ? 3 : 2)
                }
            }
            if let bp = b.alive ? Optional(b.pos) : b.hitPos, let p = project(cam, W, H, bp) {
                let r = 5 + 25 / max(0.5, p.z)
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color(Color(red: 0.94, green: 0.86, blue: 0.31)))
            }
        }

        if cam.mode == "aim" || game.bullet == nil || game.impactDone {
            let ax = game.aim.x, ay = game.aim.y
            let ring = Path(ellipseIn: CGRect(x: ax - 14, y: ay - 14, width: 28, height: 28))
            context.stroke(ring, with: .color(Color.red.opacity(0.55)), lineWidth: 1.5)
            context.fill(Path(ellipseIn: CGRect(x: ax - 4, y: ay - 4, width: 8, height: 8)), with: .color(Color.red.opacity(0.55)))
            var cross = Path()
            cross.move(to: CGPoint(x: ax - 22, y: ay)); cross.addLine(to: CGPoint(x: ax - 10, y: ay))
            cross.move(to: CGPoint(x: ax + 10, y: ay)); cross.addLine(to: CGPoint(x: ax + 22, y: ay))
            cross.move(to: CGPoint(x: ax, y: ay - 22)); cross.addLine(to: CGPoint(x: ax, y: ay - 10))
            cross.move(to: CGPoint(x: ax, y: ay + 10)); cross.addLine(to: CGPoint(x: ax, y: ay + 22))
            context.stroke(cross, with: .color(Color.red.opacity(0.55)), lineWidth: 1.5)
        }

        // mode badge
        let badge = CGRect(x: W - 190, y: H - 42, width: 178, height: 30)
        context.fill(Path(roundedRect: badge, cornerRadius: 6), with: .color(Color(white: 0.12).opacity(0.85)))
        context.draw(
            Text(String(format: "%@  x%.2f", cam.mode.uppercased(), game.timeScale))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(red: 0.94, green: 0.85, blue: 0.47)),
            at: CGPoint(x: W - 178, y: H - 22),
            anchor: .leading
        )
    }
}

#Preview {
    ContentView()
}
