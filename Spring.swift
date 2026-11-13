// SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/)
// Весна: тающий снег, капель, лужи, лепестки цветущей вишни, птицы на окнах,
// стая птиц в небе, воздушный змей, первоцветы у Dock.

import AppKit

struct Bird {
    var x, y, vx, vy, phase: CGFloat
    var tx, ty: CGFloat
    var perched = false
    var perchWin: UInt32? = nil
    var perchDX: CGFloat = 0
    var timer: CGFloat = 0
    var leaving = false
    var hop: CGFloat = 0
}
struct Puddle { var x, w: CGFloat }
struct Ripple { var x, y, r, life: CGFloat }

/// Лепестки цветущей вишни/яблони.
enum Petals {
    static let palette: [(CGFloat, CGFloat, CGFloat)] = [(1, 0.78, 0.86), (1, 0.9, 0.94), (0.98, 0.66, 0.8), (1, 0.97, 0.98)]

    static func makeSprite(_ c: (CGFloat, CGFloat, CGFloat), px: Int = 40) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let s = CGFloat(px) * 0.45
        ctx.translateBy(x: CGFloat(px) / 2, y: CGFloat(px) / 2)
        ctx.scaleBy(x: s, y: s)
        // лепесток с выемкой на конце
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -0.95))
        p.addCurve(to: CGPoint(x: 0.12, y: 0.85), control1: CGPoint(x: 0.75, y: -0.4), control2: CGPoint(x: 0.7, y: 0.75))
        p.addLine(to: CGPoint(x: 0, y: 0.62))
        p.addLine(to: CGPoint(x: -0.12, y: 0.85))
        p.addCurve(to: CGPoint(x: 0, y: -0.95), control1: CGPoint(x: -0.7, y: 0.75), control2: CGPoint(x: -0.75, y: -0.4))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.clip()
        ctx.drawLinearGradient(linGrad(rgb(c.0, c.1 * 0.92, c.2 * 0.95), rgb(min(1, c.0 * 1.02), min(1, c.1 * 1.08), min(1, c.2 * 1.04))),
                               start: CGPoint(x: 0, y: -1), end: CGPoint(x: 0, y: 1), options: [])
        return ctx.makeImage()
    }

    static let sprites: [CGImage] = palette.compactMap { makeSprite($0) }
}

extension SnowView {
    var isSpring: Bool { season == .spring }

    /// Начало весны: остатки зимнего снега, лужи.
    func startSpring() {
        guard !heights.isEmpty else { return }
        var phase = CGFloat.random(in: 0...10)
        for k in heights.indices {
            phase += 0.02
            heights[k] = max(0, 9 + sin(phase) * 5 + sin(phase * 3.1) * 3)
        }
        let w = bounds.width
        puddles = (0..<6).map { i in
            Puddle(x: w * (0.1 + CGFloat(i) * 0.15) + CGFloat.random(in: -40...40), w: CGFloat.random(in: 50...110))
        }
        for (id, var c) in caps {
            for k in c.h.indices { c.h[k] = min(capCapacity(c, k), 5) }
            caps[id] = c
        }
    }

    func petalSprite(_ seed: CGFloat) -> CGImage? {
        let s = Petals.sprites
        guard !s.isEmpty else { return nil }
        return s[Int(abs(seed * 1000)) % s.count]
    }

    // MARK: - Шаг весны

