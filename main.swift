// SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/)
// SnowDesk — снег на рабочем столе: сугробы на Dock, снежки, снеговики и джип со снегоуборочным отвалом.
// Сборка: bash build.sh

import AppKit
import SwiftUI

struct Flake { var x, y, vy, r, phase, alpha, z: CGFloat }
struct Glint { var x, phase, depth: CGFloat }
struct Particle { var x, y, vx, vy, r: CGFloat }
struct Spark { var x, y, vx, vy, life: CGFloat }
struct Snowball { var x, y, vx, vy, r: CGFloat; var owner: Int = -1 }
struct Snowman {
    var x: CGFloat
    var radii: [CGFloat]     // комья снизу вверх
    var progress: CGFloat    // анимация автолепки, 1 = готов
}

final class SnowView: NSView {
    var flakes: [Flake] = []
    var particles: [Particle] = []
    var snowballs: [Snowball] = []
    var heights: [CGFloat] = []
    var snowmen: [Snowman] = []
    let col: CGFloat = 3
    let maxHeight: CGFloat = 30
    let carScale: CGFloat = 0.68
    var ground: CGFloat = 0
    var wind: CGFloat = 0
    var windTarget: CGFloat = 0
    var gustLeft: CGFloat = 0
    var snowing = true
    var shovel = false
    var playEnabled = true
    var garland = true
    var garlandAuto = true
    var nightLevel: CGFloat = 1
    var ceiling: CGFloat = 0
    var sleighX: CGFloat? = nil
    var sleighBase: CGFloat = 0
    var sparks: [Spark] = []
    var tractorX: CGFloat? = nil
    var tractorDir: CGFloat = 1
    var nextDir: CGFloat = 1
    var tractorLoad: CGFloat = 0
    var lastBlade: CGFloat = 0
    var t: CGFloat = 0
    var mouse = CGPoint(x: -1000, y: -1000)
    var held: Snowball? = nil
    var samples: [(CGPoint, TimeInterval)] = []

    // мир: окна, ёлка, домики, персонажи
    let prefs = Prefs.shared
    var prefsVersion = -1
    var winRects: [(id: UInt32, rect: CGRect, owner: String)] = []
    var ropes: [String: Rope] = [:]
    var selectedJoint: Int? = nil
    var jointWin: [Int: UInt32] = [:]
    var lastMouse = CGPoint.zero
    var widgetLayer = Int(Int32.min)
    var depositTick = 0
    var winQueryBusy = false
    var season: Season = .winter
    var butterflies: [Butterfly] = []
    var fireflies: [Firefly] = []
    var bubbles: [Bubble] = []
    var grassImage: CGImage? = nil
    var grassFor = CGSize.zero
    var grassSeason: Season = .winter
    var birds: [Bird] = []
    var puddles: [Puddle] = []
    var ripples: [Ripple] = []
    var mouseVel = CGPoint.zero
    var caps: [UInt32: WindowCap] = [:]
    var walkers: [Walker] = []
    var nextWalkerID = 1
    var treeImage: CGImage? = nil
    var treeLights: [CGPoint] = []
    var treeFall: CGFloat = 0
    var treeFallDir: CGFloat = 1
    var treeGoneTimer: CGFloat = 0
    var treeAppear: CGFloat = 1
    var decorLeft: CGImage? = nil
    var decorRight: CGImage? = nil
    var decorGlowsL: [CGRect] = []
    var decorGlowsR: [CGRect] = []
    var decorSizeL = CGSize.zero
    var decorSizeR = CGSize.zero
    var dragJoint: Int? = nil
    var renderScale: CGFloat = 2
    var lastDirty: [CGRect] = []
    weak var garlandView: NSView?
    var lastGarlandRect = CGRect.zero
    var customCar: CGImage? = nil
    var customCarVersion = -1

