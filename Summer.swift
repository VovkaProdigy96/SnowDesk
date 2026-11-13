// SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/)
// Лето: трава и цветы у Dock, бабочки, светлячки, мыльные пузыри, тополиный пух,
// яблоня, садовник с газонокосилкой, воздушный шар.

import AppKit

struct Butterfly {
    var x, y, vx, vy, phase: CGFloat
    var tx, ty: CGFloat
    var c: (CGFloat, CGFloat, CGFloat)
    var scale: CGFloat
    var leaving = false
}
struct Firefly { var x, y, vx, vy, phase: CGFloat; var leaving = false }
struct Bubble { var x, y, vx, vy, r, life, hue: CGFloat }

/// Пушинка одуванчика / тополиный пух.
enum Fluff {
    static let sprite: CGImage? = {
        let px = 40
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let c = CGPoint(x: 20, y: 22)
        // мягкое облачко
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.5), CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                           locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: 12, options: [])
        // тонкие лучики-волоски
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
        ctx.setLineWidth(0.7)
        for k in 0..<14 {
            let a = CGFloat(k) / 14 * 2 * .pi
            ctx.move(to: c)
            ctx.addLine(to: CGPoint(x: c.x + cos(a) * 11, y: c.y + sin(a) * 11))
        }
        ctx.strokePath()
        // семечко на ножке
        ctx.setStrokeColor(CGColor(red: 0.85, green: 0.82, blue: 0.75, alpha: 0.9))
        ctx.setLineWidth(0.9)
        ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x, y: c.y - 14))
        ctx.strokePath()
        ctx.setFillColor(CGColor(red: 0.55, green: 0.45, blue: 0.3, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: c.x - 1.2, y: c.y - 17, width: 2.4, height: 4))
        return ctx.makeImage()
    }()
}

extension SnowView {
    var isSummer: Bool { season == .summer }

    // MARK: - Трава и цветы у Dock