    func springStep() {
        guard isSpring else {
            if !birds.isEmpty || !ripples.isEmpty { birds.removeAll(); ripples.removeAll() }
            return
        }
        let w = bounds.width
        // таяние раз в 6 кадров
        if Int(t * 60) % 6 == 0 {
            let melt = CGFloat(0.004 + 0.03 * prefs.meltSpeed) * (nightLevel > 0.6 ? 0.3 : 1)
            for k in heights.indices where heights[k] > 0 {
                heights[k] = max(0, heights[k] - melt * CGFloat.random(in: 0.5...1.5))
            }
            for (id, var c) in caps {
                var any = false
                for k in c.h.indices where c.h[k] > 0 {
                    c.h[k] = max(0, c.h[k] - melt * 0.8)
                    any = true
                }
                // капель с краёв окна, пока на нём есть снег
                if any && CGFloat.random(in: 0...1) < 0.35 && particles.count < 1200 {
                    let left = Bool.random()
                    let x = left ? c.rect.minX + 2 : c.rect.maxX - 2
                    particles.append(Particle(x: x, y: c.rect.maxY - c.radius, vx: 0, vy: -0.5, r: 0.8))
                }
                caps[id] = c
            }
        }
        // дождь: круги на лужах
        if prefs.rain && !puddles.isEmpty && CGFloat.random(in: 0...1) < CGFloat(prefs.rainAmount) * 0.5 {
            if let p = puddles.randomElement() {
                ripples.append(Ripple(x: p.x + CGFloat.random(in: -p.w * 0.4...p.w * 0.4), y: ground + 3, r: 1, life: 1))
            }
        }
        var i = 0
        while i < ripples.count {
            ripples[i].r += 0.35
            ripples[i].life -= 0.025
            if ripples[i].life <= 0 { ripples.remove(at: i); continue }
            i += 1
        }
        // лепестки с цветущего дерева
        if treeStanding && snowing && CGFloat.random(in: 0...1) < 0.03 * CGFloat(prefs.petalAmount) + 0.006 && particles.count < 1500 {
            let H = treeHeightPt
            particles.append(Particle(x: treeX + CGFloat.random(in: -H * 0.3...H * 0.3), y: ground + H * CGFloat.random(in: 0.45...0.85),
                                      vx: CGFloat.random(in: -0.5...0.5), vy: 0, r: CGFloat.random(in: 1.5...3)))
        }
        birdStep(w)
    }

    // MARK: - Птицы

    func birdTarget() -> (CGFloat, CGFloat, UInt32?, CGFloat) {
        // садимся на верх окна или на траву у Dock
        if Bool.random(), let wr = winRects.filter({ $0.rect.width > 160 }).randomElement() {
            let dx = CGFloat.random(in: 30...(wr.rect.width - 30))
            return (wr.rect.minX + dx, wr.rect.maxY, wr.id, dx)
        }
        return (CGFloat.random(in: 60...max(61, bounds.width - 60)), ground + 4, nil, 0)
    }