    lazy var ballGradient: CGGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [NSColor.white.cgColor,
                 NSColor(calibratedRed: 0.96, green: 0.97, blue: 1, alpha: 1).cgColor,
                 NSColor(calibratedRed: 0.72, green: 0.79, blue: 0.92, alpha: 1).cgColor] as CFArray,
        locations: [0, 0.45, 1])!
    lazy var pileGradient: CGGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [NSColor.white.cgColor,
                 NSColor(calibratedRed: 0.84, green: 0.89, blue: 0.97, alpha: 1).cgColor] as CFArray,
        locations: [0, 1])!

    lazy var flakeSprite: CGImage? = SceneView.radialImage(size: 32, stops: [
        (0, 1, 1, 1, 1), (0.35, 1, 1, 1, 0.85), (0.7, 1, 1, 1, 0.25), (1, 1, 1, 1, 0)])
    lazy var bokehSprite: CGImage? = SceneView.radialImage(size: 64, stops: [
        (0, 1, 1, 1, 0.5), (0.6, 1, 1, 1, 0.38), (0.85, 1, 1, 1, 0.12), (1, 1, 1, 1, 0)])
    lazy var noiseTile: CGImage? = SnowView.makeNoiseTile()
    lazy var carBody: CGImage? = SnowView.loadPNG("car_body")
    lazy var wheelImgs: [CGImage?] = [SnowView.loadPNG("car_wheel_front"), SnowView.loadPNG("car_wheel_rear")]
    lazy var carWheels: [[String: Double]] = {
        guard let url = Bundle.main.url(forResource: "car", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let w = j["wheels"] as? [[String: Any]] else { return [] }
        return w.map { d in
            var o: [String: Double] = [:]
            for k in ["x", "y", "r"] { o[k] = d[k] as? Double ?? 0 }
            return o
        }
    }()
    var glints: [Glint] = (0..<70).map { _ in
        Glint(x: .random(in: 0...3000), phase: .random(in: 0...100), depth: .random(in: 0.05...0.9))
    }

    static func loadPNG(_ name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Мягкий шум для фактуры снега (голубоватые пятна с прозрачностью).
    static func makeNoiseTile() -> CGImage? {
        let size = 384
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        for (cells, strength) in [(12, 0.16), (40, 0.12), (130, 0.08)] as [(Int, Double)] {
            var px = [UInt8](repeating: 0, count: cells * cells * 4)
            for i in 0..<(cells * cells) {
                let a = Double.random(in: 0...1) * strength
                px[i * 4] = UInt8(0.55 * a * 255)
                px[i * 4 + 1] = UInt8(0.65 * a * 255)
                px[i * 4 + 2] = UInt8(0.85 * a * 255)
                px[i * 4 + 3] = UInt8(a * 255)
            }
            let small: CGImage? = px.withUnsafeMutableBytes { buf in
                CGContext(data: buf.baseAddress, width: cells, height: cells, bitsPerComponent: 8,
                          bytesPerRow: cells * 4, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
            }
            if let img = small { ctx.draw(img, in: CGRect(x: 0, y: 0, width: size, height: size)) }
        }
        return ctx.makeImage()
    }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var columnCount: Int { Int(bounds.width / col) + 2 }

    func resetHeights() { heights = Array(repeating: 0, count: columnCount) }

    func index(_ x: CGFloat) -> Int { max(0, min(heights.count - 1, Int(x / col))) }

    func surface(_ x: CGFloat) -> CGFloat {
        heights.isEmpty ? ground : ground + heights[index(x)]
    }

    func addSnow(at x: CGFloat, amount: CGFloat) {
        guard x >= 0, x < bounds.width, !heights.isEmpty else { return }
        let i = index(x)
        heights[i] = min(maxHeight, heights[i] + amount * 0.5)
        if i > 0 { heights[i - 1] = min(maxHeight, heights[i - 1] + amount * 0.25) }
        if i < heights.count - 1 { heights[i + 1] = min(maxHeight, heights[i + 1] + amount * 0.25) }
    }

    func addHeap(at x: CGFloat, volume: CGFloat, span: CGFloat) {
        var xx = x - span
        while xx <= x + span {
            let w = 1 - abs(xx - x) / span
            addSnow(at: xx, amount: volume * w * col / span)
            xx += col
        }
    }

    func burst(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, count: Int) {
        for _ in 0..<count where particles.count < 1500 {
            let a = CGFloat.random(in: 0...(2 * .pi)), sp = CGFloat.random(in: 1...5)
            particles.append(Particle(x: x + cos(a) * r * 0.6, y: y + sin(a) * r * 0.6,
                                      vx: cos(a) * sp, vy: abs(sin(a)) * sp + 1,
                                      r: .random(in: 1.5...4)))
        }
    }

    func clearAll() {
        resetHeights()
        flakes.removeAll(); particles.removeAll(); snowballs.removeAll(); snowmen.removeAll()
        tractorX = nil; tractorLoad = 0; held = nil
        walkers.removeAll()
        for (id, c) in caps { caps[id] = WindowCap(rect: c.rect, h: Array(repeating: 0, count: c.h.count), radius: c.radius) }
    }

    func gust() {
        windTarget = (Bool.random() ? 1 : -1) * CGFloat.random(in: 4...6)
        gustLeft = 3
    }

    func buildSnowman() {
        guard season == .winter else { return }
        let w = bounds.width
        let nearBottom = mouse.x > 60 && mouse.x < w - 60 && mouse.y < ground + 250
        let x = nearBottom ? mouse.x : CGFloat.random(in: 80...(max(81, w - 80)))
        for k in index(x - 45)...index(x + 45) { heights[k] *= 0.5 }
        let s = CGFloat.random(in: 0.85...1.15)
        snowmen.append(Snowman(x: x, radii: [22 * s, 16 * s, 11 * s], progress: 0))
    }

    func callSleigh() {
        guard sleighX == nil, season != .autumn else { return }
        sleighX = bounds.width + 60
        sleighBase = ceiling - CGFloat.random(in: 90...200)
    }

    var sleighY: CGFloat { sleighBase + sin((sleighX ?? 0) / 90) * 18 }

    func callTractor() {
        guard tractorX == nil else { return }
        tractorDir = nextDir
        nextDir = -nextDir
        let x0: CGFloat = tractorDir > 0 ? -220 : bounds.width + 220
        tractorX = x0
        lastBlade = x0 + 136 * carScale * tractorDir
        tractorLoad = 0
    }

    // MARK: - Снеговики

    /// Центры и радиусы комьев (с учётом анимации лепки).
    func balls(_ sm: Snowman) -> [(CGPoint, CGFloat)] {
        var res: [(CGPoint, CGFloat)] = []
        let p = sm.progress * CGFloat(sm.radii.count)
        var prevC = surface(sm.x) - 3
        var prevR: CGFloat = 0
        for (i, r0) in sm.radii.enumerated() {
            let r = r0 * min(max(p - CGFloat(i), 0), 1)
            if r < 0.5 { break }
            let cy = i == 0 ? prevC + r : prevC + prevR + r - min(prevR, r) * 0.3
            res.append((CGPoint(x: sm.x, y: cy), r))
            prevC = cy; prevR = r
        }
        return res
    }

    func snowmanIndex(at p: CGPoint, pad: CGFloat = 3) -> Int? {
        for i in snowmen.indices.reversed() {
            for (c, r) in balls(snowmen[i]) where hypot(p.x - c.x, p.y - c.y) <= r + pad { return i }
        }
        return nil
    }

    /// Снеговик рассыпается в кучу снега.
    func breakSnowman(at idx: Int) {
        let sm = snowmen[idx]
        for (c, r) in balls(sm) {
            burst(c.x, c.y, r, count: Int(r * 1.5))
            addHeap(at: sm.x, volume: r * r * 0.35, span: r * 1.7)
        }
        snowmen.remove(at: idx)
    }

    func splat(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        burst(x, y, r, count: Int(r * 1.2) + 4)
        addHeap(at: x, volume: r * r * 0.25, span: max(r, 6))
    }

    // MARK: - Мышь

    func wantsMouse(at p: CGPoint) -> Bool {
        if prefs.editGarland { return false }
        if held != nil { return true }
        guard !heights.isEmpty, p.x >= 0, p.x < bounds.width else { return false }
        if isSummer { return p.y >= ground - 1 && p.y <= ground + 26 }
        if isSpring { return p.y >= ground - 1 && p.y <= surface(p.x) + 14 }
        if p.y >= ground - 1 && p.y <= surface(p.x) + 4 && heights[index(p.x)] > 2 { return true }
        return snowmanIndex(at: p) != nil
    }

    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if prefs.editGarland { garlandMouseDown(p, right: false, option: e.modifierFlags.contains(.option)); return }
        samples = [(p, e.timestamp)]
        if isAutumn { kickLeaves(at: p, power: 1); return }
        if isSummer { fluffBurst(at: p); return }
        if isSpring { springSplash(at: p); return }
        if let i = snowmanIndex(at: p) { breakSnowman(at: i); return }
        guard !heights.isEmpty, p.y <= surface(p.x) + 6, heights[index(p.x)] > 2 else { return }
        var taken: CGFloat = 0
        for k in index(p.x - 8)...index(p.x + 8) {
            let tk = min(heights[k], 2.5); heights[k] -= tk; taken += tk
        }
        let r = 5 + taken * 0.08
        held = Snowball(x: p.x, y: max(p.y, surface(p.x) + r - 3), vx: 0, vy: 0, r: r)
    }

    override func mouseDragged(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if prefs.editGarland { garlandDrag(p); return }
        let prev = samples.last?.0 ?? p
        samples.append((p, e.timestamp))
        if samples.count > 10 { samples.removeFirst() }
        if isSpring { return }
        if isSummer {
            if hypot(p.x - prev.x, p.y - prev.y) > 3 && CGFloat.random(in: 0...1) < 0.35 {
                blowBubbles(at: p, count: 1, dir: max(-2, min(2, (p.x - prev.x) * 0.2)))
            }
            return
        }
        if isAutumn {
            // ворошим кучу мышкой
            if !heights.isEmpty && p.x >= 0 && p.x < bounds.width && p.y <= surface(p.x) + 8 && hypot(p.x - prev.x, p.y - prev.y) > 2 {
                kickLeaves(at: p, power: 0.35, dirX: max(-4, min(4, (p.x - prev.x) * 0.3)))
            }
            return
        }
        guard var b = held else { return }
        b.x = p.x
        let s = surface(b.x)
        b.y = max(p.y, s + b.r - 4)
        // катаем по сугробу — ком растёт
        let dist = hypot(p.x - prev.x, p.y - prev.y)
        if p.y <= s + b.r && b.r < 32 && dist > 0.5 {
            var taken: CGFloat = 0
            for k in index(b.x - b.r * 0.7)...index(b.x + b.r * 0.7) {
                let tk = min(heights[k], 0.06 * dist); heights[k] -= tk; taken += tk
            }
            b.r = min(32, sqrt(b.r * b.r + taken * col * 0.9))
        }
        held = b
    }

    override func rightMouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if prefs.editGarland { garlandMouseDown(p, right: true, option: false) }
    }

    override func mouseUp(with e: NSEvent) {
        if prefs.editGarland { dragJoint = nil; return }
        if season != .winter { return }
        guard let b = held else { return }
        held = nil
        let recent = samples.filter { e.timestamp - $0.1 < 0.1 }
        var vx: CGFloat = 0, vy: CGFloat = 0
        if let f = recent.first, let l = recent.last, l.1 - f.1 > 0.005 {
            let dt = CGFloat(l.1 - f.1) * 60
            vx = (l.0.x - f.0.x) / dt; vy = (l.0.y - f.0.y) / dt
        }
        if hypot(vx, vy) > 5 {
            // бросок
            let k = min(1, 24 / hypot(vx, vy))
            snowballs.append(Snowball(x: b.x, y: b.y, vx: vx * k, vy: vy * k, r: min(b.r, 14)))
            return
        }
        // положить на снеговика
        for i in snowmen.indices where snowmen[i].radii.count < 3 && snowmen[i].progress >= 1 {
            guard let top = balls(snowmen[i]).last else { continue }
            if abs(b.x - top.0.x) < top.1 + 6 && b.y > top.0.y {
                snowmen[i].radii.append(min(b.r, top.1 * 0.85))
                return
            }
        }
        if b.r >= 9 && b.x > 20 && b.x < bounds.width - 20 {
            snowmen.append(Snowman(x: b.x, radii: [b.r], progress: 1))
        } else {
            splat(b.x, b.y, b.r)
        }
    }

    // MARK: - Физика

    func step() {
        if heights.count != columnCount { resetHeights() }
        t += 1.0 / 60.0
        let w = bounds.width

        if gustLeft > 0 {
            gustLeft -= 1.0 / 60.0
            if gustLeft <= 0 { windTarget = prefs.windX }
        } else {
            windTarget = prefs.windX
            if prefs.gusts && CGFloat.random(in: 0...1) < 0.0015 {
                windTarget = prefs.windX + CGFloat.random(in: -1.5...1.5)
                gustLeft = CGFloat.random(in: 2...4)
            }
        }
        wind += (windTarget - wind) * 0.02

        if abs(wind) > (isAutumn ? 1.2 : 2), !heights.isEmpty, !isSummer, !isSpring {
            for _ in 0..<6 {
                let k = Int.random(in: 0..<heights.count)
                if heights[k] > 3 {
                    heights[k] -= 0.8
                    particles.append(Particle(x: CGFloat(k) * col, y: ground + heights[k] + 2,
                                              vx: wind * 1.5, vy: .random(in: 1...3), r: .random(in: 1.5...3)))
                }
            }
        }

        // снегопад рисует видеочип, а здесь снег просто копится на сугробе и окнах
        depositSnow()

        if heights.count > 1 {
            for _ in 0..<2 {
                for j in 0..<(heights.count - 1) {
                    let d = heights[j] - heights[j + 1]
                    if abs(d) > 2 {
                        let m = (abs(d) - 2) * 0.25 * (d > 0 ? 1 : -1)
                        heights[j] -= m
                        heights[j + 1] += m
                    }
                }
            }
        }

        if shovel, held == nil, mouse.x >= 0, mouse.x < w,
           mouse.y < surface(mouse.x) + 15, mouse.y > ground - 20 {
            for k in index(mouse.x - 24)...index(mouse.x + 24) {
                let take = min(heights[k], 3)
                heights[k] -= take
                if take > 0.5 && CGFloat.random(in: 0...1) < 0.3 && particles.count < 1500 {
                    particles.append(Particle(x: CGFloat(k) * col, y: ground + heights[k] + 4,
                                              vx: .random(in: -3...3), vy: .random(in: 3...7),
                                              r: isSpring ? .random(in: 1.05...1.4) : .random(in: 2...4)))
                }
            }
        }

        for k in snowmen.indices where snowmen[k].progress < 1 {
            snowmen[k].progress = min(1, snowmen[k].progress + 1.0 / 120.0)
        }

        // джип со снегоуборочным отвалом
        if var x = tractorX {
            let d = tractorDir
            x += 3.2 * d
            let blade = x + 136 * carScale * d
            if season != .winter {
                // осенью и летом отвала нет: машина просто раскидывает листья колёсами
                carKickLeaves(x: x, d: d)
                lastBlade = blade
            } else {
            let lo = min(lastBlade, blade), hi = max(lastBlade, blade)
            let a = max(0, Int(lo / col))
            let b = min(heights.count - 1, Int(hi / col))
            if a <= b {
                for k in a...b {
                    let take = max(0, heights[k] - 1)
                    tractorLoad += take
                    heights[k] -= take
                }
            }
            lastBlade = blade
            for k in snowmen.indices.reversed() {
                let rel = (snowmen[k].x - blade) * d
                if rel < 10 && rel > -60 { breakSnowman(at: k) }
            }
            if tractorLoad > 50 && particles.count < 1500 {
                let mh = min(sqrt(tractorLoad) * 1.2, 75)
                for _ in 0..<2 where CGFloat.random(in: 0...1) < 0.8 {
                    particles.append(Particle(x: blade + d * (6 + CGFloat.random(in: 0...mh)), y: ground + mh * 0.9,
                                              vx: CGFloat.random(in: 2...6) * d, vy: .random(in: 3...8),
                                              r: .random(in: 1.5...4)))
                }
            }
            }
            let done = d > 0 ? x > w + 60 : x < -60
            tractorX = done ? nil : x
            if done { tractorLoad = 0 }
        }

        // сани Деда Мороза
        if sleighX == nil && season != .autumn && CGFloat.random(in: 0...1) < 1.0 / (60 * 240) { callSleigh() }
        if var sx = sleighX {
            sx -= isSummer ? 0.9 : (isSpring ? 1.7 : 2.4)
            sleighX = sx < -320 ? nil : sx
            let tail = CGPoint(x: sx + 160, y: sleighY - 4)
            for _ in 0..<2 where sparks.count < 400 && season == .winter {
                sparks.append(Spark(x: tail.x + CGFloat.random(in: -4...4), y: tail.y + CGFloat.random(in: -4...4),
                                    vx: .random(in: 0.2...1.2), vy: .random(in: -0.6...0.2), life: 1))
            }
        }
        var sp = 0
        while sp < sparks.count {
            sparks[sp].x += sparks[sp].vx
            sparks[sp].y += sparks[sp].vy
            sparks[sp].life -= 1.0 / 90.0
            if sparks[sp].life <= 0 { sparks.swapAt(sp, sparks.count - 1); sparks.removeLast() } else { sp += 1 }
        }

        // летящие снежки
        var s = 0
        flight: while s < snowballs.count {
            var sb = snowballs[s]
            sb.vy -= 0.3
            sb.x += sb.vx + wind * 0.2
            sb.y += sb.vy
            if let wi = walkerHit(sb) {
                walkers[wi].hit = 1
                splat(sb.x, sb.y, sb.r)
                snowballs.remove(at: s)
                continue flight
            }
            if let k = snowmanIndex(at: CGPoint(x: sb.x, y: sb.y), pad: sb.r) {
                breakSnowman(at: k)
                splat(sb.x, sb.y, sb.r)
                snowballs.remove(at: s)
                continue flight
            }
            if sb.x >= 0 && sb.x < w && sb.y - sb.r * 0.5 <= surface(sb.x) {
                splat(sb.x, sb.y, sb.r)
                snowballs.remove(at: s)
                continue
            }
            if sb.x < -60 || sb.x > w + 60 || sb.y < -60 {
                snowballs.remove(at: s)
                continue
            }
            snowballs[s] = sb
            s += 1
        }

        // комья снега (осенью — листья: парят, качаются и сильнее летят по ветру)
        let leafy = isAutumn
        let fluffy = isSummer
        let spring = isSpring
        var p = 0
        while p < particles.count {
            var q = particles[p]
            if spring && q.r >= 1.45 {
                // лепесток: парит и кружится
                q.vy = max(q.vy - 0.08, -0.9 - q.r * 0.1)
                q.vx = q.vx * 0.985 + sin(t * 2.4 + q.r * 9) * 0.06
                q.x += q.vx + wind * 0.5
            } else if spring {
                q.vy -= 0.25
                q.x += q.vx + wind * 0.2
            } else if fluffy {
                q.vy = max(q.vy - 0.035, -0.55)
                q.vx = q.vx * 0.98 + sin(t * 1.8 + q.r * 9) * 0.04
                q.x += q.vx + wind * 0.6
            } else if leafy {
                q.vy = max(q.vy - 0.12, -1.3 - q.r * 0.15)
                q.vx = q.vx * 0.985 + sin(t * 2.6 + q.r * 9) * 0.07
                q.x += q.vx + wind * 0.55
            } else {
                q.vy -= 0.25
                q.x += q.vx + wind * 0.3
            }
            q.y += q.vy
            let landed = q.vy < 0 && q.x >= 0 && q.x < w && q.y <= surface(q.x)
            if landed || q.y < -20 || q.x < -50 || q.x > w + 50 {
                if landed && !fluffy && !spring { addSnow(at: q.x, amount: q.r * 0.8) }
                particles.swapAt(p, particles.count - 1)
                particles.removeLast()
                continue
            }
            particles[p] = q
            p += 1
        }
        worldStep()
    }

    // MARK: - Рисование

    func lumpyPath(_ c: CGPoint, _ r: CGFloat, seed: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let n = 32
        for k in 0...n {
            let a = CGFloat(k) / CGFloat(n) * 2 * .pi
            var rr = r * (1 + 0.035 * sin(3 * a + seed))
            rr += r * (0.025 * sin(5 * a + seed * 1.7) + 0.012 * sin(11 * a + seed * 2.3))
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// Неровный снежный ком: свет сверху-слева, фактура, отражённый свет снизу.
    func shadedBall(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, seed: CGFloat = 0) {
        guard r > 0.5 else { return }
        let path = r > 4 ? lumpyPath(c, r, seed: seed) : CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawRadialGradient(ballGradient,
                               startCenter: CGPoint(x: c.x - r * 0.35, y: c.y + r * 0.4), startRadius: 0,
                               endCenter: c, endRadius: r * 1.08, options: [.drawsAfterEndLocation])
        if r > 4, let tile = noiseTile {
            ctx.setAlpha(0.9)
            ctx.draw(tile, in: CGRect(x: c.x - 192 + seed * 13, y: c.y - 192, width: 384, height: 384), byTiling: true)
            ctx.setAlpha(1)
        }
        // отражённый от снега свет снизу
        let refl = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [CGColor(red: 0.92, green: 0.95, blue: 1, alpha: 0.55),
                                       CGColor(red: 0.92, green: 0.95, blue: 1, alpha: 0)] as CFArray,
                              locations: [0, 1])!
        ctx.drawLinearGradient(refl, start: CGPoint(x: c.x, y: c.y - r), end: CGPoint(x: c.x, y: c.y - r * 0.55), options: [])
        ctx.restoreGState()
        if r > 4 {
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(red: 0.55, green: 0.65, blue: 0.85, alpha: 0.35))
            ctx.setLineWidth(0.8)
            ctx.strokePath()
        }
    }

    func softShadow(_ ctx: CGContext, _ rect: CGRect, _ alpha: CGFloat) {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 6,
                      color: NSColor(calibratedRed: 0.2, green: 0.28, blue: 0.5, alpha: alpha).cgColor)
        ctx.setFillColor(NSColor(calibratedRed: 0.2, green: 0.28, blue: 0.5, alpha: alpha * 0.8).cgColor)
        ctx.fillEllipse(in: rect)
        ctx.restoreGState()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)

        // дальние снежинки — позади всего
        if let sp = flakeSprite {
            for f in flakes where f.z < 0.75 {
                ctx.setAlpha(f.alpha)
                let d = f.r * 2.4
                ctx.draw(sp, in: CGRect(x: f.x - d / 2, y: f.y - d / 2, width: d, height: d))
            }
            ctx.setAlpha(1)
        }

        drawWindowCaps(ctx)
        drawSleigh(ctx)
        drawDecor(ctx)
        drawTree(ctx)
        if isSummer || isSpring { drawGrass(ctx) }
        if isSpring { drawPuddles(ctx) }

        // сугроб: тень, объём, блик по верху
        if heights.contains(where: { $0 > 0.3 }) {
            let path = CGMutablePath()
            let top = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: ground))
            for (k, hh) in heights.enumerated() {
                let pt = CGPoint(x: CGFloat(k) * col, y: ground + hh)
                path.addLine(to: pt)
                if k == 0 { top.move(to: pt) } else { top.addLine(to: pt) }
            }
            path.addLine(to: CGPoint(x: bounds.width, y: ground))
            path.addLine(to: CGPoint(x: bounds.width, y: 0))
            path.closeSubpath()
            if isAutumn { drawLeafPile(ctx, path) } else {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 8,
                          color: NSColor(calibratedRed: 0.25, green: 0.35, blue: 0.6, alpha: 0.55).cgColor)
            ctx.addPath(path)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(pileGradient, start: CGPoint(x: 0, y: ground + 45),
                                   end: CGPoint(x: 0, y: ground), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            if let tile = noiseTile {
                ctx.draw(tile, in: CGRect(x: 0, y: ground, width: 384, height: 384), byTiling: true)
            }
            // затенение у самого низа
            let ao = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [CGColor(red: 0.45, green: 0.55, blue: 0.8, alpha: 0.35),
                                         CGColor(red: 0.45, green: 0.55, blue: 0.8, alpha: 0)] as CFArray,
                                locations: [0, 1])!
            ctx.drawLinearGradient(ao, start: CGPoint(x: 0, y: ground), end: CGPoint(x: 0, y: ground + 10), options: [])
            ctx.restoreGState()
            ctx.addPath(top)
            ctx.setStrokeColor(NSColor(white: 1, alpha: 0.95).cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokePath()
            ctx.saveGState()
            ctx.translateBy(x: 0, y: -2.5)
            ctx.addPath(top)
            ctx.setStrokeColor(CGColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 0.18))
            ctx.setLineWidth(2)
            ctx.strokePath()
            ctx.restoreGState()
            // искорки на снегу
            for gl in glints {
                let gx = gl.x.truncatingRemainder(dividingBy: max(bounds.width, 1))
                let hh = heights[index(gx)]
                guard hh > 3 else { continue }
                let b = pow(max(0, sin(t * 1.3 + gl.phase)), 12)
                guard b > 0.05 else { continue }
                let gy = ground + hh - gl.depth * min(hh, 22) - 1
                let len = 1 + 3.5 * b
                ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: b))
                ctx.setLineWidth(0.8)
                ctx.move(to: CGPoint(x: gx - len, y: gy)); ctx.addLine(to: CGPoint(x: gx + len, y: gy))
                ctx.move(to: CGPoint(x: gx, y: gy - len)); ctx.addLine(to: CGPoint(x: gx, y: gy + len))
                ctx.strokePath()
            }
            }
        }

        for sm in snowmen { drawSnowman(ctx, sm) }
        drawWalkers(ctx)
        if let x = tractorX { drawTractor(ctx, x, tractorDir) }
        if isSpring { drawBirds(ctx) }
        if isSummer {
            drawButterflies(ctx)
            drawBubbles(ctx)
            drawFireflies(ctx)
        }

        // снежок в руке
        if let b = held {
            softShadow(ctx, CGRect(x: b.x - b.r, y: surface(b.x) - 2, width: b.r * 2, height: 5), 0.25)
            shadedBall(ctx, CGPoint(x: b.x, y: b.y), b.r)
        }
        for sb in snowballs { shadedBall(ctx, CGPoint(x: sb.x, y: sb.y), sb.r) }

        if isSpring { drawSpringParticles(ctx) } else if isSummer { drawFluffParticles(ctx) } else if isAutumn { drawLeafParticles(ctx) } else if let sp = flakeSprite {
            for q in particles {
                let d = q.r * 2.6
                ctx.draw(sp, in: CGRect(x: q.x - d / 2, y: q.y - d / 2, width: d, height: d))
            }
        }
        // ближние снежинки — крупные, размытые, как вне фокуса камеры
        if let bk = bokehSprite {
            for f in flakes where f.z >= 0.75 {
                ctx.setAlpha(f.alpha)
                let d = f.r * 3.2
                ctx.draw(bk, in: CGRect(x: f.x - d / 2, y: f.y - d / 2, width: d, height: d))
            }
            ctx.setAlpha(1)
        }
    }

    // MARK: - Сани

    func drawSleigh(_ ctx: CGContext) {
        if isSummer { drawBalloon(ctx); return }
        if isSpring { drawFlock(ctx); return }
        for s in sparks {
            ctx.setFillColor(NSColor(calibratedRed: 1, green: 0.85, blue: 0.4, alpha: s.life * 0.9).cgColor)
            let r = 1 + s.life * 1.5
            ctx.fillEllipse(in: CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2))
        }
        guard let sx = sleighX else { return }
        let sy = sleighY
        let brown = NSColor(calibratedRed: 0.5, green: 0.32, blue: 0.18, alpha: 1).cgColor
        let antler = NSColor(calibratedRed: 0.85, green: 0.75, blue: 0.55, alpha: 1).cgColor
        ctx.setLineCap(.round)
        // упряжь
        ctx.setStrokeColor(NSColor(calibratedRed: 0.9, green: 0.75, blue: 0.3, alpha: 1).cgColor)
        ctx.setLineWidth(1.2)
        ctx.move(to: CGPoint(x: sx - 10, y: sy + 2)); ctx.addLine(to: CGPoint(x: sx + 128, y: sy - 2))
        ctx.strokePath()
        // олени
        for i in 0..<3 {
            let rx = sx + CGFloat(i) * 38
            let ry = sy + sin(t * 6 + CGFloat(i)) * 2
            let ph = sin(t * 12 + CGFloat(i) * 1.3)
            ctx.setStrokeColor(brown); ctx.setLineWidth(2.2)
            ctx.move(to: CGPoint(x: rx - 7, y: ry - 3)); ctx.addLine(to: CGPoint(x: rx - 11 - 5 * ph, y: ry - 12))
            ctx.move(to: CGPoint(x: rx - 4, y: ry - 3)); ctx.addLine(to: CGPoint(x: rx - 6 + 4 * ph, y: ry - 12))
            ctx.move(to: CGPoint(x: rx + 8, y: ry - 3)); ctx.addLine(to: CGPoint(x: rx + 12 + 5 * ph, y: ry - 11))
            ctx.move(to: CGPoint(x: rx + 11, y: ry - 3)); ctx.addLine(to: CGPoint(x: rx + 15 - 4 * ph, y: ry - 11))
            ctx.strokePath()
            ctx.setFillColor(brown)
            ctx.fillEllipse(in: CGRect(x: rx - 11, y: ry - 5, width: 25, height: 10))
            ctx.setLineWidth(4)
            ctx.move(to: CGPoint(x: rx - 8, y: ry + 2)); ctx.addLine(to: CGPoint(x: rx - 14, y: ry + 9))
            ctx.strokePath()
            ctx.fillEllipse(in: CGRect(x: rx - 22, y: ry + 6, width: 11, height: 7))
            ctx.setStrokeColor(antler); ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: rx - 14, y: ry + 12)); ctx.addLine(to: CGPoint(x: rx - 12, y: ry + 22))
            ctx.move(to: CGPoint(x: rx - 12.8, y: ry + 17)); ctx.addLine(to: CGPoint(x: rx - 8, y: ry + 20))
            ctx.move(to: CGPoint(x: rx - 16, y: ry + 12)); ctx.addLine(to: CGPoint(x: rx - 19, y: ry + 21))
            ctx.strokePath()
            ctx.setFillColor(i == 0 ? NSColor(calibratedRed: 1, green: 0.15, blue: 0.1, alpha: 1).cgColor : brown)
            ctx.fillEllipse(in: CGRect(x: rx - 24, y: ry + 7, width: 4, height: 4))
        }
        // сани
        let bx = sx + 150, by = sy - 2
        ctx.setStrokeColor(NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.3, alpha: 1).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: bx - 26, y: by - 3))
        ctx.addQuadCurve(to: CGPoint(x: bx - 18, y: by - 11), control: CGPoint(x: bx - 28, y: by - 11))
        ctx.addLine(to: CGPoint(x: bx + 20, y: by - 11))
        ctx.strokePath()
        ctx.setFillColor(NSColor(calibratedRed: 0.75, green: 0.08, blue: 0.1, alpha: 1).cgColor)
        ctx.addPath(CGPath(roundedRect: CGRect(x: bx - 18, y: by - 7, width: 36, height: 13), cornerWidth: 5, cornerHeight: 5, transform: nil))
        ctx.fillPath()
        ctx.addPath(CGPath(roundedRect: CGRect(x: bx + 10, y: by - 7, width: 10, height: 22), cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.fillPath()
        // мешок с подарками
        ctx.setFillColor(NSColor(calibratedRed: 0.6, green: 0.45, blue: 0.3, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: bx + 2, y: by + 3, width: 14, height: 13))
        // Дед Мороз
        ctx.setFillColor(NSColor(calibratedRed: 0.85, green: 0.1, blue: 0.12, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: bx - 10, y: by + 2, width: 14, height: 15))
        ctx.setFillColor(NSColor(calibratedRed: 1, green: 0.85, blue: 0.75, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: bx - 8, y: by + 15, width: 8, height: 8))
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: bx - 9, y: by + 12, width: 8, height: 6))
        ctx.setFillColor(NSColor(calibratedRed: 0.85, green: 0.1, blue: 0.12, alpha: 1).cgColor)
        ctx.move(to: CGPoint(x: bx - 9, y: by + 21)); ctx.addLine(to: CGPoint(x: bx + 1, y: by + 21))
        ctx.addLine(to: CGPoint(x: bx + 4, y: by + 28)); ctx.closePath(); ctx.fillPath()
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: bx + 2, y: by + 26, width: 4, height: 4))
    }

    func coal(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, seed: CGFloat) {
        ctx.addPath(lumpyPath(c, r, seed: seed))
        ctx.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1))
        ctx.fillPath()
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.45))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.45, y: c.y + r * 0.1, width: r * 0.45, height: r * 0.4))
    }

    func twig(_ ctx: CGContext, from a: CGPoint, to b: CGPoint, width: CGFloat) {
        let brown = CGColor(red: 0.3, green: 0.19, blue: 0.1, alpha: 1)
        ctx.setStrokeColor(brown)
        ctx.setLineCap(.round)
        let mid = CGPoint(x: (a.x + b.x) / 2 + (b.y - a.y) * 0.06, y: (a.y + b.y) / 2 - (b.x - a.x) * 0.06)
        ctx.setLineWidth(width)
        ctx.move(to: a); ctx.addLine(to: mid); ctx.strokePath()
        ctx.setLineWidth(width * 0.7)
        ctx.move(to: mid); ctx.addLine(to: b); ctx.strokePath()
        // веточки
        let dx = b.x - a.x, dy = b.y - a.y
        ctx.setLineWidth(width * 0.45)
        for (t0, side) in [(0.55, 1.0), (0.78, -1.0)] as [(CGFloat, CGFloat)] {
            let p = CGPoint(x: a.x + dx * t0, y: a.y + dy * t0)
            ctx.move(to: p)
            ctx.addLine(to: CGPoint(x: p.x + dx * 0.22 - dy * 0.25 * side, y: p.y + dy * 0.22 + dx * 0.25 * side))
            ctx.strokePath()
        }
    }

    func drawSnowman(_ ctx: CGContext, _ sm: Snowman) {
        let bs = balls(sm)
        guard let first = bs.first else { return }
        let seed0 = sm.x * 0.37
        softShadow(ctx, CGRect(x: sm.x - first.1 * 1.1 + 5, y: first.0.y - first.1 - 4,
                               width: first.1 * 2.5, height: 8), 0.4)
        let done = sm.radii.count >= 3 && bs.count == 3 && sm.progress >= 1
        if done {
            let (c2, r2) = bs[1]
            let w = max(1.6, r2 * 0.13)
            twig(ctx, from: CGPoint(x: c2.x - r2 * 0.75, y: c2.y + r2 * 0.1),
                 to: CGPoint(x: c2.x - r2 * 2.1, y: c2.y + r2 * 0.95), width: w)
            twig(ctx, from: CGPoint(x: c2.x + r2 * 0.75, y: c2.y + r2 * 0.1),
                 to: CGPoint(x: c2.x + r2 * 2.0, y: c2.y + r2 * 0.6), width: w)
        }
        for (k, (c, r)) in bs.enumerated() {
            if k > 0 {
                softShadow(ctx, CGRect(x: c.x - r * 0.85, y: c.y - r * 1.05, width: r * 1.7, height: r * 0.5), 0.35)
            }
            shadedBall(ctx, c, r, seed: seed0 + CGFloat(k) * 2.1)
        }
        guard done else { return }
        let (c2, r2) = bs[1]
        let (c3, r3) = bs[2]
        let s = r3 / 11
        // вязаный шарф
        let band = CGRect(x: c3.x - r3 * 0.98, y: c3.y - r3 - 2.5 * s, width: r3 * 1.96, height: 6 * s)
        let scarf = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [CGColor(red: 0.85, green: 0.12, blue: 0.15, alpha: 1),
                                        CGColor(red: 0.55, green: 0.05, blue: 0.08, alpha: 1)] as CFArray,
                               locations: [0, 1])!
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: band, cornerWidth: 2.5 * s, cornerHeight: 2.5 * s, transform: nil))
        ctx.addPath(CGPath(roundedRect: CGRect(x: c3.x + r3 * 0.25, y: c3.y - r3 - 13 * s, width: 5.5 * s, height: 12 * s),
                           cornerWidth: 2 * s, cornerHeight: 2 * s, transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(scarf, start: CGPoint(x: band.minX, y: band.maxY), end: CGPoint(x: band.maxX, y: c3.y - r3 - 13 * s), options: [])
        ctx.setStrokeColor(CGColor(red: 1, green: 0.95, blue: 0.9, alpha: 0.75))
        ctx.setLineWidth(1.2 * s)
        var yy = c3.y - r3 - 11 * s
        while yy < band.maxY { ctx.move(to: CGPoint(x: band.minX, y: yy)); ctx.addLine(to: CGPoint(x: band.maxX, y: yy)); yy += 3.2 * s }
        ctx.strokePath()
        ctx.restoreGState()
        // бахрома
        ctx.setStrokeColor(CGColor(red: 0.7, green: 0.08, blue: 0.1, alpha: 1))
        ctx.setLineWidth(0.8 * s)
        for k in 0..<4 {
            let fx = c3.x + r3 * 0.25 + (CGFloat(k) + 0.5) * 1.4 * s
            ctx.move(to: CGPoint(x: fx, y: c3.y - r3 - 13 * s)); ctx.addLine(to: CGPoint(x: fx, y: c3.y - r3 - 15.5 * s))
        }
        ctx.strokePath()
        // глаза-угольки, рот, пуговицы
        coal(ctx, CGPoint(x: c3.x - 3.6 * s, y: c3.y + 3.6 * s), 1.6 * s, seed: 1)
        coal(ctx, CGPoint(x: c3.x + 3.8 * s, y: c3.y + 3.8 * s), 1.6 * s, seed: 2)
        for k in 0..<5 {
            let a = CGFloat.pi * (1.25 + CGFloat(k) * 0.125)
            coal(ctx, CGPoint(x: c3.x + cos(a) * 6 * s + 1 * s, y: c3.y - 1.5 * s + sin(a) * 4.5 * s), 0.8 * s, seed: CGFloat(k))
        }
        for k in 0..<3 {
            coal(ctx, CGPoint(x: c2.x + r2 * 0.05, y: c2.y + r2 * (0.45 - CGFloat(k) * 0.4)), r2 * 0.1, seed: CGFloat(k) + 5)
        }
        // нос-морковка с бороздками
        let nose = CGMutablePath()
        nose.move(to: CGPoint(x: c3.x + 0.5 * s, y: c3.y + 2.2 * s))
        nose.addQuadCurve(to: CGPoint(x: c3.x + 15 * s, y: c3.y - 2.5 * s), control: CGPoint(x: c3.x + 8 * s, y: c3.y + 1 * s))
        nose.addQuadCurve(to: CGPoint(x: c3.x + 0.5 * s, y: c3.y - 2.6 * s), control: CGPoint(x: c3.x + 7 * s, y: c3.y - 3 * s))
        nose.closeSubpath()
        let carrot = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [CGColor(red: 1, green: 0.6, blue: 0.15, alpha: 1),
                                         CGColor(red: 0.85, green: 0.35, blue: 0.05, alpha: 1)] as CFArray,
                                locations: [0, 1])!
        ctx.saveGState()
        ctx.addPath(nose); ctx.clip()
        ctx.drawLinearGradient(carrot, start: CGPoint(x: c3.x, y: c3.y + 2.2 * s), end: CGPoint(x: c3.x, y: c3.y - 2.6 * s), options: [])
        ctx.setStrokeColor(CGColor(red: 0.6, green: 0.25, blue: 0.05, alpha: 0.6))
        ctx.setLineWidth(0.6 * s)
        for k in 1...3 {
            let nx = c3.x + CGFloat(k) * 3.4 * s
            ctx.move(to: CGPoint(x: nx, y: c3.y + 2 * s)); ctx.addLine(to: CGPoint(x: nx + 0.6 * s, y: c3.y - 3 * s))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    func drawTractor(_ ctx: CGContext, _ x: CGFloat, _ dir: CGFloat) {
        ctx.saveGState()
        if dir < 0 { ctx.translateBy(x: 2 * x, y: 0); ctx.scaleBy(x: -1, y: 1) }
        let g = ground
        // уменьшаем всю машину вокруг точки на земле
        ctx.translateBy(x: x, y: g)
        ctx.scaleBy(x: carScale, y: carScale)
        ctx.translateBy(x: -x, y: -g)
        defer { ctx.restoreGState() }
        let night = nightLevel
        let ink = rgb(0.16, 0.17, 0.19)
        let b = sin(t * 25) * 0.6
        func pt(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: x + dx, y: g + dy + b) }
        func poly(_ pts: [CGPoint]) -> CGPath {
            let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p
        }
        func glow(_ p: CGPoint, _ rad: CGFloat, _ c: (CGFloat, CGFloat, CGFloat), _ a: CGFloat) {
            glowSpot(ctx, p, rad, c, a)
        }
        let blade = x + 136

        // тень
        softShadow(ctx, CGRect(x: x - 58, y: g - 5, width: 210, height: 10), 0.55)

        // снег перед отвалом
        let mh = min(sqrt(tractorLoad) * 1.2, 70)
        if mh > 2 && season == .winter {
            let m = CGMutablePath()
            m.move(to: CGPoint(x: blade - 6, y: g))
            m.addQuadCurve(to: CGPoint(x: blade + mh * 1.7, y: g), control: CGPoint(x: blade + mh * 0.3, y: g + mh * 1.6))
            m.closeSubpath()
            ctx.saveGState()
            ctx.addPath(m); ctx.clip()
            ctx.drawLinearGradient(pileGradient, start: CGPoint(x: 0, y: g + mh), end: CGPoint(x: 0, y: g), options: [])
            if let tile = noiseTile { ctx.draw(tile, in: CGRect(x: blade, y: g, width: 384, height: 384), byTiling: true) }
            ctx.restoreGState()
        }

        // лучи фар
        if night > 0.05 {
            let hx = x + 118, hy = g + 37 + b
            let beam = poly([CGPoint(x: hx, y: hy + 3), CGPoint(x: hx + 280, y: hy + 34), CGPoint(x: hx + 280, y: g - 4), CGPoint(x: hx, y: hy - 4)])
            ctx.saveGState()
            ctx.addPath(beam); ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(1, 0.97, 0.85, 0.32 * night), rgb(1, 0.97, 0.85, 0)),
                                   start: CGPoint(x: hx, y: hy), end: CGPoint(x: hx + 280, y: hy), options: [])
            ctx.restoreGState()
        }

        // своя картинка машины вместо нарисованного внедорожника
        var customTop: CGFloat = 0
        if prefs.carMode == 1, let img = customCar {
            let cw: CGFloat = 172
            let ch = cw * CGFloat(img.height) / CGFloat(max(1, img.width))
            ctx.saveGState()
            if prefs.carFlip { ctx.translateBy(x: 2 * (x + 36), y: 0); ctx.scaleBy(x: -1, y: 1) }
            ctx.interpolationQuality = .high
            ctx.draw(img, in: CGRect(x: x - 50, y: g + b, width: cw, height: ch))
            ctx.restoreGState()
            customTop = ch
        }
        if customTop == 0 {
        // кузов: серебристый металлик
        let body = CGMutablePath()
        let arcA: CGFloat = 0.14
        body.move(to: pt(-46, 6))
        body.addLine(to: pt(-50, 20)); body.addLine(to: pt(-50, 42)); body.addLine(to: pt(-46, 50))
        body.addLine(to: pt(-40, 72))
        body.addQuadCurve(to: pt(-28, 80), control: pt(-38, 80))
        body.addLine(to: pt(40, 80))
        body.addQuadCurve(to: pt(64, 56), control: pt(50, 78))
        body.addQuadCurve(to: pt(110, 47), control: pt(96, 54))
        body.addQuadCurve(to: pt(122, 30), control: pt(121, 44))
        body.addLine(to: pt(121, 10)); body.addLine(to: pt(116, 6)); body.addLine(to: pt(110, 6))
        // колёсные арки открыты снизу, кузов (порог) идёт между ними
        body.addArc(center: CGPoint(x: x + 86, y: g + 17 + b), radius: 22, startAngle: -arcA, endAngle: .pi + arcA, clockwise: false)
        body.addLine(to: pt(62, 6))
        body.addLine(to: pt(10, 6))
        body.addArc(center: CGPoint(x: x - 14, y: g + 17 + b), radius: 22, startAngle: -arcA, endAngle: .pi + arcA, clockwise: false)
        body.addLine(to: pt(-38, 6))
        body.closeSubpath()
        ctx.saveGState()
        ctx.addPath(body); ctx.clip()
        let metal = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [rgb(0.82, 0.84, 0.87), rgb(0.97, 0.98, 0.99), rgb(0.74, 0.76, 0.8),
                                        rgb(0.62, 0.64, 0.68), rgb(0.8, 0.82, 0.85)] as CFArray,
                               locations: [0, 0.28, 0.5, 0.75, 1])!
        ctx.drawLinearGradient(metal, start: pt(0, 82), end: pt(0, 8), options: [])
        // отражение неба на борту
        ctx.setFillColor(rgb(1, 1, 1, 0.22))
        ctx.fill(CGRect(x: x - 52, y: g + 41 + b, width: 180, height: 3))
        // пластиковый обвес и молдинг
        ctx.setFillColor(rgb(0.2, 0.21, 0.23))
        ctx.fill(CGRect(x: x - 52, y: g + b, width: 178, height: 13))
        ctx.setFillColor(rgb(0.85, 0.86, 0.88))
        ctx.fill(CGRect(x: x - 48, y: g + 20 + b, width: 166, height: 1.4))
        ctx.restoreGState()
        ctx.addPath(body); ctx.setStrokeColor(ink); ctx.setLineWidth(1.2); ctx.strokePath()

        // тонированные стёкла с бликом
        let glassPath = poly([pt(-41, 53), pt(-36, 72), pt(-27, 77), pt(40, 77), pt(59, 54)])
        ctx.saveGState()
        ctx.addPath(glassPath); ctx.clip()
        ctx.drawLinearGradient(linGrad(rgb(0.28, 0.33, 0.42), rgb(0.06, 0.07, 0.1)), start: pt(0, 77), end: pt(0, 53), options: [])
        ctx.setFillColor(rgb(1, 1, 1, 0.13))
        ctx.addPath(poly([pt(30, 77), pt(40, 77), pt(18, 53), pt(8, 53)])); ctx.fillPath()
        ctx.restoreGState()
        ctx.setFillColor(rgb(0.12, 0.12, 0.14))
        ctx.fill(CGRect(x: x + 13, y: g + 53 + b, width: 5, height: 24))
        ctx.fill(CGRect(x: x - 22, y: g + 53 + b, width: 5, height: 24))
        // рейлинги
        ctx.setFillColor(rgb(0.25, 0.26, 0.28))
        ctx.fill(CGRect(x: x - 30, y: g + 82 + b, width: 70, height: 2.5))
        ctx.fill(CGRect(x: x - 28, y: g + 79.5 + b, width: 3, height: 3.5))
        ctx.fill(CGRect(x: x + 36, y: g + 79.5 + b, width: 3, height: 3.5))
        // двери, ручки, зеркало
        ctx.setStrokeColor(rgb(0.35, 0.37, 0.4, 0.8)); ctx.setLineWidth(0.9)
        ctx.move(to: pt(16, 52)); ctx.addLine(to: pt(16, 13))
        ctx.move(to: pt(-19, 52)); ctx.addLine(to: pt(-19, 14))
        ctx.move(to: pt(61, 53)); ctx.addLine(to: pt(59, 13))
        ctx.strokePath()
        ctx.setFillColor(rgb(0.55, 0.57, 0.6))
        ctx.fill(CGRect(x: x + 3, y: g + 44 + b, width: 8, height: 1.8))
        ctx.fill(CGRect(x: x + 40, y: g + 44 + b, width: 8, height: 1.8))
        ctx.addPath(poly([pt(57, 52), pt(64, 53), pt(64, 47), pt(58, 47)]))
        ctx.setFillColor(rgb(0.78, 0.8, 0.83)); ctx.fillPath()
        // фары и фонари
        ctx.addPath(poly([pt(106, 44), pt(118, 41), pt(120, 35), pt(108, 36)]))
        ctx.setFillColor(rgb(0.95, 0.96, 0.98)); ctx.fillPath()
        glow(pt(116, 38.5), 6 + 12 * night, (1, 0.97, 0.85), 0.45 + 0.45 * night)
        ctx.addPath(poly([pt(-50, 47), pt(-45, 47), pt(-45, 37), pt(-50, 37)]))
        ctx.setFillColor(rgb(0.75, 0.08, 0.08)); ctx.fillPath()
        if night > 0.05 { glow(pt(-48, 42), 12, (1, 0.1, 0.1), 0.6 * night) }
        // решётка радиатора
        ctx.setFillColor(rgb(0.25, 0.26, 0.28))
        ctx.fill(CGRect(x: x + 117, y: g + 22 + b, width: 4, height: 11))

        // ниши колёс и расширители арок
        for cx in [x - 14, x + 86] {
            // тёмная ниша видна только над колесом
            ctx.saveGState()
            ctx.clip(to: CGRect(x: cx - 24, y: g + 12 + b, width: 48, height: 40))
            ctx.setFillColor(rgb(0.06, 0.06, 0.07))
            ctx.fillEllipse(in: CGRect(x: cx - 21.5, y: g + 17 + b - 21.5, width: 43, height: 43))
            ctx.restoreGState()
            let flare = CGMutablePath()
            flare.addArc(center: CGPoint(x: cx, y: g + 17 + b), radius: 23, startAngle: -arcA, endAngle: .pi + arcA, clockwise: false)
            ctx.addPath(flare)
            ctx.setStrokeColor(rgb(0.18, 0.19, 0.21)); ctx.setLineWidth(3.5); ctx.strokePath()
        }
        // нижняя кромка порога и бамперов
        ctx.setFillColor(rgb(0.13, 0.14, 0.15))
        ctx.fill(CGRect(x: x + 10, y: g + 6 + b, width: 52, height: 2))
        ctx.fill(CGRect(x: x + 110, y: g + 6 + b, width: 7, height: 2))
        ctx.fill(CGRect(x: x - 46, y: g + 6 + b, width: 8, height: 2))

        // колёса: шина + литой диск с пятью спицами, крутятся
        let spin = -(x * dir) / 17
        for cx in [x - 14, x + 86] {
            let c = CGPoint(x: cx, y: g + 17)
            ctx.setFillColor(rgb(0.07, 0.07, 0.08))
            ctx.fillEllipse(in: CGRect(x: c.x - 17, y: c.y - 17, width: 34, height: 34))
            ctx.setStrokeColor(rgb(0.2, 0.2, 0.22)); ctx.setLineWidth(1)
            ctx.strokeEllipse(in: CGRect(x: c.x - 15, y: c.y - 15, width: 30, height: 30))
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: c.x - 11.5, y: c.y - 11.5, width: 23, height: 23)); ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(0.4, 0.42, 0.45), rgb(0.18, 0.19, 0.2)),
                                   start: CGPoint(x: c.x, y: c.y + 12), end: CGPoint(x: c.x, y: c.y - 12), options: [])
            ctx.restoreGState()
            for k in 0..<5 {
                let a = spin + CGFloat(k) * 2 * .pi / 5
                func r(_ rad: CGFloat, _ da: CGFloat) -> CGPoint {
                    CGPoint(x: c.x + rad * cos(a + da), y: c.y + rad * sin(a + da))
                }
                ctx.addPath(poly([r(3, -0.7), r(11, -0.22), r(11, 0.22), r(3, 0.7)]))
                ctx.setFillColor(rgb(0.86, 0.87, 0.9)); ctx.fillPath()
            }
            ctx.setStrokeColor(rgb(0.88, 0.89, 0.92)); ctx.setLineWidth(1.4)
            ctx.strokeEllipse(in: CGRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22))
            ctx.setFillColor(rgb(0.55, 0.56, 0.6))
            ctx.fillEllipse(in: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6))
        }

        }
        if season != .winter { return }   // осенью и летом без мигалки и отвала — обычный внедорожник
        // мигалка: янтарный купол с вращающимся отблеском
        let bx = customTop > 0 ? x + 36 : x + 6
        let by = customTop > 0 ? g + customTop + 1 + b : g + 84 + b
        ctx.setFillColor(rgb(0.15, 0.15, 0.17))
        ctx.fill(CGRect(x: bx - 9, y: by - 1, width: 18, height: 3))
        let phase = (t * 2.2).truncatingRemainder(dividingBy: 1)
        let flash = pow(max(0, cos(phase * 2 * .pi)), 6)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: CGRect(x: bx - 6, y: by + 2, width: 12, height: 8), cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(linGrad(rgb(1, 0.78, 0.25), rgb(0.85, 0.4, 0)), start: CGPoint(x: bx, y: by + 10), end: CGPoint(x: bx, y: by + 2), options: [])
        ctx.restoreGState()
        glow(CGPoint(x: bx + sin(phase * 2 * .pi) * 4, y: by + 6), 14 + 40 * flash, (1, 0.6, 0.1), 0.25 + 0.6 * flash)

        // рама и отвал: окрашенная сталь
        ctx.setFillColor(rgb(0.15, 0.15, 0.16))
        ctx.fill(CGRect(x: x + 116, y: g + 14, width: blade - x - 120, height: 6))
        ctx.fill(CGRect(x: x + 116, y: g + 25, width: blade - x - 120, height: 3))
        let bl = CGMutablePath()
        bl.move(to: CGPoint(x: blade - 8, y: g + 1))
        bl.addLine(to: CGPoint(x: blade + 10, y: g + 1))
        bl.addQuadCurve(to: CGPoint(x: blade + 9, y: g + 46), control: CGPoint(x: blade - 2, y: g + 22))
        bl.addLine(to: CGPoint(x: blade + 2, y: g + 49))
        bl.addQuadCurve(to: CGPoint(x: blade - 8, y: g + 2), control: CGPoint(x: blade - 12, y: g + 22))
        bl.closeSubpath()
        let paint = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [rgb(0.75, 0.3, 0.02), rgb(1, 0.6, 0.15), rgb(0.7, 0.28, 0.02)] as CFArray,
                               locations: [0, 0.55, 1])!
        ctx.saveGState()
        ctx.addPath(bl); ctx.clip()
        ctx.drawLinearGradient(paint, start: CGPoint(x: blade - 10, y: g), end: CGPoint(x: blade + 10, y: g), options: [])
        ctx.setFillColor(rgb(0.62, 0.64, 0.68))
        ctx.fill(CGRect(x: blade - 10, y: g, width: 22, height: 4))
        ctx.restoreGState()
        ctx.addPath(bl)
        ctx.setStrokeColor(rgb(0.2, 0.1, 0.02, 0.8)); ctx.setLineWidth(0.8); ctx.strokePath()
    }
}