    func buildGrass() {
        let spring = isSpring
        grassSeason = season
        let w = bounds.width + 40
        let gh = ground + 46
        grassFor = CGSize(width: bounds.width, height: ground)
        var rng = SeededRandom(seed: 777)
        grassImage = makeImage(width: w, height: gh) { ctx in
            let base = self.ground + 4
            ctx.drawLinearGradient(linGrad(rgb(0.32, 0.58, 0.2), rgb(0.16, 0.36, 0.11)),
                                   start: CGPoint(x: 0, y: base), end: CGPoint(x: 0, y: 0), options: [])
            ctx.setLineCap(.round)
            // три слоя травинок: сзади темнее, спереди светлее
            for layer in 0..<3 {
                var x: CGFloat = 0
                while x < w {
                    let h = CGFloat.random(in: 8...26, using: &rng) * (0.7 + 0.18 * CGFloat(layer)) * (spring ? 0.65 : 1)
                    let lean = CGFloat.random(in: -6...6, using: &rng)
                    let k = 0.75 + 0.15 * CGFloat(layer) + CGFloat.random(in: -0.08...0.08, using: &rng)
                    ctx.setStrokeColor(spring ? rgb(0.36 * k, 0.68 * k, 0.22 * k) : rgb(0.24 * k, 0.55 * k, 0.16 * k))
                    ctx.setLineWidth(CGFloat.random(in: 1.2...2.2, using: &rng))
                    let b = CGPoint(x: x, y: base - 3)
                    ctx.move(to: b)
                    ctx.addQuadCurve(to: CGPoint(x: x + lean, y: base + h), control: CGPoint(x: x + lean * 0.2, y: base + h * 0.6))
                    ctx.strokePath()
                    x += CGFloat.random(in: 1.6...3.4, using: &rng)
                }
            }
            // цветы: ромашки, маки, васильки, одуванчики
            var x: CGFloat = CGFloat.random(in: 10...40, using: &rng)
            while x < w {
                let sh = CGFloat.random(in: 14...32, using: &rng)
                let top = CGPoint(x: x + CGFloat.random(in: -3...3, using: &rng), y: base + sh)
                ctx.setStrokeColor(rgb(0.2, 0.45, 0.14))
                ctx.setLineWidth(1.2)
                ctx.move(to: CGPoint(x: x, y: base - 2))
                ctx.addQuadCurve(to: top, control: CGPoint(x: x, y: base + sh * 0.5))
                ctx.strokePath()
                let kind = Int.random(in: 0..<5, using: &rng) + (spring ? 10 : 0)
                switch kind {
                case 10, 11:   // подснежник: белый поникший цветок
                    ctx.setFillColor(rgb(0.97, 0.98, 1))
                    ctx.fillEllipse(in: CGRect(x: top.x - 1, y: top.y - 5, width: 4, height: 6))
                    ctx.setFillColor(rgb(0.4, 0.7, 0.3))
                    ctx.fillEllipse(in: CGRect(x: top.x, y: top.y - 0.5, width: 2, height: 1.6))
                case 12:       // крокус
                    ctx.setFillColor(rgb(0.62, 0.4, 0.9))
                    ctx.fillEllipse(in: CGRect(x: top.x - 2.5, y: top.y - 3, width: 5, height: 7))
                    ctx.setFillColor(rgb(1, 0.8, 0.2))
                    ctx.fillEllipse(in: CGRect(x: top.x - 0.6, y: top.y + 1, width: 1.2, height: 2))
                case 13, 14:   // тюльпан
                    ctx.setFillColor(kind == 13 ? rgb(0.95, 0.2, 0.25) : rgb(1, 0.82, 0.15))
                    ctx.move(to: CGPoint(x: top.x - 3.5, y: top.y + 5))
                    ctx.addLine(to: CGPoint(x: top.x - 1.5, y: top.y + 2.5))
                    ctx.addLine(to: CGPoint(x: top.x, y: top.y + 5))
                    ctx.addLine(to: CGPoint(x: top.x + 1.5, y: top.y + 2.5))
                    ctx.addLine(to: CGPoint(x: top.x + 3.5, y: top.y + 5))
                    ctx.addQuadCurve(to: CGPoint(x: top.x - 3.5, y: top.y + 5), control: CGPoint(x: top.x, y: top.y - 6))
                    ctx.fillPath()
                case 0, 1:   // ромашка
                    ctx.setFillColor(rgb(1, 1, 1))
                    for p in 0..<8 {
                        let a = CGFloat(p) / 8 * 2 * .pi
                        ctx.fillEllipse(in: CGRect(x: top.x + cos(a) * 3.2 - 1.8, y: top.y + sin(a) * 3.2 - 1.8, width: 3.6, height: 3.6))
                    }
                    ctx.setFillColor(rgb(1, 0.8, 0.15))
                    ctx.fillEllipse(in: CGRect(x: top.x - 2, y: top.y - 2, width: 4, height: 4))
                case 2:      // мак
                    ctx.setFillColor(rgb(0.9, 0.12, 0.1))
                    ctx.fillEllipse(in: CGRect(x: top.x - 4, y: top.y - 3, width: 8, height: 6.5))
                    ctx.setFillColor(rgb(0.15, 0.1, 0.1))
                    ctx.fillEllipse(in: CGRect(x: top.x - 1.2, y: top.y - 0.5, width: 2.4, height: 2.4))
                case 3:      // василёк
                    ctx.setFillColor(rgb(0.3, 0.45, 0.95))
                    for p in 0..<6 {
                        let a = CGFloat(p) / 6 * 2 * .pi
                        ctx.fillEllipse(in: CGRect(x: top.x + cos(a) * 2.4 - 1.6, y: top.y + sin(a) * 2.4 - 1.6, width: 3.2, height: 3.2))
                    }
                default:     // одуванчик
                    ctx.setFillColor(rgb(1, 0.85, 0.1))
                    ctx.fillEllipse(in: CGRect(x: top.x - 3, y: top.y - 3, width: 6, height: 6))
                }
                x += CGFloat.random(in: 14...46, using: &rng)
            }
        }
    }