    func birdStep(_ w: CGFloat) {
        let want = prefs.birds && nightLevel < 0.55 ? 4 : 0
        let active = birds.filter { !$0.leaving }.count
        if active < want && CGFloat.random(in: 0...1) < 0.004 {
            let left = Bool.random()
            let tg = birdTarget()
            birds.append(Bird(x: left ? -20 : w + 20, y: ceiling - CGFloat.random(in: 40...200), vx: 0, vy: 0,
                              phase: CGFloat.random(in: 0...6), tx: tg.0, ty: tg.1, perchWin: tg.2, perchDX: tg.3))
        }
        if active > want, let k = birds.firstIndex(where: { !$0.leaving }) { flyAway(k) }
        var i = 0
        while i < birds.count {
            var b = birds[i]
            if b.perched {
                b.timer -= 1
                // окно уехало или закрылось — взлетаем
                if let id = b.perchWin {
                    if let wr = winRects.first(where: { $0.id == id }) {
                        b.x = wr.rect.minX + b.perchDX
                        b.y = wr.rect.maxY + (caps[id]?.h[max(0, min((caps[id]?.h.count ?? 1) - 1, Int(b.perchDX / col)))] ?? 0)
                    } else { b.perched = false; b.leaving = true; b.tx = b.x < w / 2 ? -80 : w + 80; b.ty = ceiling }
                }
                // прыжки на месте
                if b.hop <= 0 && CGFloat.random(in: 0...1) < 0.01 { b.hop = 1 }
                if b.hop > 0 { b.hop = max(0, b.hop - 0.08) }
                let near = hypot(mouse.x - b.x, mouse.y - b.y) < 80
                if near || b.timer <= 0 {
                    b.perched = false
                    if near || CGFloat.random(in: 0...1) < 0.35 {
                        b.leaving = true
                        b.tx = b.x < w / 2 ? -80 : w + 80
                        b.ty = ceiling + 40
                    } else {
                        let tg = birdTarget()
                        b.tx = tg.0; b.ty = tg.1; b.perchWin = tg.2; b.perchDX = tg.3
                    }
                    b.vy = 2.5
                }
            } else {
                let dx = b.tx - b.x, dy = b.ty - b.y
                let d = max(1, hypot(dx, dy))
                let sp: CGFloat = 3.2
                b.vx += (dx / d * sp - b.vx) * 0.06
                b.vy += (dy / d * sp - b.vy) * 0.06 + sin(b.phase * 0.4) * 0.05
                b.x += b.vx
                b.y += b.vy
                b.phase += 0.7
                if !b.leaving && d < 5 {
                    b.perched = true
                    b.timer = CGFloat.random(in: 300...900)
                    b.vx = 0; b.vy = 0
                }
                if b.leaving && (b.x < -40 || b.x > w + 40 || b.y > ceiling + 30) { birds.remove(at: i); continue }
            }
            birds[i] = b
            i += 1
        }
    }

    func flyAway(_ k: Int) {
        birds[k].perched = false
        birds[k].leaving = true
        birds[k].tx = birds[k].x < bounds.width / 2 ? -80 : bounds.width + 80
        birds[k].ty = ceiling + 40
    }

