// SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/)
// Осень: листопад, кучи листьев на окнах и у Dock, клён, тыквы, грабли, зонты.

import AppKit

/// Готовые картинки листьев (рисуются один раз при запуске).
enum Leaves {
    static let palette: [(CGFloat, CGFloat, CGFloat)] = [
        (0.93, 0.47, 0.08), (0.85, 0.22, 0.08), (0.98, 0.74, 0.14),
        (0.66, 0.34, 0.1), (0.78, 0.56, 0.16), (0.72, 0.14, 0.1)]

    /// Контур листа в квадрате -1…1: 0 — кленовый, 1 — овальный (берёза/липа), 2 — дубовый.
    static func shape(_ kind: Int) -> CGPath {
        let p = CGMutablePath()
        switch kind {
        case 0:
            // кленовый: пять острых лопастей
            let n = 10
            for i in 0..<(n * 2) {
                let a = CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(n)
                let lobe = i % 2 == 0
                var r: CGFloat = lobe ? 0.95 : 0.42
                if lobe && (i == 8 || i == 12) { r = 0.6 }      // нижние лопасти короче
                if !lobe && (i == 9 || i == 11) { r = 0.3 }
                let pt = CGPoint(x: cos(a) * r, y: sin(a) * r * 0.95 + 0.05)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        case 1:
            p.move(to: CGPoint(x: 0, y: 0.95))
            p.addCurve(to: CGPoint(x: 0, y: -0.8), control1: CGPoint(x: 0.75, y: 0.5), control2: CGPoint(x: 0.6, y: -0.55))
            p.addCurve(to: CGPoint(x: 0, y: 0.95), control1: CGPoint(x: -0.6, y: -0.55), control2: CGPoint(x: -0.75, y: 0.5))
            p.closeSubpath()
        default:
            // дубовый: волнистые края
            let n = 14
            for i in 0...n {
                let u = CGFloat(i) / CGFloat(n)
                let y = 0.9 - u * 1.7
                let w = sin(u * .pi) * 0.5 * (1 + 0.35 * sin(u * .pi * 7))
                let pt = CGPoint(x: w, y: y)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            for i in stride(from: n, through: 0, by: -1) {
                let u = CGFloat(i) / CGFloat(n)
                let y = 0.9 - u * 1.7
                let w = sin(u * .pi) * 0.5 * (1 + 0.35 * sin(u * .pi * 7 + 0.6))
                p.addLine(to: CGPoint(x: -w, y: y))
            }
            p.closeSubpath()
        }
        return p
    }

    static func makeSprite(kind: Int, color c: (CGFloat, CGFloat, CGFloat), px: Int = 48) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let s = CGFloat(px) * 0.46
        ctx.translateBy(x: CGFloat(px) / 2, y: CGFloat(px) / 2)
        ctx.scaleBy(x: s, y: s)
        let path = shape(kind)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [rgb(min(1, c.0 * 1.12), min(1, c.1 * 1.15), min(1, c.2 * 1.2)),
                                    rgb(c.0 * 0.72, c.1 * 0.66, c.2 * 0.6)] as CFArray,
                           locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: -0.6, y: 0.8), end: CGPoint(x: 0.6, y: -0.8), options: [])
        ctx.restoreGState()
        // прожилки и черешок
        ctx.setStrokeColor(rgb(c.0 * 0.55, c.1 * 0.45, c.2 * 0.35, 0.8))
        ctx.setLineWidth(0.06)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 0, y: -0.95)); ctx.addLine(to: CGPoint(x: 0, y: 0.75))
        for k in 0..<3 {
            let y = -0.35 + CGFloat(k) * 0.35
            ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: 0.38, y: y + 0.3))
            ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: -0.38, y: y + 0.3))
        }
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(c.0 * 0.5, c.1 * 0.4, c.2 * 0.3, 0.35))
        ctx.setLineWidth(0.04)
        ctx.strokePath()
        return ctx.makeImage()
    }

    static let sprites: [CGImage] = {
        var out: [CGImage] = []
        for (i, c) in palette.enumerated() {
            for kind in 0..<3 where (i + kind) % 2 == 0 || kind == 0 {
                if let img = makeSprite(kind: kind, color: c) { out.append(img) }
            }
        }
        return out
    }()

    /// Плитка «ковёр из листьев» — заливает кучу целиком одной операцией.
    static let tile: CGImage? = {
        let size = 256
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        var rng = SeededRandom(seed: 4242)
        let imgs = sprites
        guard !imgs.isEmpty else { return nil }
        for _ in 0..<230 {
            let x = CGFloat.random(in: -10...CGFloat(size + 10), using: &rng)
            let y = CGFloat.random(in: -10...CGFloat(size + 10), using: &rng)
            let d = CGFloat.random(in: 14...26, using: &rng)
            let img = imgs[Int.random(in: 0..<imgs.count, using: &rng)]
            ctx.saveGState()
            ctx.translateBy(x: x, y: y)
            ctx.rotate(by: CGFloat.random(in: 0...(2 * .pi), using: &rng))
            ctx.setAlpha(CGFloat.random(in: 0.75...1, using: &rng))
            ctx.draw(img, in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d))
            ctx.restoreGState()
        }
        return ctx.makeImage()
    }()
}