// MARK: - Живые обои: время суток по реальным часам

struct SolarState { var elev: Double; var ha: Double; var moonElev: Double; var moonHa: Double }

/// Приближённое положение солнца (формулы NOAA). Долгота оценивается по часовому поясу.
func solarPosition(_ date: Date, latitude: Double = 55.75) -> SolarState {
    let tz = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600
    let lon = tz * 15
    let cal = Calendar.current
    let n = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
    let c = cal.dateComponents([.hour, .minute, .second], from: date)
    let h0 = Double(c.hour ?? 0)
    let m0 = Double(c.minute ?? 0) / 60
    let s0 = Double(c.second ?? 0) / 3600
    let hr = h0 + m0 + s0
    let g = 2 * Double.pi / 365 * (n - 1 + (hr - 12) / 24)
    var eq = 0.000075 + 0.001868 * cos(g)
    eq -= 0.032077 * sin(g)
    eq -= 0.014615 * cos(2 * g)
    eq -= 0.040849 * sin(2 * g)
    eq *= 229.18
    var decl = 0.006918 - 0.399912 * cos(g)
    decl += 0.070257 * sin(g)
    decl -= 0.006758 * cos(2 * g)
    decl += 0.000907 * sin(2 * g)
    decl -= 0.002697 * cos(3 * g)
    decl += 0.00148 * sin(3 * g)
    let tst = hr * 60 + eq + 4 * lon - 60 * tz
    let ha = tst / 4 - 180
    func elev(_ hAngle: Double, _ de: Double) -> Double {
        let la = latitude * Double.pi / 180
        let cz = sin(la) * sin(de) + cos(la) * cos(de) * cos(hAngle * Double.pi / 180)
        return 90 - acos(max(-1, min(1, cz))) * 180 / Double.pi
    }
    var mha = ha + 180
    if mha > 180 { mha -= 360 }
    return SolarState(elev: elev(ha, decl), ha: ha, moonElev: elev(mha, -decl), moonHa: mha)
}