    func drawBird(_ ctx: CGContext, x: CGFloat, y: CGFloat, dir: CGFloat, flap: CGFloat?, scale: CGFloat = 1) {
        ctx.saveGState()
        ctx.translateBy(x: x, y: y)
        ctx.scaleBy(x: dir < 0 ? -scale : scale, y: scale)
        let body = rgb(0.42, 0.3, 0.2)
        let belly = rgb(0.78, 0.68, 0.55)
        // хвост
        ctx.setFillColor(body)
        ctx.move(to: CGPoint(x: -5, y: 4)); ctx.addLine(to: CGPoint(x: -11, y: 7)); ctx.addLine(to: CGPoint(x: -10, y: 3))
        ctx.closePath(); ctx.fillPath()
        ctx.fillEllipse(in: CGRect(x: -6, y: 1, width: 11, height: 7.5))
        ctx.setFillColor(belly)
        ctx.fillEllipse(in: CGRect(x: -3, y: 1, width: 7, height: 4))
        ctx.setFillColor(body)
        ctx.fillEllipse(in: CGRect(x: 2.5, y: 5, width: 5.5, height: 5.5))
        ctx.setFillColor(rgb(0.95, 0.75, 0.3))
        ctx.move(to: CGPoint(x: 7.6, y: 7.8)); ctx.addLine(to: CGPoint(x: 10, y: 7.2)); ctx.addLine(to: CGPoint(x: 7.6, y: 6.6))
        ctx.closePath(); ctx.fillPath()
        ctx.setFillColor(rgb(0.05, 0.05, 0.05))
        ctx.fillEllipse(in: CGRect(x: 5.4, y: 7.6, width: 1.2, height: 1.2))
        // крыло: в полёте машет
        ctx.setFillColor(rgb(0.32, 0.22, 0.14))
        if let f = flap {
            let up = sin(f)
            ctx.move(to: CGPoint(x: -3, y: 6)); ctx.addLine(to: CGPoint(x: 3, y: 6))
            ctx.addLine(to: CGPoint(x: -1, y: 6 + up * 9)); ctx.closePath(); ctx.fillPath()
        } else {
            ctx.fillEllipse(in: CGRect(x: -4, y: 3, width: 7, height: 4))
            // лапки
            ctx.setStrokeColor(rgb(0.3, 0.2, 0.12))
            ctx.setLineWidth(0.8)
            ctx.move(to: CGPoint(x: -1, y: 1.5)); ctx.addLine(to: CGPoint(x: -1, y: -1))
            ctx.move(to: CGPoint(x: 1.5, y: 1.5)); ctx.addLine(to: CGPoint(x: 1.5, y: -1))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    func drawBirds(_ ctx: CGContext) {
        for b in birds {
            let dir: CGFloat = b.perched ? (Int(b.timer / 120) % 2 == 0 ? 1 : -1) : (b.vx >= 0 ? 1 : -1)
            drawBird(ctx, x: b.x, y: b.y + 1 + sin(b.hop * .pi) * 4, dir: dir, flap: b.perched ? nil : b.phase)
        }
    }

    /// Стая птиц клином — весной пролетает вместо саней.
    func drawFlock(_ ctx: CGContext) {
        guard let sx = sleighX else { return }
        let y = sleighY
        for k in 0..<9 {
            let side: CGFloat = k % 2 == 0 ? 1 : -1
            let n = CGFloat((k + 1) / 2)
            let bx = sx + n * 22
            let by = y + side * n * 12
            drawBird(ctx, x: bx, y: by, dir: -1, flap: t * 9 + CGFloat(k), scale: 0.8)
        }
    }

    // MARK: - Лужи и брызги

    func puddleLevel() -> CGFloat {
        let snow = averageSnow
        return max(0.25, min(1, 1.1 - snow / 10)) * (prefs.rain ? 1.15 : 1)
    }

    func drawPuddles(_ ctx: CGContext) {
        let lv = puddleLevel()
        for p in puddles {
            let w = p.w * lv
            let r = CGRect(x: p.x - w / 2, y: ground - 1, width: w, height: 7 * lv)
            ctx.saveGState()
            ctx.addEllipse(in: r)
            ctx.clip()
            let day = 1 - nightLevel
            ctx.drawLinearGradient(linGrad(rgb(0.55 + 0.25 * day, 0.68 + 0.2 * day, 0.85, 0.85), rgb(0.25, 0.35, 0.5, 0.85)),
                                   start: CGPoint(x: 0, y: r.maxY), end: CGPoint(x: 0, y: r.minY), options: [])
            ctx.setFillColor(rgb(1, 1, 1, 0.35))
            ctx.fill(CGRect(x: r.minX + w * 0.2, y: r.midY + 0.5, width: w * 0.35, height: 0.8))
            ctx.restoreGState()
        }
        for rp in ripples {
            ctx.setStrokeColor(rgb(1, 1, 1, rp.life * 0.6))
            ctx.setLineWidth(0.8)
            ctx.strokeEllipse(in: CGRect(x: rp.x - rp.r, y: rp.y - rp.r * 0.3, width: rp.r * 2, height: rp.r * 0.6))
        }
    }

    /// Клик весной: по снегу — комья мокрого снега, по траве или луже — брызги и круги.
    func springSplash(at p: CGPoint) {
        guard !heights.isEmpty, p.x >= 0, p.x < bounds.width else { return }
        let hh = heights[index(p.x)]
        if hh > 2 {
            for k in index(p.x - 12)...index(p.x + 12) { heights[k] = max(0, heights[k] - 2.5) }
            for _ in 0..<10 where particles.count < 1500 {
                particles.append(Particle(x: p.x + .random(in: -8...8), y: surface(p.x) + 2,
                                          vx: .random(in: -2.5...2.5), vy: .random(in: 2...5), r: .random(in: 1.05...1.4)))
            }
        }
        for _ in 0..<12 where particles.count < 1500 {
            particles.append(Particle(x: p.x, y: max(p.y, ground + 2), vx: .random(in: -2...2), vy: .random(in: 1.5...4), r: 0.75))
        }
        ripples.append(Ripple(x: p.x, y: ground + 3, r: 2, life: 1))
        for k in birds.indices where hypot(birds[k].x - p.x, birds[k].y - p.y) < 200 { flyAway(k) }
    }

    func drawSpringParticles(_ ctx: CGContext) {
        for q in particles {
            if q.r < 1 {
                // капля
                ctx.setFillColor(rgb(0.7, 0.82, 0.95, 0.85))
                ctx.fillEllipse(in: CGRect(x: q.x - 1, y: q.y - 1.8, width: 2, height: 3.6))
            } else if q.r < 1.45 {
                // комок мокрого снега
                let d = q.r * 4
                ctx.setFillColor(rgb(0.93, 0.95, 0.98))
                ctx.fillEllipse(in: CGRect(x: q.x - d / 2, y: q.y - d / 2, width: d, height: d))
            } else if let img = petalSprite(q.r) {
                let d = 4 + q.r * 2.6
                ctx.saveGState()
                ctx.translateBy(x: q.x, y: q.y)
                ctx.rotate(by: q.x * 0.05 + q.y * 0.04 + q.r * 9)
                ctx.scaleBy(x: 0.4 + 0.6 * abs(sin(q.y * 0.06 + q.r * 5)), y: 1)
                ctx.draw(img, in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d))
                ctx.restoreGState()
            }
        }
    }

    // MARK: - Воздушный змей

    func drawKite(_ ctx: CGContext, hand: CGPoint) {
        let k = CGPoint(x: hand.x - 40 + sin(t * 1.1) * 8, y: hand.y + 120 + sin(t * 1.7) * 6)
        ctx.setStrokeColor(rgb(0.95, 0.95, 0.95, 0.8))
        ctx.setLineWidth(0.6)
        ctx.move(to: hand)
        ctx.addQuadCurve(to: k, control: CGPoint(x: hand.x - 5, y: hand.y + 50))
        ctx.strokePath()
        let kite = CGMutablePath()
        kite.move(to: CGPoint(x: k.x, y: k.y + 16))
        kite.addLine(to: CGPoint(x: k.x + 10, y: k.y + 2))
        kite.addLine(to: CGPoint(x: k.x, y: k.y - 12))
        kite.addLine(to: CGPoint(x: k.x - 10, y: k.y + 2))
        kite.closeSubpath()
        ctx.addPath(kite)
        ctx.setFillColor(rgb(0.95, 0.25, 0.2))
        ctx.fillPath()
        ctx.setFillColor(rgb(1, 0.85, 0.2))
        ctx.move(to: CGPoint(x: k.x, y: k.y + 16)); ctx.addLine(to: CGPoint(x: k.x + 10, y: k.y + 2)); ctx.addLine(to: CGPoint(x: k.x, y: k.y + 2))
        ctx.closePath(); ctx.fillPath()
        ctx.move(to: CGPoint(x: k.x, y: k.y - 12)); ctx.addLine(to: CGPoint(x: k.x - 10, y: k.y + 2)); ctx.addLine(to: CGPoint(x: k.x, y: k.y + 2))
        ctx.closePath(); ctx.fillPath()
        // хвост с бантиками
        ctx.setStrokeColor(rgb(0.3, 0.3, 0.35))
        ctx.setLineWidth(0.6)
        var p = CGPoint(x: k.x, y: k.y - 12)
        ctx.move(to: p)
        for i in 1...6 {
            p = CGPoint(x: k.x + sin(t * 3 + CGFloat(i)) * 4 + CGFloat(i) * 2, y: k.y - 12 - CGFloat(i) * 6)
            ctx.addLine(to: p)
        }
        ctx.strokePath()
        for i in [2, 4, 6] {
            let bp = CGPoint(x: k.x + sin(t * 3 + CGFloat(i)) * 4 + CGFloat(i) * 2, y: k.y - 12 - CGFloat(i) * 6)
            ctx.setFillColor(i % 4 == 0 ? rgb(0.2, 0.5, 0.95) : rgb(0.95, 0.85, 0.2))
            ctx.fillEllipse(in: CGRect(x: bp.x - 2, y: bp.y - 1.2, width: 4, height: 2.4))
        }
    }

    // MARK: - Цветущее дерево

    func drawBlossomBody(_ ctx: CGContext, H: CGFloat, rng: inout SeededRandom) {
        let bark = rgb(0.3, 0.2, 0.16)
        let trunk = CGMutablePath()
        trunk.move(to: CGPoint(x: -H * 0.05, y: 0))
        trunk.addQuadCurve(to: CGPoint(x: -H * 0.025, y: H * 0.45), control: CGPoint(x: -H * 0.015, y: H * 0.2))
        trunk.addLine(to: CGPoint(x: H * 0.025, y: H * 0.45))
        trunk.addQuadCurve(to: CGPoint(x: H * 0.05, y: 0), control: CGPoint(x: H * 0.02, y: H * 0.2))
        trunk.closeSubpath()
        ctx.addPath(trunk)
        ctx.setFillColor(bark)
        ctx.fillPath()
        ctx.setStrokeColor(bark)
        ctx.setLineCap(.round)
        for (a, len, w) in [(-1.0, 0.33, 0.022), (0.9, 0.32, 0.02), (-0.4, 0.33, 0.018), (0.35, 0.34, 0.018), (0.0, 0.3, 0.016)] as [(CGFloat, CGFloat, CGFloat)] {
            let base = CGPoint(x: 0, y: H * 0.38)
            ctx.setLineWidth(H * w)
            ctx.move(to: base)
            ctx.addLine(to: CGPoint(x: sin(a) * H * len, y: base.y + cos(a) * H * len))
            ctx.strokePath()
        }
        // крона — облако цветов: розовые, белые и немного молодой листвы
        let cy = H * 0.66, rx = H * 0.37, ry = H * 0.29
        var blobs: [(CGPoint, CGFloat, Int)] = []
        for _ in 0..<80 {
            let a = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let d = sqrt(CGFloat.random(in: 0...1, using: &rng))
            blobs.append((CGPoint(x: cos(a) * rx * d, y: cy + sin(a) * ry * d), H * CGFloat.random(in: 0.06...0.11, using: &rng),
                          Int.random(in: 0..<10, using: &rng)))
        }
        blobs.sort { $0.0.y < $1.0.y }
        for (c, r, kind) in blobs {
            let light = 0.82 + 0.25 * (c.y - (cy - ry)) / (2 * ry)
            let col: (CGFloat, CGFloat, CGFloat) = kind < 5 ? (1, 0.74, 0.84) : (kind < 8 ? (1, 0.93, 0.95) : (0.55, 0.78, 0.4))
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(min(1, col.0 * light), min(1, col.1 * light), min(1, col.2 * light)),
                                           rgb(col.0 * light * 0.78, col.1 * light * 0.7, col.2 * light * 0.75)),
                                   start: CGPoint(x: c.x - r * 0.4, y: c.y + r), end: CGPoint(x: c.x + r * 0.3, y: c.y - r), options: [])
            ctx.restoreGState()
        }
        // отдельные цветочки
        for _ in 0..<60 {
            let a = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let d = sqrt(CGFloat.random(in: 0...1.05, using: &rng))
            let c = CGPoint(x: cos(a) * rx * d, y: cy + sin(a) * ry * d)
            ctx.setFillColor(rgb(1, 1, 1, 0.9))
            ctx.fillEllipse(in: CGRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.2, height: 3.2))
            ctx.setFillColor(rgb(0.95, 0.45, 0.6))
            ctx.fillEllipse(in: CGRect(x: c.x - 0.6, y: c.y - 0.6, width: 1.2, height: 1.2))
        }
    }
}