extension SnowView {
    var isAutumn: Bool { season == .autumn }

    /// Сезон сменился (по календарю или вручную) — перестраиваем сцену.
    func checkSeason() {
        let s = prefs.season
        guard s != season else { return }
        season = s
        clearAll()
        sleighX = nil
        sparks.removeAll()
        treeFall = 0
        rebuildTree()
        rebuildDecor()
        if s == .spring { startSpring() }
    }

    func leafSprite(_ seed: CGFloat) -> CGImage? {
        let imgs = Leaves.sprites
        guard !imgs.isEmpty else { return nil }
        return imgs[Int(abs(seed * 1000)) % imgs.count]
    }

    // MARK: - Куча листьев

    func drawLeafPile(_ ctx: CGContext, _ path: CGPath) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: rgb(0.2, 0.1, 0.02, 0.5))
        ctx.addPath(path)
        ctx.setFillColor(rgb(0.55, 0.28, 0.08))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(linGrad(rgb(0.8, 0.45, 0.12), rgb(0.42, 0.2, 0.06)),
                               start: CGPoint(x: 0, y: ground + 30), end: CGPoint(x: 0, y: ground), options: [])
        if let tile = Leaves.tile {
            ctx.draw(tile, in: CGRect(x: 0, y: ground, width: 256, height: 256), byTiling: true)
        }
        // тень у самого низа
        ctx.drawLinearGradient(linGrad(rgb(0.15, 0.07, 0.02, 0.4), rgb(0.15, 0.07, 0.02, 0)),
                               start: CGPoint(x: 0, y: ground), end: CGPoint(x: 0, y: ground + 8), options: [])
        ctx.restoreGState()
        // листья, торчащие из верхнего края кучи
        guard !heights.isEmpty else { return }
        var x: CGFloat = 4
        var i = 0
        while x < bounds.width {
            let hh = heights[index(x)]
            if hh > 1.5, let img = leafSprite(CGFloat(i) * 0.137) {
                let d: CGFloat = 13 + CGFloat((i * 7) % 6)
                ctx.saveGState()
                ctx.translateBy(x: x, y: ground + hh - 2)
                ctx.rotate(by: CGFloat(i) * 2.399)
                ctx.draw(img, in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d))
                ctx.restoreGState()
            }
            x += 11
            i += 1
        }
    }

    func fillLeafCap(_ ctx: CGContext, _ path: CGPath) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 3, color: rgb(0.2, 0.1, 0.02, 0.4))
        ctx.addPath(path)
        ctx.setFillColor(rgb(0.7, 0.36, 0.1))
        ctx.fillPath()
        ctx.restoreGState()
        if let tile = Leaves.tile {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            let bb = path.boundingBox
            ctx.draw(tile, in: CGRect(x: bb.minX, y: bb.minY, width: 128, height: 128), byTiling: true)
            ctx.restoreGState()
        }
    }

    // MARK: - Падающие и разлетающиеся листья

    func drawLeafParticles(_ ctx: CGContext) {
        for q in particles {
            guard let img = leafSprite(q.r) else { continue }
            let d = 8 + q.r * 3
            ctx.saveGState()
            ctx.translateBy(x: q.x, y: q.y)
            ctx.rotate(by: (q.x * 0.045 + q.y * 0.03) + q.r * 10)
            // лист поворачивается к нам то лицом, то ребром
            ctx.scaleBy(x: 0.35 + 0.65 * abs(sin(q.y * 0.05 + q.r * 7)), y: 1)
            ctx.draw(img, in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d))
            ctx.restoreGState()
        }
    }

    /// Пнуть кучу: листья разлетаются веером.
    func kickLeaves(at p: CGPoint, power: CGFloat, dirX: CGFloat = 0) {
        guard !heights.isEmpty, p.x >= 0, p.x < bounds.width else { return }
        let span = 8 + 10 * power
        var taken: CGFloat = 0
        for k in index(p.x - span)...index(p.x + span) {
            let tk = min(heights[k], 3.5 * power)
            heights[k] -= tk
            taken += tk
        }
        let n = min(40, Int(taken * 0.9) + Int(4 * power))
        for _ in 0..<n where particles.count < 1500 {
            particles.append(Particle(x: p.x + CGFloat.random(in: -span...span), y: surface(p.x) + 2,
                                      vx: dirX * CGFloat.random(in: 0.5...1.2) + CGFloat.random(in: -2.5...2.5) * power,
                                      vy: CGFloat.random(in: 2.5...6.5) * power,
                                      r: CGFloat.random(in: 1.5...4)))
        }
    }

    /// Машина осенью: колёса подкидывают листья позади себя.
    func carKickLeaves(x: CGFloat, d: CGFloat) {
        guard !heights.isEmpty else { return }
        if isSpring {
            // брызги из луж под колёсами
            for p in puddles where abs(p.x - x) < p.w * 0.5 + 20 && particles.count < 1500 {
                for _ in 0..<3 {
                    particles.append(Particle(x: x + CGFloat.random(in: -20...60) * d, y: ground + 3,
                                              vx: -d * CGFloat.random(in: 0.5...3), vy: CGFloat.random(in: 2...5), r: 0.8))
                }
            }
        }
        for off in stride(from: CGFloat(-40), through: 110, by: col) {
            let px = x + off * carScale * d
            guard px >= 0, px < bounds.width else { continue }
            let k = index(px)
            guard heights[k] > 1.5 else { continue }
            let take = heights[k] * 0.35
            heights[k] -= take
            if CGFloat.random(in: 0...1) < take * 0.5 && particles.count < 1500 {
                particles.append(Particle(x: px, y: ground + heights[k] + 2,
                                          vx: -d * CGFloat.random(in: 1...4), vy: CGFloat.random(in: 2...5),
                                          r: isSpring ? CGFloat.random(in: 1.05...1.4) : CGFloat.random(in: 1.5...3.5)))
            }
        }
    }

    /// Охапка листьев сверху (кнопка в настройках).
    func leafShower() {
        let w = bounds.width
        for _ in 0..<120 where particles.count < 1500 {
            particles.append(Particle(x: CGFloat.random(in: 0...w), y: ceiling + CGFloat.random(in: 0...120),
                                      vx: CGFloat.random(in: -1...1), vy: CGFloat.random(in: -1...0),
                                      r: CGFloat.random(in: 1.5...4)))
        }
    }

    /// Осенние мелочи каждый кадр: клён роняет листья.
    func autumnStep() {
        guard isAutumn, treeStanding, snowing else { return }
        let H = treeHeightPt
        if CGFloat.random(in: 0...1) < 0.025 * CGFloat(prefs.leafAmount) + 0.004 && particles.count < 1500 {
            particles.append(Particle(x: treeX + CGFloat.random(in: -H * 0.3...H * 0.3),
                                      y: ground + H * CGFloat.random(in: 0.45...0.85),
                                      vx: CGFloat.random(in: -0.6...0.6), vy: 0,
                                      r: CGFloat.random(in: 1.5...3.5)))
        }
    }

    // MARK: - Клён

    func drawMapleBody(_ ctx: CGContext, H: CGFloat, rng: inout SeededRandom) {
        // ствол и ветви
        let bark = rgb(0.32, 0.2, 0.13)
        let trunk = CGMutablePath()
        trunk.move(to: CGPoint(x: -H * 0.05, y: 0))
        trunk.addQuadCurve(to: CGPoint(x: -H * 0.025, y: H * 0.5), control: CGPoint(x: -H * 0.02, y: H * 0.2))
        trunk.addLine(to: CGPoint(x: H * 0.025, y: H * 0.5))
        trunk.addQuadCurve(to: CGPoint(x: H * 0.05, y: 0), control: CGPoint(x: H * 0.02, y: H * 0.2))
        trunk.closeSubpath()
        ctx.addPath(trunk)
        ctx.setFillColor(bark)
        ctx.fillPath()
        ctx.setStrokeColor(bark)
        ctx.setLineCap(.round)
        for (a, len, w) in [(-0.9, 0.3, 0.025), (0.8, 0.28, 0.022), (-0.3, 0.32, 0.02), (0.35, 0.3, 0.02), (-1.3, 0.2, 0.015), (1.2, 0.22, 0.015)] as [(CGFloat, CGFloat, CGFloat)] {
            let base = CGPoint(x: 0, y: H * (0.38 + abs(a) * 0.06))
            ctx.setLineWidth(H * w)
            ctx.move(to: base)
            ctx.addLine(to: CGPoint(x: base.x + sin(a) * H * len, y: base.y + cos(a) * H * len))
            ctx.strokePath()
        }
        // крона из десятков кругов: снизу темнее, сверху освещена
        let cy = H * 0.66, rx = H * 0.36, ry = H * 0.3
        let pal = Leaves.palette
        var blobs: [(CGPoint, CGFloat, Int)] = []
        for _ in 0..<70 {
            let a = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let d = sqrt(CGFloat.random(in: 0...1, using: &rng))
            let c = CGPoint(x: cos(a) * rx * d, y: cy + sin(a) * ry * d)
            blobs.append((c, H * CGFloat.random(in: 0.07...0.12, using: &rng), Int.random(in: 0..<pal.count, using: &rng)))
        }
        blobs.sort { $0.0.y < $1.0.y }
        for (c, r, ci) in blobs {
            let col = pal[ci]
            let light = 0.75 + 0.35 * (c.y - (cy - ry)) / (2 * ry)
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(min(1, col.0 * light * 1.1), min(1, col.1 * light * 1.1), col.2 * light),
                                           rgb(col.0 * light * 0.65, col.1 * light * 0.6, col.2 * light * 0.55)),
                                   start: CGPoint(x: c.x - r * 0.4, y: c.y + r), end: CGPoint(x: c.x + r * 0.3, y: c.y - r), options: [])
            ctx.restoreGState()
        }
        // отдельные листья по краю кроны
        let imgs = Leaves.sprites
        if !imgs.isEmpty {
            for _ in 0..<40 {
                let a = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                let c = CGPoint(x: cos(a) * rx * 1.02, y: cy + sin(a) * ry * 1.02)
                let d = H * CGFloat.random(in: 0.05...0.08, using: &rng)
                ctx.saveGState()
                ctx.translateBy(x: c.x, y: c.y)
                ctx.rotate(by: CGFloat.random(in: 0...(2 * .pi), using: &rng))
                ctx.draw(imgs[Int.random(in: 0..<imgs.count, using: &rng)], in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d))
                ctx.restoreGState()
            }
        }
        // ковёр листьев у ствола
        ctx.setFillColor(rgb(0.75, 0.38, 0.1, 0.9))
        ctx.fillEllipse(in: CGRect(x: -H * 0.2, y: -3, width: H * 0.4, height: 7))
    }

    // MARK: - Тыквы у домиков

    func drawPumpkins(_ ctx: CGContext) -> [CGRect] {
        var glows: [CGRect] = []
        for (x, r, face) in [(8.0, 7.5, true), (22.0, 5.5, false), (31.0, 4.2, false)] as [(CGFloat, CGFloat, Bool)] {
            let c = CGPoint(x: x, y: r * 0.9)
            for k in -1...1 {
                let rect = CGRect(x: c.x - r * 0.55 + CGFloat(k) * r * 0.42, y: c.y - r * 0.85, width: r * 1.1, height: r * 1.7)
                ctx.saveGState()
                ctx.addEllipse(in: rect)
                ctx.clip()
                ctx.drawLinearGradient(linGrad(rgb(1, 0.6, 0.12), rgb(0.78, 0.32, 0.03)),
                                       start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
                ctx.restoreGState()
            }
            ctx.setFillColor(rgb(0.3, 0.38, 0.12))
            ctx.fill(CGRect(x: c.x - 1, y: c.y + r * 0.75, width: 2, height: r * 0.45))
            if face {
                ctx.setFillColor(rgb(0.25, 0.1, 0.02))
                for ex in [-2.6, 2.6] as [CGFloat] {
                    ctx.move(to: CGPoint(x: c.x + ex - 1.4, y: c.y + 0.8))
                    ctx.addLine(to: CGPoint(x: c.x + ex + 1.4, y: c.y + 0.8))
                    ctx.addLine(to: CGPoint(x: c.x + ex, y: c.y + 3))
                    ctx.closePath(); ctx.fillPath()
                }
                let mouth = CGRect(x: c.x - 3.5, y: c.y - 3.2, width: 7, height: 2.4)
                ctx.fillEllipse(in: mouth)
                glows.append(mouth)
                glows.append(CGRect(x: c.x - 2.6 - 1, y: c.y + 1, width: 2, height: 1.6))
                glows.append(CGRect(x: c.x + 2.6 - 1, y: c.y + 1, width: 2, height: 1.6))
            }
        }
        return glows
    }

    // MARK: - Грабли и зонт

    func drawRake(_ ctx: CGContext, _ a: Walker) {
        let wood = rgb(0.55, 0.38, 0.2)
        let steel = rgb(0.35, 0.37, 0.4)
        if a.state == 1 {
            let sw = sin(a.timer * 0.18)
            let top = CGPoint(x: -2, y: 38)
            let end = CGPoint(x: 20 + sw * 7, y: 2)
            line(ctx, top, end, 2, wood)
            ctx.setStrokeColor(steel)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: end.x, y: end.y + 5)); ctx.addLine(to: CGPoint(x: end.x, y: end.y - 5))
            for k in 0..<5 {
                let yy = end.y - 4.5 + CGFloat(k) * 2.2
                ctx.move(to: CGPoint(x: end.x, y: yy)); ctx.addLine(to: CGPoint(x: end.x + 3, y: yy - 1.2))
            }
            ctx.strokePath()
            // горка собранных листьев перед граблями
            if let img = leafSprite(0.31) {
                ctx.draw(img, in: CGRect(x: end.x + 2, y: -2, width: 9, height: 9))
            }
        } else {
            line(ctx, CGPoint(x: -12, y: 58), CGPoint(x: 8, y: 30), 2, wood)
            ctx.setStrokeColor(steel)
            ctx.setLineWidth(1.1)
            ctx.move(to: CGPoint(x: -17, y: 55)); ctx.addLine(to: CGPoint(x: -8, y: 62))
            ctx.strokePath()
        }
    }

    func drawUmbrella(_ ctx: CGContext, _ a: Walker) {
        let hand = CGPoint(x: 6, y: 40)
        let topY: CGFloat = 76
        line(ctx, hand, CGPoint(x: 4, y: topY), 1.4, rgb(0.2, 0.2, 0.22))
        let canopy = CGMutablePath()
        canopy.move(to: CGPoint(x: 4 - 19, y: topY - 6))
        canopy.addQuadCurve(to: CGPoint(x: 4 + 19, y: topY - 6), control: CGPoint(x: 4, y: topY + 16))
        // зубчатый нижний край
        for k in 0..<4 {
            let x0 = 4 + 19 - CGFloat(k) * 9.5
            canopy.addQuadCurve(to: CGPoint(x: x0 - 9.5, y: topY - 6), control: CGPoint(x: x0 - 4.75, y: topY - 3))
        }
        canopy.closeSubpath()
        ctx.saveGState()
        ctx.addPath(canopy)
        ctx.clip()
        ctx.drawLinearGradient(linGrad(rgb(a.c2.0 * 1.1, a.c2.1 * 1.1, a.c2.2 * 1.1), rgb(a.c2.0 * 0.6, a.c2.1 * 0.6, a.c2.2 * 0.6)),
                               start: CGPoint(x: 0, y: topY + 10), end: CGPoint(x: 0, y: topY - 6), options: [])
        ctx.restoreGState()
        // ручка-крючок
        ctx.setStrokeColor(rgb(0.25, 0.15, 0.08))
        ctx.setLineWidth(1.6)
        ctx.addArc(center: CGPoint(x: 6 + 2, y: hand.y), radius: 2, startAngle: .pi, endAngle: 0, clockwise: true)
        ctx.strokePath()
    }

    /// Ребёнок подкидывает охапку листьев в сторону другого.
    func tossLeaves(from a: Walker, to o: Walker) {
        let sx = a.x + a.dir * 8 * a.scale
        let sy = surface(a.x) + 40 * a.scale
        for _ in 0..<10 where particles.count < 1500 {
            particles.append(Particle(x: sx, y: sy, vx: (o.x - sx) / CGFloat.random(in: 60...120),
                                      vy: CGFloat.random(in: 3...6), r: CGFloat.random(in: 1.5...3.5)))
        }
        if let k = heights.indices.contains(index(a.x)) ? index(a.x) : nil { heights[k] = max(0, heights[k] - 2) }
    }
}