func smooth(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
    let t = min(1, max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

final class SceneView: NSView {
    let sky = CAGradientLayer()
    let starsBox = CALayer(), stars = CALayer(), twinkle = CALayer()
    let auroraBox = CALayer(), auroraA = CALayer(), auroraB = CALayer()
    let sun = CALayer(), moon = CALayer()
    let night = CALayer(), day = CALayer()
    let dusk = CALayer()
    let glow = CALayer()
    let smoke = CAEmitterLayer()
    var chimney = CGPoint(x: 0.40625, y: 0.6528)
    var horizon: CGFloat = 0.62
    var imgRect = CGRect.zero
    var season: Season = .winter
    // облака и туман
    let cloudBox = CALayer(), fogBox = CALayer(), flashL = CALayer()
    var cloudTints: [CALayer] = []
    var fogTints: [CALayer] = []
    var cloudCount = -1
    var skyBuiltFor = CGRect.zero

    static func loadScene(_ name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Пейзаж под сезон: осенью — золотые луга и разноцветный лес.
    func setSeason(_ s: Season) {
        guard s != season else { return }
        season = s
        let suf = s == .autumn ? "_autumn" : (s == .summer ? "_summer" : (s == .spring ? "_spring" : ""))
        // летом печь не топят — дыма из трубы нет
        smoke.birthRate = s == .summer ? 0 : 1
        CATransaction.begin()
        CATransaction.setAnimationDuration(1.5)
        night.contents = SceneView.loadScene("landscape_night" + suf) ?? SceneView.loadScene("landscape_night")
        day.contents = SceneView.loadScene("landscape_day" + suf) ?? SceneView.loadScene("landscape_day")
        CATransaction.commit()
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        let root = layer!
        root.backgroundColor = NSColor.black.cgColor
        let order: [CALayer] = [sky, starsBox, auroraBox, sun, moon, cloudBox, night, day, fogBox, dusk, glow, smoke, flashL]
        for l in order { root.addSublayer(l) }
        starsBox.addSublayer(stars); starsBox.addSublayer(twinkle)
        auroraBox.addSublayer(auroraA); auroraBox.addSublayer(auroraB)

        func load(_ name: String) -> CGImage? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
                  let img = NSImage(contentsOf: url) else { return nil }
            return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        stars.contents = load("stars"); twinkle.contents = load("stars_twinkle")
        auroraA.contents = load("aurora_a"); auroraB.contents = load("aurora_b")
        night.contents = load("landscape_night"); day.contents = load("landscape_day")
        glow.contents = load("windows_glow"); moon.contents = load("moon")
        sun.contents = SceneView.radialImage(size: 256, stops: [
            (0, 1, 1, 0.97, 1), (0.15, 1, 0.97, 0.85, 1), (0.19, 1, 0.9, 0.7, 0.5),
            (0.45, 1, 0.85, 0.6, 0.16), (1, 1, 0.8, 0.6, 0)])
        let imgs: [CALayer] = [stars, twinkle, auroraA, auroraB, night, day, glow, moon, sun]
        for l in imgs { l.contentsGravity = .resize }
        dusk.backgroundColor = CGColor(red: 1, green: 0.55, blue: 0.25, alpha: 1)
        dusk.opacity = 0
        if let url = Bundle.main.url(forResource: "scene", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let c = j["chimney"] as? [Double], c.count == 2 { chimney = CGPoint(x: c[0], y: c[1]) }
            if let hz = j["horizon"] as? Double { horizon = CGFloat(hz) }
        }
        setupSmoke()
        startLoops()
        layoutScene()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutScene()
    }

    static func radialImage(size: Int, stops: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)]) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = stops.map { CGColor(red: $0.1, green: $0.2, blue: $0.3, alpha: $0.4) } as CFArray
        let locs = stops.map { $0.0 }
        guard let g = CGGradient(colorsSpace: cs, colors: colors, locations: locs) else { return nil }
        let c = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(size) / 2, options: [])
        return ctx.makeImage()
    }

    func setupSmoke() {
        let cell = CAEmitterCell()
        cell.name = "smoke"
        cell.contents = SceneView.radialImage(size: 64, stops: [(0, 1, 1, 1, 0.9), (0.5, 1, 1, 1, 0.35), (1, 1, 1, 1, 0)])
        cell.birthRate = 5
        cell.lifetime = 9
        cell.lifetimeRange = 2
        cell.velocity = 14
        cell.velocityRange = 4
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = 0.25
        cell.xAcceleration = 3
        cell.yAcceleration = 1
        cell.scale = 0.35
        cell.scaleSpeed = 0.12
        cell.alphaSpeed = -0.09
        cell.spin = 0.2
        cell.spinRange = 0.4
        cell.color = CGColor(red: 0.86, green: 0.87, blue: 0.9, alpha: 0.55)
        smoke.emitterShape = .point
        smoke.emitterCells = [cell]
    }

    func startLoops() {
        func loop(_ l: CALayer, _ key: String, _ from: Double, _ to: Double, _ dur: Double,
                  offset: Double = 0, additive: Bool = false) {
            let a = CABasicAnimation(keyPath: key)
            a.fromValue = from
            a.toValue = to
            a.duration = dur
            a.autoreverses = true
            a.repeatCount = .infinity
            a.isAdditive = additive
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            a.beginTime = CACurrentMediaTime() - offset
            l.add(a, forKey: key)
        }
        // северное сияние переливается и колышется
        loop(auroraA, "opacity", 0.35, 1.0, 6.5)
        loop(auroraB, "opacity", 1.0, 0.25, 9.7, offset: 3)
        loop(auroraA, "transform.translation.x", -50, 50, 17, additive: true)
        loop(auroraB, "transform.translation.x", 60, -60, 23, additive: true)
        loop(auroraA, "transform.scale.y", 0.96, 1.06, 11)
        loop(auroraB, "transform.scale.y", 1.05, 0.95, 13)
        // звёзды мерцают
        loop(twinkle, "opacity", 0.2, 1.0, 1.7)
    }

    func layoutScene() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let b = bounds
        let s = max(b.width / 3840, b.height / 2160)
        let w = 3840 * s, h = 2160 * s
        imgRect = CGRect(x: (b.width - w) / 2, y: (b.height - h) / 2, width: w, height: h)
        let full: [CALayer] = [sky, dusk, starsBox, auroraBox, smoke, flashL]
        for l in full { l.frame = b }
        let pics: [CALayer] = [stars, twinkle, auroraA, auroraB, night, day, glow]
        for l in pics { l.frame = imgRect }
        moon.bounds = CGRect(x: 0, y: 0, width: 600 * s, height: 600 * s)
        sun.bounds = CGRect(x: 0, y: 0, width: 700 * s, height: 700 * s)
        smoke.emitterPosition = CGPoint(x: imgRect.minX + chimney.x * w, y: imgRect.minY + (1 - chimney.y) * h)
        cloudBox.frame = b
        fogBox.frame = imgRect
        if imgRect != skyBuiltFor { buildSky() }
        CATransaction.commit()
    }

    /// Слой с маской по форме картинки — им подкрашиваем облака и туман (ночь, закат, пасмурно).
    static func tinted(_ img: CGImage?, _ frame: CGRect) -> (CALayer, CALayer) {
        let l = CALayer()
        l.contents = img
        l.contentsGravity = .resize
        l.frame = frame
        let tint = CALayer()
        tint.frame = l.bounds
        tint.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        tint.opacity = 0
        let m = CALayer()
        m.contents = img
        m.contentsGravity = .resize
        m.frame = tint.bounds
        tint.mask = m
        l.addSublayer(tint)
        return (l, tint)
    }

    /// Облака плывут по небу, полосы тумана — по долине. Всё анимирует видеочип.
    func buildSky() {
        let w = imgRect.width, h = imgRect.height
        guard w > 10 else { return }
        skyBuiltFor = imgRect
        cloudBox.sublayers?.forEach { $0.removeFromSuperlayer() }
        fogBox.sublayers?.forEach { $0.removeFromSuperlayer() }
        cloudTints = []
        fogTints = []
        let k = w / 3840
        let imgs = (0..<4).compactMap { SceneView.loadScene("cloud_\($0)") }
        var rng = SeededRandom(seed: 2024)
        if !imgs.isEmpty {
            for i in 0..<10 {
                let rel = CGFloat.random(in: 0.45...1.1, using: &rng)
                let cw = 1400 * k * rel, ch = 560 * k * rel
                let (layer, tint) = SceneView.tinted(imgs[i % imgs.count], CGRect(x: 0, y: 0, width: cw, height: ch))
                // маленькие (дальние) облака ниже у горизонта и плывут медленнее
                let fromTop = h * (0.05 + (1.1 - rel) * 0.38) + CGFloat.random(in: 0...(h * 0.06), using: &rng)
                layer.position = CGPoint(x: imgRect.minX - cw, y: imgRect.maxY - fromTop - ch * 0.2)
                let a = CABasicAnimation(keyPath: "position.x")
                a.fromValue = imgRect.minX - cw
                a.toValue = imgRect.maxX + cw
                let dur = Double(1500 / rel) * Double.random(in: 0.8...1.2, using: &rng)
                a.duration = dur
                a.repeatCount = .infinity
                a.beginTime = CACurrentMediaTime() - Double.random(in: 0...dur, using: &rng)
                a.isRemovedOnCompletion = false
                layer.add(a, forKey: "drift")
                layer.isHidden = i >= max(0, cloudCount)
                cloudBox.addSublayer(layer)
                cloudTints.append(tint)
            }
        }
        // туман: две бесшовные полосы, каждая едет по кругу
        let fog = SceneView.loadScene("fog_band")
        for (centerFromTop, height, dur, alpha) in [(0.735, 0.26, 420.0, 1.0), (0.63, 0.15, 700.0, 0.75)] as [(CGFloat, CGFloat, Double, Float)] {
            let bh = h * height
            let strip = CALayer()
            strip.frame = CGRect(x: 0, y: h * (1 - centerFromTop) - bh / 2, width: w * 2, height: bh)
            strip.opacity = alpha
            for t in 0..<2 {
                let (tile, tint) = SceneView.tinted(fog, CGRect(x: CGFloat(t) * w, y: 0, width: w, height: bh))
                strip.addSublayer(tile)
                fogTints.append(tint)
            }
            let a = CABasicAnimation(keyPath: "position.x")
            a.fromValue = w
            a.toValue = 0
            a.duration = dur
            a.repeatCount = .infinity
            a.isRemovedOnCompletion = false
            strip.add(a, forKey: "drift")
            fogBox.addSublayer(strip)
        }
    }

    /// Вспышка молнии: небо и пейзаж на мгновение освещаются.
    func flash() {
        flashL.backgroundColor = CGColor(red: 0.92, green: 0.94, blue: 1, alpha: 1)
        let a = CAKeyframeAnimation(keyPath: "opacity")
        a.values = [0, 0.55, 0.08, 0.4, 0]
        a.keyTimes = [0, 0.08, 0.25, 0.35, 1]
        a.duration = 0.7
        flashL.opacity = 0
        flashL.add(a, forKey: "flash")
    }

    func skyPoint(ha: Double, elev: CGFloat) -> CGPoint {
        let w = imgRect.width, h = imgRect.height
        let x = imgRect.midX + CGFloat(max(-1.15, min(1.15, ha / 90))) * w * 0.42
        // над хребтом гор: даже низкое осенне-зимнее солнце (10–15°) видно над вершинами,
        // а на закате и рассвете оно уходит за горы
        let e = max(-12, min(45, elev))
        let k = e >= 0 ? sqrt(e / 45) : -sqrt(-e / 45)
        let fromTop = h * 0.43 - k * h * 0.36
        return CGPoint(x: x, y: imgRect.maxY - fromTop)
    }

    /// Обновляет небо под время `date`. Возвращает «темноту» 0…1 (1 — ночь).
    @discardableResult
    func update(date: Date, duration: Double) -> CGFloat {
        let p = solarPosition(date)
        let e = CGFloat(p.elev)
        let me = CGFloat(p.moonElev)
        let d = smooth(-6, 4, e)
        let duskK: CGFloat = e > -12 ? exp(-pow(e / 7, 2)) : 0
        func mix(_ a: [CGFloat], _ b: [CGFloat], _ t: CGFloat) -> [CGFloat] {
            zip(a, b).map { $0 + ($1 - $0) * t }
        }
        func cg(_ c: [CGFloat]) -> CGColor { CGColor(red: c[0] / 255, green: c[1] / 255, blue: c[2] / 255, alpha: 1) }
        let pr = Prefs.shared
        let rainy = season != .winter && pr.rain
        var top = mix(mix([6, 9, 30], [70, 130, 210], d), [70, 60, 120], duskK * 0.6)
        var bot = mix(mix([40, 44, 95], [185, 212, 240], d), [250, 150, 100], duskK * 0.75)
        if rainy {
            // в дождь небо серое
            top = mix(top, [110, 118, 130], 0.6 * d)
            bot = mix(bot, [170, 176, 184], 0.6 * d)
        }
        let dark = smooth(0.55, 0.15, d)
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
        if duration == 0 { CATransaction.setDisableActions(true) }
        sky.colors = [cg(bot), cg(top)]
        starsBox.opacity = Float((1 - d) * (1 - d))
        auroraBox.opacity = Float(max(0, 1 - d * 1.5) * 0.95)
        day.opacity = Float(d)
        dusk.opacity = Float(duskK * 0.22)
        glow.opacity = Float(dark)
        sun.position = skyPoint(ha: p.ha, elev: e)
        sun.opacity = Float(smooth(-6, 1, e))
        moon.position = skyPoint(ha: p.moonHa, elev: me)
        moon.opacity = Float(smooth(-6, 1, me) * (1 - d * 0.7))

        // облака: сколько — по сезону и погоде, цвет — по времени суток
        let want = pr.clouds ? (season == .autumn ? 6 : (season == .winter ? 4 : 5)) + (rainy ? 4 : 0) : 0
        if want != cloudCount {
            cloudCount = want
            for (i, l) in (cloudBox.sublayers ?? []).enumerated() { l.isHidden = i >= want }
        }
        var tc = CGColor(red: 0.07, green: 0.08, blue: 0.16, alpha: 1)
        var ta = (1 - d) * 0.82
        if duskK > 0.25 && d > 0.15 {
            tc = CGColor(red: 1, green: 0.5, blue: 0.32, alpha: 1)
            ta = duskK * 0.45
        } else if rainy && d > 0.5 {
            tc = CGColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1)
            ta = 0.5
        }
        for t in cloudTints { t.backgroundColor = tc; t.opacity = Float(ta) }
        cloudBox.opacity = rainy ? 1 : 0.93
        if rainy { sun.opacity *= 0.25 }

        // туман: гуще утром на рассвете и ночью, осенью сильнее, чем зимой
        let morning = p.ha < 0 ? exp(-pow((e - 2) / 9, 2)) : 0
        var f = 0.15 + 0.8 * morning + 0.3 * (1 - d)
        f *= season == .autumn ? 1 : (season == .summer ? 0.4 : (season == .spring ? 0.8 : 0.55))
        if rainy { f += 0.3 }
        if !pr.fog { f = 0 }
        fogBox.opacity = Float(min(1, f))
        for t in fogTints {
            t.backgroundColor = duskK > 0.25 && d > 0.15
                ? CGColor(red: 1, green: 0.62, blue: 0.45, alpha: 1)
                : CGColor(red: 0.2, green: 0.23, blue: 0.36, alpha: 1)
            t.opacity = Float(duskK > 0.25 && d > 0.15 ? duskK * 0.35 : (1 - d) * 0.75)
        }
        CATransaction.commit()
        return dark
    }
}