    func drawGrass(_ ctx: CGContext) {
        if grassImage == nil || grassSeason != season || grassFor != CGSize(width: bounds.width, height: ground) { buildGrass() }
        guard let img = grassImage else { return }
        // трава качается от ветра: сдвиг по верхушкам, корни на месте
        let sway = sin(t * 1.4) * 0.035 + max(-0.25, min(0.25, wind * 0.03))
        ctx.saveGState()
        ctx.translateBy(x: 0, y: ground)
        ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: sway, d: 1, tx: 0, ty: 0))
        ctx.draw(img, in: CGRect(x: -20, y: -ground, width: bounds.width + 40, height: ground + 46))
        ctx.restoreGState()
    }

    // MARK: - Живность и пузыри

    func newButterfly(fromLeft: Bool) -> Butterfly {
        let cols: [(CGFloat, CGFloat, CGFloat)] = [(1, 0.6, 0.1), (0.95, 0.9, 0.3), (0.35, 0.55, 1), (1, 1, 1), (0.9, 0.3, 0.6)]
        let x: CGFloat = fromLeft ? -20 : bounds.width + 20
        return Butterfly(x: x, y: ground + CGFloat.random(in: 40...200), vx: fromLeft ? 1 : -1, vy: 0,
                         phase: CGFloat.random(in: 0...6),
                         tx: CGFloat.random(in: 100...max(101, bounds.width - 100)), ty: ground + CGFloat.random(in: 15...160),
                         c: cols.randomElement() ?? (1, 0.6, 0.1), scale: CGFloat.random(in: 0.8...1.2))
    }

    func summerStep() {
        guard isSummer else {
            if !butterflies.isEmpty || !fireflies.isEmpty || !bubbles.isEmpty {
                butterflies.removeAll(); fireflies.removeAll(); bubbles.removeAll()
            }
            return
        }
        let w = bounds.width
        // бабочки днём
        let wantB = prefs.butterflies && nightLevel < 0.5 ? 5 : 0
        let activeB = butterflies.filter { !$0.leaving }.count
        if activeB < wantB && CGFloat.random(in: 0...1) < 0.006 { butterflies.append(newButterfly(fromLeft: Bool.random())) }
        if activeB > wantB, let i = butterflies.firstIndex(where: { !$0.leaving }) {
            butterflies[i].leaving = true
            butterflies[i].tx = butterflies[i].x < w / 2 ? -100 : w + 100
            butterflies[i].ty = butterflies[i].y + 200
        }
        var i = 0
        while i < butterflies.count {
            var b = butterflies[i]
            let dx = b.tx - b.x, dy = b.ty - b.y
            b.vx += dx * 0.0009 + CGFloat.random(in: -0.12...0.12)
            b.vy += dy * 0.0012 + CGFloat.random(in: -0.12...0.12) + sin(b.phase * 0.5) * 0.06
            let md = hypot(mouse.x - b.x, mouse.y - b.y)
            if md < 80 && md > 0.1 {
                b.vx += (b.x - mouse.x) / md * 0.5
                b.vy += (b.y - mouse.y) / md * 0.5
            }
            let sp = hypot(b.vx, b.vy)
            let maxSp: CGFloat = md < 80 ? 4 : 2
            if sp > maxSp { b.vx *= maxSp / sp; b.vy *= maxSp / sp }
            b.vx *= 0.97; b.vy *= 0.97
            b.x += b.vx + wind * 0.15
            b.y += b.vy
            b.y = max(ground + 6, b.y)
            b.phase += 0.55
            if !b.leaving && hypot(dx, dy) < 25 {
                b.tx = CGFloat.random(in: 60...max(61, w - 60))
                b.ty = ground + CGFloat.random(in: 12...200)
            }
            if b.leaving && (b.x < -60 || b.x > w + 60) { butterflies.remove(at: i); continue }
            butterflies[i] = b
            i += 1
        }
        // светлячки ночью
        let wantF = prefs.fireflies && nightLevel > 0.45 ? 26 : 0
        let activeF = fireflies.filter { !$0.leaving }.count
        if activeF < wantF && CGFloat.random(in: 0...1) < 0.05 {
            fireflies.append(Firefly(x: CGFloat.random(in: 0...w), y: ground + CGFloat.random(in: 6...140),
                                     vx: 0, vy: 0, phase: CGFloat.random(in: 0...6)))
        }
        if activeF > wantF, let k = fireflies.firstIndex(where: { !$0.leaving }) { fireflies[k].leaving = true }
        i = 0
        while i < fireflies.count {
            var f = fireflies[i]
            f.vx = (f.vx + CGFloat.random(in: -0.05...0.05)) * 0.98
            f.vy = (f.vy + CGFloat.random(in: -0.05...0.05)) * 0.98
            if f.y < ground + 5 { f.vy += 0.05 }
            if f.y > ground + 170 { f.vy -= 0.05 }
            f.x += f.vx + wind * 0.05
            f.y += f.vy
            f.phase += f.leaving ? 0.08 : 0.035
            if f.leaving && Int(f.phase * 10) % 37 == 0 && CGFloat.random(in: 0...1) < 0.1 { fireflies.remove(at: i); continue }
            fireflies[i] = f
            i += 1
        }
        // пузыри
        i = 0
        while i < bubbles.count {
            var b = bubbles[i]
            b.vy += 0.008
            b.vx += sin(t * 2 + b.hue * 10) * 0.02 + wind * 0.003
            b.vx *= 0.99; b.vy *= 0.99
            b.x += b.vx; b.y += b.vy
            b.life -= 1.0 / 60.0
            if b.life <= 0 || b.y > ceiling + 40 || b.x < -40 || b.x > w + 40 {
                if b.life <= 0 && particles.count < 1500 {
                    // лопнул — пара брызг
                    for _ in 0..<4 {
                        particles.append(Particle(x: b.x, y: b.y, vx: .random(in: -1.5...1.5), vy: .random(in: -1...1.5), r: 0.6))
                    }
                }
                bubbles.remove(at: i); continue
            }
            bubbles[i] = b
            i += 1
        }
    }

    func drawButterflies(_ ctx: CGContext) {
        for b in butterflies {
            ctx.saveGState()
            ctx.translateBy(x: b.x, y: b.y)
            ctx.scaleBy(x: (b.vx < 0 ? -1 : 1) * b.scale, y: b.scale)
            let flap = 0.25 + 0.75 * abs(sin(b.phase))
            let c = b.c
            for (dy, ry, rx) in [(2.0, 6.0, 7.5), (-3.0, 4.5, 5.5)] as [(CGFloat, CGFloat, CGFloat)] {
                ctx.setFillColor(rgb(c.0, c.1, c.2, 0.95))
                ctx.fillEllipse(in: CGRect(x: -rx * flap - 0.5, y: dy - ry / 2, width: rx * flap, height: ry))
                ctx.setFillColor(rgb(c.0 * 0.8, c.1 * 0.8, c.2 * 0.8, 0.9))
                ctx.fillEllipse(in: CGRect(x: 0.5, y: dy - ry / 2, width: rx * flap * 0.9, height: ry))
            }
            ctx.setFillColor(rgb(0.15, 0.12, 0.1))
            ctx.fill(CGRect(x: -0.8, y: -5, width: 1.6, height: 9))
            ctx.setStrokeColor(rgb(0.15, 0.12, 0.1))
            ctx.setLineWidth(0.6)
            ctx.move(to: CGPoint(x: 0, y: 4)); ctx.addLine(to: CGPoint(x: 2.5, y: 7.5))
            ctx.move(to: CGPoint(x: 0, y: 4)); ctx.addLine(to: CGPoint(x: -2.5, y: 7.5))
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    func drawFireflies(_ ctx: CGContext) {
        for f in fireflies {
            let glow = pow(max(0, sin(f.phase)), 3)
            guard glow > 0.03 else { continue }
            glowSpot(ctx, CGPoint(x: f.x, y: f.y), 9, (0.75, 1, 0.35), 0.55 * glow)
            ctx.setFillColor(rgb(0.9, 1, 0.6, glow))
            ctx.fillEllipse(in: CGRect(x: f.x - 1.3, y: f.y - 1.3, width: 2.6, height: 2.6))
        }
    }

    func drawBubbles(_ ctx: CGContext) {
        for b in bubbles {
            let r = b.r
            let fade = min(1, b.life * 2)
            let rect = CGRect(x: b.x - r, y: b.y - r, width: r * 2, height: r * 2)
            ctx.setFillColor(rgb(0.85, 0.95, 1, 0.08 * fade))
            ctx.fillEllipse(in: rect)
            // радужная плёнка
            let h = b.hue + t * 0.1
            ctx.setStrokeColor(rgb(0.6 + 0.4 * sin(h * 6), 0.6 + 0.4 * sin(h * 6 + 2), 0.6 + 0.4 * sin(h * 6 + 4), 0.55 * fade))
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: rect)
            ctx.setFillColor(rgb(1, 1, 1, 0.75 * fade))
            ctx.fillEllipse(in: CGRect(x: b.x - r * 0.55, y: b.y + r * 0.25, width: r * 0.35, height: r * 0.25))
        }
    }

    func drawFluffParticles(_ ctx: CGContext) {
        guard let sp = Fluff.sprite else { return }
        for q in particles {
            let d = 5 + q.r * 3.5
            ctx.saveGState()
            ctx.translateBy(x: q.x, y: q.y)
            ctx.rotate(by: sin(q.y * 0.03 + q.r * 5) * 0.4)
            ctx.draw(sp, in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d))
            ctx.restoreGState()
        }
    }

    /// Клик по траве: из-под курсора разлетается пух одуванчиков, бабочки вспархивают.
    func fluffBurst(at p: CGPoint) {
        for _ in 0..<14 where particles.count < 1500 {
            particles.append(Particle(x: p.x + .random(in: -10...10), y: max(p.y, ground + 10),
                                      vx: .random(in: -1.8...1.8), vy: .random(in: 1...3.2), r: .random(in: 1.5...3)))
        }
        for i in butterflies.indices where hypot(butterflies[i].x - p.x, butterflies[i].y - p.y) < 160 {
            butterflies[i].vy += 3
            butterflies[i].ty = ground + CGFloat.random(in: 140...260)
        }
    }

    func blowBubbles(at p: CGPoint, count: Int, dir: CGFloat = 0) {
        for _ in 0..<count where bubbles.count < 80 {
            bubbles.append(Bubble(x: p.x, y: p.y, vx: dir * CGFloat.random(in: 0.5...1.6) + .random(in: -0.6...0.6),
                                  vy: .random(in: 0.2...1.2), r: .random(in: 4...11), life: .random(in: 4...9),
                                  hue: .random(in: 0...1)))
        }
    }

    /// Ребёнок пускает мыльные пузыри.
    func kidBubbles(from a: Walker) {
        blowBubbles(at: CGPoint(x: a.x + a.dir * 12 * a.scale, y: surface(a.x) + 42 * a.scale), count: 6, dir: a.dir)
    }

    // MARK: - Яблоня

    func drawAppleBody(_ ctx: CGContext, H: CGFloat, rng: inout SeededRandom) {
        let bark = rgb(0.36, 0.25, 0.17)
        let trunk = CGMutablePath()
        trunk.move(to: CGPoint(x: -H * 0.055, y: 0))
        trunk.addQuadCurve(to: CGPoint(x: -H * 0.03, y: H * 0.45), control: CGPoint(x: -H * 0.015, y: H * 0.2))
        trunk.addLine(to: CGPoint(x: H * 0.03, y: H * 0.45))
        trunk.addQuadCurve(to: CGPoint(x: H * 0.055, y: 0), control: CGPoint(x: H * 0.02, y: H * 0.2))
        trunk.closeSubpath()
        ctx.addPath(trunk)
        ctx.setFillColor(bark)
        ctx.fillPath()
        ctx.setStrokeColor(bark)
        ctx.setLineCap(.round)
        for (a, len, w) in [(-0.95, 0.3, 0.026), (0.85, 0.3, 0.024), (-0.35, 0.3, 0.02), (0.3, 0.3, 0.02)] as [(CGFloat, CGFloat, CGFloat)] {
            let base = CGPoint(x: 0, y: H * 0.36)
            ctx.setLineWidth(H * w)
            ctx.move(to: base)
            ctx.addLine(to: CGPoint(x: sin(a) * H * len, y: base.y + cos(a) * H * len))
            ctx.strokePath()
        }
        let cy = H * 0.64, rx = H * 0.37, ry = H * 0.3
        var blobs: [(CGPoint, CGFloat)] = []
        for _ in 0..<70 {
            let a = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let d = sqrt(CGFloat.random(in: 0...1, using: &rng))
            blobs.append((CGPoint(x: cos(a) * rx * d, y: cy + sin(a) * ry * d), H * CGFloat.random(in: 0.07...0.12, using: &rng)))
        }
        blobs.sort { $0.0.y < $1.0.y }
        for (c, r) in blobs {
            let light = 0.7 + 0.4 * (c.y - (cy - ry)) / (2 * ry)
            let gv = CGFloat.random(in: 0.9...1.1, using: &rng)
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(0.4 * light * gv, 0.7 * light, 0.24 * light), rgb(0.16 * light, 0.4 * light * gv, 0.12 * light)),
                                   start: CGPoint(x: c.x - r * 0.4, y: c.y + r), end: CGPoint(x: c.x + r * 0.3, y: c.y - r), options: [])
            ctx.restoreGState()
        }
        // яблоки
        for _ in 0..<16 {
            let a = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let d = sqrt(CGFloat.random(in: 0.2...0.95, using: &rng))
            let c = CGPoint(x: cos(a) * rx * d, y: cy + sin(a) * ry * d)
            let r = H * 0.022
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(1, 0.35, 0.25), rgb(0.6, 0.05, 0.05)),
                                   start: CGPoint(x: c.x - r, y: c.y + r), end: CGPoint(x: c.x + r, y: c.y - r), options: [])
            ctx.restoreGState()
            ctx.setFillColor(rgb(1, 1, 1, 0.5))
            ctx.fillEllipse(in: CGRect(x: c.x - r * 0.5, y: c.y + r * 0.2, width: r * 0.45, height: r * 0.35))
        }
    }

    // MARK: - Клумба у домиков

    func drawFlowerBed(_ ctx: CGContext) -> [CGRect] {
        ctx.setFillColor(rgb(0.38, 0.25, 0.15))
        ctx.addPath(CGPath(roundedRect: CGRect(x: 1, y: 0, width: 34, height: 5), cornerWidth: 2, cornerHeight: 2, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(rgb(0.2, 0.48, 0.18))
        for k in 0..<7 { ctx.fillEllipse(in: CGRect(x: 1 + CGFloat(k) * 4.6, y: 3, width: 6, height: 8)) }
        let cols: [(CGFloat, CGFloat, CGFloat)] = [(0.95, 0.25, 0.35), (1, 0.85, 0.2), (1, 1, 1), (0.6, 0.4, 0.95), (1, 0.55, 0.2)]
        for k in 0..<9 {
            let c = cols[k % cols.count]
            let x = 3 + CGFloat(k) * 3.6
            let y = 9 + CGFloat((k * 5) % 4)
            ctx.setFillColor(rgb(c.0, c.1, c.2))
            ctx.fillEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
        }
        return []
    }

    // MARK: - Садовник с газонокосилкой

    func drawMower(_ ctx: CGContext, _ a: Walker) {
        // ручка от рук к косилке впереди
        line(ctx, CGPoint(x: 5, y: 34), CGPoint(x: 26, y: 10), 1.8, rgb(0.2, 0.2, 0.22))
        let body = CGRect(x: 22, y: 3, width: 20, height: 9)
        ctx.addPath(CGPath(roundedRect: body, cornerWidth: 3, cornerHeight: 3, transform: nil))
        ctx.setFillColor(rgb(0.85, 0.15, 0.12))
        ctx.fillPath()
        ctx.setFillColor(rgb(0.25, 0.25, 0.27))
        ctx.fill(CGRect(x: 27, y: 10, width: 8, height: 4))
        ctx.setFillColor(rgb(0.1, 0.1, 0.1))
        for wx in [25.0, 38.0] as [CGFloat] {
            ctx.fillEllipse(in: CGRect(x: wx - 3, y: -1, width: 6, height: 6))
        }
        // летящая скошенная трава
        ctx.setFillColor(rgb(0.35, 0.65, 0.2, 0.8))
        for k in 0..<4 {
            let ph = (t * 3 + CGFloat(k) * 0.7).truncatingRemainder(dividingBy: 1)
            ctx.fillEllipse(in: CGRect(x: 20 - ph * 14, y: 4 + ph * 8 - ph * ph * 10, width: 2, height: 2))
        }
    }

    // MARK: - Воздушный шар (вместо саней летом)

    func drawBalloon(_ ctx: CGContext) {
        guard let sx = sleighX else { return }
        let x = sx + 80, y = sleighY
        let R: CGFloat = 34
        let c = CGPoint(x: x, y: y + 52)
        // полосатый купол
        let dome = CGMutablePath()
        dome.addArc(center: c, radius: R, startAngle: -0.55, endAngle: .pi + 0.55, clockwise: false)
        dome.addQuadCurve(to: CGPoint(x: x, y: y + 6), control: CGPoint(x: x - R * 0.7, y: y + 20))
        dome.addQuadCurve(to: CGPoint(x: c.x + R * cos(-0.55), y: c.y + R * sin(-0.55)), control: CGPoint(x: x + R * 0.7, y: y + 20))
        dome.closeSubpath()
        ctx.saveGState()
        ctx.addPath(dome)
        ctx.clip()
        let stripes: [(CGFloat, CGFloat, CGFloat)] = [(0.92, 0.2, 0.2), (1, 0.85, 0.2), (0.2, 0.5, 0.9), (1, 1, 1)]
        for k in 0..<8 {
            let c0 = stripes[k % stripes.count]
            ctx.setFillColor(rgb(c0.0, c0.1, c0.2))
            ctx.fill(CGRect(x: x - R + CGFloat(k) * R / 4, y: y, width: R / 4 + 0.5, height: R * 2 + 30))
        }
        ctx.drawLinearGradient(linGrad(rgb(1, 1, 1, 0.25), rgb(0, 0, 0, 0.25)),
                               start: CGPoint(x: x - R, y: c.y + R), end: CGPoint(x: x + R, y: c.y - R), options: [])
        ctx.restoreGState()
        // стропы и корзина
        ctx.setStrokeColor(rgb(0.3, 0.22, 0.14))
        ctx.setLineWidth(0.8)
        ctx.move(to: CGPoint(x: x - 7, y: y + 6)); ctx.addLine(to: CGPoint(x: x - 6, y: y - 6))
        ctx.move(to: CGPoint(x: x + 7, y: y + 6)); ctx.addLine(to: CGPoint(x: x + 6, y: y - 6))
        ctx.strokePath()
        ctx.setFillColor(rgb(0.55, 0.38, 0.2))
        ctx.fill(CGRect(x: x - 7, y: y - 15, width: 14, height: 10))
        ctx.setFillColor(rgb(0.4, 0.27, 0.14))
        ctx.fill(CGRect(x: x - 7, y: y - 7, width: 14, height: 2))
    }
}