/// Верхний прозрачный слой: только гирлянда (и правка её точек).
final class GarlandView: NSView {
    weak var snow: SnowView?
    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let s = snow else { return }
        ctx.clear(dirtyRect)
        if s.garland { s.drawGarland(ctx) }
        if s.prefs.editGarland {
            // подсказка, пока включена расстановка точек
            let text = "Расстановка гирлянды: клик — точка, правый клик — удалить. Закрой окно настроек, чтобы закончить." as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                                                        .foregroundColor: NSColor.white]
            let size = text.size(withAttributes: attrs)
            let r = CGRect(x: (bounds.width - size.width) / 2 - 14, y: s.ceiling - 46, width: size.width + 28, height: size.height + 12)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: 9, cornerHeight: 9, transform: nil))
            ctx.setFillColor(CGColor(red: 0.1, green: 0.35, blue: 0.85, alpha: 0.9))
            ctx.fillPath()
            NSGraphicsContext.saveGraphicsState()
            text.draw(at: CGPoint(x: r.minX + 14, y: r.minY + 6), withAttributes: attrs)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    override func mouseDown(with e: NSEvent) {
        let ctrl = e.modifierFlags.contains(.control)
        snow?.garlandMouseDown(convert(e.locationInWindow, from: nil), right: ctrl,
                               option: e.modifierFlags.contains(.option))
    }

    override func mouseDragged(with e: NSEvent) {
        snow?.garlandDrag(convert(e.locationInWindow, from: nil))
    }

    override func mouseUp(with e: NSEvent) { snow?.dragJoint = nil }

    override func rightMouseDown(with e: NSEvent) {
        snow?.garlandMouseDown(convert(e.locationInWindow, from: nil), right: true, option: false)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var view: SnowView!
    var statusItem: NSStatusItem!
    var tour: DemoTour?
    var timer: Timer?
    var snowItem: NSMenuItem!
    var shovelItem: NSMenuItem!
    var playItem: NSMenuItem!
    var garlandItem: NSMenuItem!
    var garlandAutoItem: NSMenuItem!
    var wallItem: NSMenuItem!
    var demoItem: NSMenuItem!
    var sceneWindow: NSWindow!
    var scene: SceneView!
    var sceneTimer: Timer?
    var demo = false
    var demoStart = Date()
    var demoBase = Date()
    var frameCount = 0
    var topWindow: NSWindow!
    var garlandView: GarlandView!
    var overItem: NSMenuItem!
    static var belowWindowsLevel: NSWindow.Level { NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1) }
    /// Слой сцены: ниже обычных окон, но выше иконок рабочего стола и виджетов (чтобы гирлянда цеплялась к виджетам поверх).
    var lowerLevel: NSWindow.Level {
        let base = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
        // никогда не выше обычных окон, даже если виджет временно поднят (например, пока его тащат)
        let top = NSWindow.Level.normal.rawValue - 1
        return NSWindow.Level(rawValue: min(top, max(base, view.widgetLayer + 1)))
    }
    var snowfall: SnowfallView!
    var settingsWindow: NSWindow?
    var winTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        // ниже обычных окон, но выше обоев и иконок рабочего стола
        window.level = AppDelegate.belowWindowsLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        view = SnowView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        window.contentView = view
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()

        // гирлянда — отдельным слоем поверх окон (её можно натянуть между окнами)
        topWindow = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        topWindow.isOpaque = false
        topWindow.backgroundColor = .clear
        topWindow.hasShadow = false
        topWindow.ignoresMouseEvents = true
        topWindow.level = .statusBar
        topWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        garlandView = GarlandView(frame: NSRect(origin: .zero, size: screen.frame.size))
        garlandView.wantsLayer = true
        garlandView.snow = view
        topWindow.contentView = garlandView
        topWindow.setFrame(screen.frame, display: true)
        topWindow.orderFrontRegardless()
        view.garlandView = garlandView
        view.resetHeights()
        updateGround()
        view.renderScale = window.backingScaleFactor
        snowfall = SnowfallView(frame: view.bounds)
        snowfall.autoresizingMask = [.width, .height]
        view.addSubview(snowfall)
        snowfall.update(size: view.bounds.size, amount: CGFloat(view.prefs.snowAmount), snowing: true, wind: 0)

        // живые обои — под иконками рабочего стола
        sceneWindow = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        sceneWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        sceneWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        sceneWindow.ignoresMouseEvents = true
        sceneWindow.hasShadow = false
        scene = SceneView(frame: NSRect(origin: .zero, size: screen.frame.size))
        sceneWindow.contentView = scene
        sceneWindow.setFrame(screen.frame, display: true)
        sceneWindow.orderFrontRegardless()
        view.nightLevel = scene.update(date: Date(), duration: 0)
        restartSceneTimer()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "❄️"
        let menu = NSMenu()
        snowItem = add(menu, "Снегопад", #selector(toggleSnow))
        snowItem.state = .on
        playItem = add(menu, "Играть мышкой (снежки, снеговики)", #selector(togglePlay))
        playItem.state = .on
        shovelItem = add(menu, "Лопата (копать курсором)", #selector(toggleShovel))
        garlandItem = add(menu, "Гирлянда", #selector(toggleGarland))
        garlandItem.state = .on
        garlandAutoItem = add(menu, "Гирлянда загорается в темноте", #selector(toggleGarlandAuto))
        garlandAutoItem.state = .on
        wallItem = add(menu, "🏔 Живые обои", #selector(toggleWall))
        wallItem.state = .on
        demoItem = add(menu, "⏩ Сутки за 2 минуты (демо)", #selector(toggleDemo))
        menu.addItem(.separator())
        _ = add(menu, "⚙️ Настройки…", #selector(openSettings))
        overItem = add(menu, "Снег и персонажи поверх окон", #selector(toggleOver))
        menu.addItem(.separator())
        _ = add(menu, "🎲 Случайное событие", #selector(randomEvent))
        _ = add(menu, "🐾 Позвать йети", #selector(callYeti))
        _ = add(menu, "💨 Порыв ветра", #selector(gust))
        _ = add(menu, "🛷 Сани Деда Мороза", #selector(sleigh))
        _ = add(menu, "⛄ Слепить снеговика", #selector(snowman))
        _ = add(menu, "🚙 Вызвать снегоуборщик", #selector(tractor))
        _ = add(menu, "Очистить", #selector(clear))
        menu.addItem(.separator())
        _ = add(menu, "Выйти", #selector(quit))
        _ = menu   // старое меню больше не показываем — всё в окне
        statusItem.button?.target = self
        statusItem.button?.action = #selector(openSettings)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAction(_:)),
                                               name: Prefs.actionNote, object: nil)

        let tm = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick),
                       userInfo: nil, repeats: true)
        RunLoop.main.add(tm, forMode: .common)
        timer = tm

        // окна проверяем 5 раз в секунду — этого хватает, чтобы снег осыпался при перемещении
        let wt = Timer(timeInterval: 0.2, target: self, selector: #selector(windowsTick), userInfo: nil, repeats: true)
        RunLoop.main.add(wt, forMode: .common)
        winTimer = wt

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    func add(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    func updateGround() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        // верхний край Dock (если Dock внизу); иначе — низ экрана
        view.ground = max(0, screen.visibleFrame.minY - screen.frame.minY)
        view.ceiling = screen.visibleFrame.maxY - screen.frame.minY
    }

    @objc func tick() {
        frameCount += 1
        if frameCount % 60 == 0 { updateGround() }
        let m = NSEvent.mouseLocation
        view.mouse = CGPoint(x: m.x - window.frame.minX, y: m.y - window.frame.minY)
        view.step()
        let inSettings = settingsWindow.map { $0.isVisible && $0.frame.contains(m) } ?? false
        var want = view.playEnabled && view.wantsMouse(at: view.mouse)
        if inSettings { want = false }
        if window.ignoresMouseEvents == want { window.ignoresMouseEvents = !want }
        // правка точек гирлянды — через верхний слой
        // расстановка точек работает, только пока открыто окно настроек
        if view.prefs.editGarland && !(settingsWindow.map { $0.isVisible && !$0.isMiniaturized } ?? false) {
            view.prefs.editGarland = false
        }
        let edit = view.prefs.editGarland && !inSettings && view.mouse.y < view.ceiling
        if topWindow.ignoresMouseEvents == edit { topWindow.ignoresMouseEvents = !edit }
        // рисуем 30 раз в секунду и только там, где что-то меняется
        if frameCount % 2 == 0 { view.invalidateDirty() }
        if frameCount % 15 == 0 { syncPrefs() }
        if frameCount % 30 == 0 { DemoTour.check(self) }
        if frameCount % 30 == 0 {
            let p = view.prefs
            snowfall.update(size: view.bounds.size, amount: CGFloat(p.fallAmount),
                            snowing: view.snowing, wind: view.wind, season: view.season,
                            rain: p.raining ? CGFloat(p.rainAmount) : 0)
        }
        // молнии в летнюю грозу
        if view.season == .summer && view.prefs.rain && sceneWindow.isVisible
            && CGFloat.random(in: 0...1) < CGFloat(view.prefs.rainAmount) / (60 * 14) {
            scene.flash()
        }
    }

    @objc func windowsTick() { view.refreshWindows() }

    @objc func handleAction(_ n: Notification) {
        guard let name = n.object as? String else { return }
        switch name {
        case "snowman": view.buildSnowman()
        case "leafgust": view.leafShower()
        case "birds":
            for _ in 0..<3 {
                let tg = view.birdTarget()
                let left = Bool.random()
                view.birds.append(Bird(x: left ? -20 : view.bounds.width + 20, y: view.ceiling - 80, vx: 0, vy: 0,
                                       phase: 0, tx: tg.0, ty: tg.1, perchWin: tg.2, perchDX: tg.3))
            }
        case "kite": view.spawn(.kid)
        case "respring": if view.season == .spring { view.startSpring() }
        case "butterflies":
            for _ in 0..<3 { view.butterflies.append(view.newButterfly(fromLeft: Bool.random())) }
        case "bubbles":
            let w = view.bounds.width
            for _ in 0..<4 {
                view.blowBubbles(at: CGPoint(x: CGFloat.random(in: w * 0.2...w * 0.8), y: view.ground + 30), count: 5)
            }
        case "plow": view.callTractor()
        case "sleigh": view.callSleigh()
        case "yeti": if view.season == .winter { view.spawn(.yeti) }
        case "janitor": view.spawn(.janitor)
        case "event": view.spawnRandomEvent()
        case "gust": view.gust()
        case "clear": view.clearAll()
        case "quit": NSApp.terminate(nil)
        default: break
        }
    }

    /// Переносим переключатели из окна настроек в сцену.
    func syncPrefs() {
        let p = view.prefs
        view.snowing = p.snowing
        view.playEnabled = p.play
        view.shovel = p.shovel
        view.garland = p.garlandOn && (p.season == .winter || p.garlandAllYear)
        view.garlandAuto = p.garlandAuto
        if p.wallpaper != sceneWindow.isVisible { toggleWall() }
        scene.setSeason(view.season)
        // значок в строке меню — по сезону
        let icon: String
        switch view.season {
        case .winter: icon = "❄️"
        case .spring: icon = "🌸"
        case .summer: icon = "☀️"
        case .autumn: icon = "🍂"
        }
        if statusItem.button?.title != icon { statusItem.button?.title = icon }
        if p.demo != demo { toggleDemo() }
        if p.overWindows != (window.level == .statusBar) { toggleOver() }
        let lower = lowerLevel
        if !p.overWindows && window.level != lower { window.level = lower }
        // гирлянда: по умолчанию позади окон, поверх — по настройке или пока расставляем точки
        let gl: NSWindow.Level = (p.garlandOver || p.editGarland) ? .statusBar : lower
        if topWindow.level != gl {
            topWindow.level = gl
            topWindow.orderFrontRegardless()
        }
    }

    @objc func toggleOver() {
        let over = window.level != .statusBar
        window.level = over ? .statusBar : lowerLevel
        overItem.state = over ? .on : .off
    }

    @objc func randomEvent() { view.spawnRandomEvent() }

    @objc func callYeti() { view.spawn(.yeti) }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "SnowDesk — настройки"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            settingsWindow = w
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func screensChanged() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        window.setFrame(screen.frame, display: true)
        topWindow.setFrame(screen.frame, display: true)
        garlandView.frame = NSRect(origin: .zero, size: screen.frame.size)
        view.frame = NSRect(origin: .zero, size: screen.frame.size)
        sceneWindow.setFrame(screen.frame, display: true)
        scene.frame = NSRect(origin: .zero, size: screen.frame.size)
        view.renderScale = window.backingScaleFactor
        view.prefsVersion = -1
        view.resetHeights()
        updateGround()
    }

    @objc func toggleSnow() {
        view.snowing.toggle()
        snowItem.state = view.snowing ? .on : .off
    }

    @objc func toggleShovel() {
        view.shovel.toggle()
        shovelItem.state = view.shovel ? .on : .off
    }

    @objc func toggleGarland() {
        view.garland.toggle()
        garlandItem.state = view.garland ? .on : .off
    }

    @objc func sleigh() { view.callSleigh() }

    func sceneDate() -> Date {
        demo ? demoBase.addingTimeInterval(Date().timeIntervalSince(demoStart) * 720) : Date()
    }

    func restartSceneTimer() {
        sceneTimer?.invalidate()
        let iv = demo ? 0.25 : 5.0
        let tm = Timer(timeInterval: iv, target: self, selector: #selector(sceneTick), userInfo: nil, repeats: true)
        RunLoop.main.add(tm, forMode: .common)
        sceneTimer = tm
    }

    @objc func sceneTick() {
        let dur = demo ? 0.25 : 5.0
        view.nightLevel = scene.update(date: sceneDate(), duration: dur)
    }

    @objc func toggleGarlandAuto() {
        view.garlandAuto.toggle()
        garlandAutoItem.state = view.garlandAuto ? .on : .off
    }

    @objc func toggleWall() {
        if sceneWindow.isVisible { sceneWindow.orderOut(nil) } else { sceneWindow.orderFrontRegardless() }
        wallItem.state = sceneWindow.isVisible ? .on : .off
    }

    @objc func toggleDemo() {
        demo.toggle()
        demoStart = Date()
        demoBase = Date()
        demoItem.state = demo ? .on : .off
        if !demo { view.nightLevel = scene.update(date: Date(), duration: 1) }
        restartSceneTimer()
    }

    @objc func togglePlay() {
        view.playEnabled.toggle()
        playItem.state = view.playEnabled ? .on : .off
    }

    @objc func gust() { view.gust() }
    @objc func snowman() { view.buildSnowman() }
    @objc func tractor() { view.callTractor() }
    @objc func clear() { view.clearAll() }
    @objc func quit() { NSApp.terminate(nil) }
}

// Запуск на главном потоке (требование Swift 6)
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
