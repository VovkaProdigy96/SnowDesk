// SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/)
// Мир SnowDesk: снег на окнах, гирлянда, ёлка, домики у Dock, прохожие, дети, собаки, кошки и йети.

import AppKit

/// Снег на верхнем крае окна. radius — скругление углов окна: на скруглениях снег не держится и ссыпается.
struct WindowCap {
    var rect: CGRect
    var h: [CGFloat]
    var radius: CGFloat = 12
    var spill: [CGFloat] = [0, 0]   // накопленный «ссып» с левого и правого края
}

/// Отрезок гирлянды как верёвка (физика Верле): точки, их прошлые позиции и длина звена.
struct Rope { var pts: [CGPoint]; var prev: [CGPoint]; var rest: CGFloat }

enum WalkerKind { case person, kid, dog, cat, yeti, janitor }

struct Walker {
    var id: Int
    var kind: WalkerKind
    var x: CGFloat
    var dir: CGFloat
    var speed: CGFloat
    var phase: CGFloat = 0
    var state = 0                 // 0 — идёт, 1 — занят делом, 2 — уходит
    var timer: CGFloat = 0
    var stopX: CGFloat = -1
    var c1: (CGFloat, CGFloat, CGFloat) = (0.2, 0.3, 0.6)
    var c2: (CGFloat, CGFloat, CGFloat) = (0.8, 0.1, 0.1)
    var throwsLeft = 0
    var lastPrint: CGFloat = -1000
    var hit: CGFloat = 0          // реакция на попадание снежком
    var scale: CGFloat = 1
}

enum DecorItem {
    case house(CGFloat, CGFloat, CGFloat, Bool)
    case fir(CGFloat)
    case lamp
    case stall(CGFloat, CGFloat, CGFloat)
    case brownstone(CGFloat, CGFloat, CGFloat)
    case gifts
    case pumpkins
    case flowers
}

/// Простой генератор случайных чисел с зерном — чтобы ёлка не менялась каждый кадр.
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 33)) &* 0xff51afd7ed558ccd
        return z ^ (z >> 33)
    }
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func linGrad(_ c1: CGColor, _ c2: CGColor) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c1, c2] as CFArray, locations: [0, 1])!
}

extension SnowView {
    static let jackets: [(CGFloat, CGFloat, CGFloat)] = [
        (0.8, 0.15, 0.15), (0.15, 0.35, 0.75), (0.95, 0.65, 0.1), (0.2, 0.55, 0.3),
        (0.55, 0.2, 0.6), (0.25, 0.27, 0.32), (0.9, 0.4, 0.55), (0.1, 0.55, 0.6)]
    static let dogColors: [(CGFloat, CGFloat, CGFloat)] = [
        (0.55, 0.35, 0.18), (0.12, 0.1, 0.1), (0.85, 0.65, 0.35), (0.6, 0.6, 0.62)]
    static let catColors: [(CGFloat, CGFloat, CGFloat)] = [
        (0.9, 0.55, 0.2), (0.15, 0.15, 0.17), (0.6, 0.6, 0.62), (0.95, 0.93, 0.9)]

    var treeHeightPt: CGFloat { [150, 200, 260][max(0, min(2, prefs.treeSize))] }
    var treeX: CGFloat { bounds.width * 0.22 }
    var treeStanding: Bool { prefs.treeOn && treeFall == 0 && treeImage != nil }

    // MARK: - Общий шаг мира

    func worldStep() {
        checkSeason()
        autumnStep()
        summerStep()
        springStep()
        if prefsVersion != prefs.version {
            prefsVersion = prefs.version
            rebuildTree()
            rebuildDecor()
        }
        if customCarVersion != prefs.version {
            customCarVersion = prefs.version
            customCar = nil
            if prefs.carMode == 1 && !prefs.carImagePath.isEmpty,
               let img = NSImage(contentsOfFile: prefs.carImagePath) {
                customCar = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        }
        ropeStep()
        treeStep()
        autoServices()
        eventStep()
        walkerStep()
    }

    func makeImage(width: CGFloat, height: CGFloat, _ draw: (CGContext) -> Void) -> CGImage? {
        let sc = renderScale
        let wpx = Int(width * sc), hpx = Int(height * sc)
        guard wpx > 0, hpx > 0,
              let ctx = CGContext(data: nil, width: wpx, height: hpx, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: sc, y: sc)
        draw(ctx)
        return ctx.makeImage()
    }

    func glowSpot(_ ctx: CGContext, _ p: CGPoint, _ rad: CGFloat, _ c: (CGFloat, CGFloat, CGFloat), _ a: CGFloat) {
        guard a > 0.01 else { return }
        let g = linGrad(rgb(c.0, c.1, c.2, a), rgb(c.0, c.1, c.2, 0))
        ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: rad, options: [])
    }

    // MARK: - Снег на окнах

    func refreshWindows() {
        guard prefs.windowSnow else {
            if !caps.isEmpty { caps.removeAll() }
            winRects = []
            return
        }
        // список окон спрашиваем у системы в фоне: во время анимаций (сворачивание, Mission Control)
        // этот вызов может подвисать, и раньше из-за него замирала вся сцена
        if winQueryBusy { return }
        winQueryBusy = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                  kCGNullWindowID) as? [[String: Any]]
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    self.winQueryBusy = false
                    if let info = info, self.prefs.windowSnow { self.applyWindows(info) }
                }
            }
        }
    }

    func applyWindows(_ info: [[String: Any]]) {
        let myPID = Int(ProcessInfo.processInfo.processIdentifier)
        let H = bounds.height
        var list: [(id: UInt32, rect: CGRect, owner: String)] = []
        var foundWidgetLayer = Int(Int32.min)
        defer { widgetLayer = foundWidgetLayer }
        for w in info {
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            // виджеты рабочего стола живут на своём слое у процесса «Центр уведомлений»
            let isWidget = prefs.widgetSnow
                && (owner.contains("Notification") || owner.contains("Widget") || owner.contains("уведомлен")
                    || owner.contains("Виджет"))
            guard layer == 0 || isWidget,
                  (w[kCGWindowOwnerPID as String] as? Int) != myPID,
                  let num = w[kCGWindowNumber as String] as? Int,
                  let bd = w[kCGWindowBounds as String] as? [String: Any],
                  let r = CGRect(dictionaryRepresentation: bd as CFDictionary) else { continue }
            if let a = w[kCGWindowAlpha as String] as? Double, a < 0.1 { continue }
            if isWidget && layer < 0 { foundWidgetLayer = max(foundWidgetLayer, layer) }
            if r.width < 120 || r.height < 60 { continue }
            if isWidget && (r.width > 900 || r.height > 900) { continue }
            var vr = CGRect(x: r.minX, y: H - r.maxY, width: r.width, height: r.height)
            // у окна виджета есть прозрачные поля вокруг карточки
            if isWidget { vr = vr.insetBy(dx: 8, dy: 8) }
            if vr.maxY > ceiling + 2 || vr.maxY < ground + 40 { continue }
            list.append((id: UInt32(num), rect: vr, owner: owner))
            if list.count >= 14 { break }
        }
        var newCaps: [UInt32: WindowCap] = [:]
        for item in list {
            let n = max(1, Int(item.rect.width / col))
            if let c = caps[item.id] {
                let moved = abs(c.rect.minX - item.rect.minX) > 1.5 || abs(c.rect.maxY - item.rect.maxY) > 1.5
                    || abs(c.rect.width - item.rect.width) > 1.5
                if moved {
                    // окно сдвинули — снег осыпается (при сворачивании окно резко сжимается — тогда без осыпания)
                    if abs(c.rect.width - item.rect.width) < c.rect.width * 0.2 { shedCap(c) }
                    newCaps[item.id] = WindowCap(rect: item.rect, h: Array(repeating: 0, count: n), radius: radiusFor(item.owner))
                } else {
                    newCaps[item.id] = c
                }
            } else {
                newCaps[item.id] = WindowCap(rect: item.rect, h: Array(repeating: 0, count: n), radius: radiusFor(item.owner))
            }
        }
        caps = newCaps
        winRects = list
    }

    func shedCap(_ c: WindowCap) {
        let step = max(2, c.h.count / 60)   // не больше ~60 комочков с одного окна
        for (k, hh) in c.h.enumerated() where hh > 0.8 && k % step == 0 && particles.count < 900 {
            particles.append(Particle(x: c.rect.minX + CGFloat(k) * col, y: c.rect.maxY + hh / 2,
                                      vx: CGFloat.random(in: -0.6...0.6), vy: CGFloat.random(in: 0...1.2),
                                      r: min(4, 1 + hh * 0.35)))
        }
    }

    /// Закрыта ли точка окнами, которые лежат выше (ближе к нам), чем окно с номером `idx`.
    func covered(_ p: CGPoint, before idx: Int) -> Bool {
        var i = 0
        while i < idx && i < winRects.count {
            if winRects[i].rect.contains(p) { return true }
            i += 1
        }
        return false
    }

    /// Скругление углов: у виджетов карточка круглее, у обычных окон — меньше.
    func radiusFor(_ owner: String) -> CGFloat {
        let widget = owner.contains("Notification") || owner.contains("Widget") || owner.contains("уведомлен")
            || owner.contains("Виджет")
        return widget ? 22 : 12
    }

    /// Насколько поверхность окна ниже верхнего края в столбце k (на скруглённом углу).
    func capDrop(_ c: WindowCap, _ k: Int) -> CGFloat {
        let x = (CGFloat(k) + 0.5) * col
        let dx = min(x, c.rect.width - x)
        let r = min(c.radius, c.rect.width / 2)
        guard dx < r else { return 0 }
        let u = r - dx
        return r - sqrt(max(0, r * r - u * u))
    }

    /// Сколько снега удержится в столбце: на ровном — до 9 пт, на крутом скате угла — почти ничего.
    func capCapacity(_ c: WindowCap, _ k: Int) -> CGFloat {
        let slope = abs(capDrop(c, k) - capDrop(c, k + (k < c.h.count / 2 ? 1 : -1))) / col
        return max(0, 9 * (1 - slope * 1.15))
    }

    /// Снег медленно копится на сугробе у Dock и на верхних краях окон.
    /// Скорость зависит только от ползунка «Сила снегопада»:
    /// при максимуме ровный край окна заполняется примерно за 3 минуты, сугроб у Dock — за ~6 минут,
    /// при минимуме — в 6–7 раз медленнее.
    func depositSnow() {
        guard snowing, !heights.isEmpty, !isSummer, !isSpring else { return }
        depositTick += 1
        let every = 6                                   // считаем 10 раз в секунду, а не 60 — дешевле
        guard depositTick % every == 0 else { return }
        let amt = CGFloat(prefs.fallAmount)
        let dt = CGFloat(every) / 60                    // секунд на шаг

        // сугроб у Dock: ~30 пт за 6 минут при максимуме
        let pileRate = 30.0 / 360.0 * amt * dt * (isAutumn ? 0.6 : 1)
        for i in stride(from: Int.random(in: 0..<3), to: heights.count, by: 3) {
            let x = (CGFloat(i) + 0.5) * col
            if covered(CGPoint(x: x, y: ground + heights[i] + 2), before: winRects.count) { continue }
            let a = pileRate * 3 * CGFloat.random(in: 0.3...1.7)
            heights[i] = min(maxHeight, heights[i] + a * 0.5)
            if i > 0 { heights[i - 1] = min(maxHeight, heights[i - 1] + a * 0.25) }
            if i < heights.count - 1 { heights[i + 1] = min(maxHeight, heights[i + 1] + a * 0.25) }
        }

        // края окон: ~9 пт за 3 минуты при максимуме
        let capRate = 9.0 / 180.0 * amt * dt
        for (i, wr) in winRects.enumerated() {
            guard var c = caps[wr.id], c.h.count > 2 else { continue }
            let n = c.h.count
            for k in 0..<n {
                let capK = capCapacity(c, k)
                // на крутом скате угла снежинки почти не задерживаются
                let stick = min(1, capK / 9)
                guard stick > 0.05 else { continue }
                let px = wr.rect.minX + (CGFloat(k) + 0.5) * col
                if covered(CGPoint(x: px, y: wr.rect.maxY - capDrop(c, k) + 1), before: i) { continue }
                c.h[k] += capRate * stick * CGFloat.random(in: 0.2...1.8)
            }
            // выравнивание: снег медленно перетекает к соседям по склону
            for j in 0..<(n - 1) {
                let d = (c.h[j] - capDrop(c, j)) - (c.h[j + 1] - capDrop(c, j + 1))
                if abs(d) > 2 {
                    let m = min((abs(d) - 2) * 0.1, d > 0 ? c.h[j] : c.h[j + 1]) * (d > 0 ? 1 : -1)
                    c.h[j] -= m
                    c.h[j + 1] += m
                }
            }
            // лишнее на скруглённых углах ползёт к краю; ссыпается комочком, только когда накопится
            for k in 0..<n {
                let capK = capCapacity(c, k)
                guard c.h[k] > capK else { continue }
                let excess = c.h[k] - capK
                c.h[k] = capK
                let outward = k < n / 2 ? -1 : 1
                let nk = k + outward
                if nk >= 0 && nk < n {
                    c.h[nk] += excess
                } else {
                    let side = outward < 0 ? 0 : 1
                    c.spill[side] += excess
                    if c.spill[side] > 1.2 && particles.count < 1500 {
                        let clump = min(6, Int(c.spill[side] / 0.4))
                        c.spill[side] = 0
                        let x = outward < 0 ? wr.rect.minX - 1 : wr.rect.maxX + 1
                        for _ in 0..<clump {
                            particles.append(Particle(x: x, y: wr.rect.maxY - c.radius + CGFloat.random(in: -2...2),
                                                      vx: CGFloat(outward) * CGFloat.random(in: 0.3...1.0),
                                                      vy: CGFloat.random(in: -0.5...0.3), r: CGFloat.random(in: 1.2...2.4)))
                        }
                    }
                }
            }
            caps[wr.id] = c
        }
    }

    func drawWindowCaps(_ ctx: CGContext) {
        guard prefs.windowSnow, !isSummer else { return }
        for (i, wr) in winRects.enumerated().reversed() {
            guard let c = caps[wr.id] else { continue }
            let top = wr.rect.maxY
            func px(_ k: Int) -> CGFloat { wr.rect.minX + (CGFloat(k) + 0.5) * col }
            func visible(_ k: Int) -> Bool {
                c.h[k] >= 0.3 && !covered(CGPoint(x: px(k), y: top - capDrop(c, k) + 1), before: i)
            }
            var k = 0
            while k < c.h.count {
                while k < c.h.count && !visible(k) { k += 1 }
                if k >= c.h.count { break }
                let start = k
                while k < c.h.count && visible(k) { k += 1 }
                let end = k - 1
                // снег лежит поверх формы окна: по скруглённым углам он идёт вниз вместе с ними
                let path = CGMutablePath()
                path.move(to: CGPoint(x: px(start) - col / 2, y: top - capDrop(c, start)))
                for q in start...end { path.addLine(to: CGPoint(x: px(q), y: top - capDrop(c, q) + c.h[q])) }
                path.addLine(to: CGPoint(x: px(end) + col / 2, y: top - capDrop(c, end)))
                for q in stride(from: end, through: start, by: -1) {
                    path.addLine(to: CGPoint(x: px(q), y: top - capDrop(c, q) - 0.5))
                }
                path.closeSubpath()
                if isAutumn {
                    fillLeafCap(ctx, path)
                } else {
                    ctx.saveGState()
                    ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 3, color: rgb(0.2, 0.3, 0.5, 0.35))
                    ctx.addPath(path)
                    ctx.setFillColor(rgb(0.97, 0.98, 1))
                    ctx.fillPath()
                    ctx.restoreGState()
                }
            }
        }
    }

    // MARK: - Гирлянда (физическая)

    func garlandPoint(_ a: CGPoint, _ b: CGPoint, _ u: CGFloat) -> CGPoint {
        let d = hypot(b.x - a.x, b.y - a.y)
        let sag = (12 + d * 0.12) * CGFloat(0.3 + prefs.garlandSlack * 1.4)
        return CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u - sin(.pi * u) * sag)
    }

    /// Где сейчас точка: если она привязана к окну или виджету — едет вместе с ним.
    func jointPos(_ j: GJoint) -> CGPoint {
        guard j.attached else { return CGPoint(x: j.x, y: j.y) }
        if let wid = jointWin[j.id], let wr = winRects.first(where: { $0.id == wid }) {
            return CGPoint(x: wr.rect.minX + CGFloat(j.ox), y: wr.rect.maxY + CGFloat(j.oy))
        }
        // после перезапуска ищем то же окно: тот же владелец и примерно то же место
        if let wr = winRects.first(where: {
            $0.owner == j.owner && abs($0.rect.minX + CGFloat(j.ox) - CGFloat(j.x)) < 80
                && abs($0.rect.maxY + CGFloat(j.oy) - CGFloat(j.y)) < 80
        }) {
            jointWin[j.id] = wr.id
            return CGPoint(x: wr.rect.minX + CGFloat(j.ox), y: wr.rect.maxY + CGFloat(j.oy))
        }
        return CGPoint(x: j.x, y: j.y)
    }

    func garlandSegments() -> [(key: String, a: CGPoint, b: CGPoint)] {
        let w = bounds.width
        var out: [(key: String, a: CGPoint, b: CGPoint)] = []
        switch prefs.garlandMode {
        case 1:
            var pts: [CGPoint] = [CGPoint(x: 0, y: ceiling - 4)]
            let wins = winRects.prefix(6).map { $0.rect }.sorted { $0.minX < $1.minX }
            for r in wins {
                pts.append(CGPoint(x: r.minX + 10, y: r.maxY - 2))
                pts.append(CGPoint(x: r.maxX - 10, y: r.maxY - 2))
            }
            pts.append(CGPoint(x: w, y: ceiling - 4))
            for k in 0..<(pts.count - 1) { out.append((key: "w\(k)", a: pts[k], b: pts[k + 1])) }
        case 2:
            var pos: [Int: CGPoint] = [:]
            for j in prefs.gJoints { pos[j.id] = jointPos(j) }
            for s in prefs.gSegs {
                if let a = pos[s.a], let b = pos[s.b] { out.append((key: "c\(s.a)-\(s.b)", a: a, b: b)) }
            }
        default:
            var x: CGFloat = 0
            var k = 0
            while x < w {
                let nx = min(w, x + 240)
                out.append((key: "t\(k)", a: CGPoint(x: x, y: ceiling - 4), b: CGPoint(x: nx, y: ceiling - 4)))
                x = nx
                k += 1
            }
        }
        return out
    }

    /// Шаг физики: провод провисает, качается от ветра, курсора и движения окон.
    func ropeStep() {
        mouseVel = CGPoint(x: mouse.x - lastMouse.x, y: mouse.y - lastMouse.y)
        lastMouse = mouse
        guard garland else {
            if !ropes.isEmpty { ropes.removeAll() }
            return
        }
        let segs = garlandSegments()
        var keep = Set<String>()
        let slackK = CGFloat(1.02 + prefs.garlandSlack * 0.22)
        let speed = hypot(mouseVel.x, mouseVel.y)
        for s in segs {
            keep.insert(s.key)
            let d = max(1, hypot(s.b.x - s.a.x, s.b.y - s.a.y))
            let n = max(6, min(40, Int(d / 14)))
            var r: Rope
            if let old = ropes[s.key], old.pts.count == n {
                r = old
            } else {
                var pts: [CGPoint] = []
                for i in 0..<n { pts.append(garlandPoint(s.a, s.b, CGFloat(i) / CGFloat(n - 1))) }
                r = Rope(pts: pts, prev: pts, rest: 0)
            }
            r.rest = d * slackK / CGFloat(n - 1)
            for i in 1..<(n - 1) {
                let p = r.pts[i]
                let vx = (p.x - r.prev[i].x) * 0.985
                let vy = (p.y - r.prev[i].y) * 0.985
                r.prev[i] = p
                var np = CGPoint(x: p.x + vx + wind * 0.012 * CGFloat.random(in: 0.4...1.6), y: p.y + vy - 0.35)
                if speed > 0.5 && hypot(np.x - mouse.x, np.y - mouse.y) < 24 {
                    np.x += mouseVel.x * 0.45
                    np.y += mouseVel.y * 0.45
                }
                r.pts[i] = np
            }
            r.pts[0] = s.a
            r.pts[n - 1] = s.b
            for _ in 0..<14 {
                for i in 0..<(n - 1) {
                    let a = r.pts[i], b = r.pts[i + 1]
                    let dx = b.x - a.x, dy = b.y - a.y
                    let dist = max(0.001, hypot(dx, dy))
                    let diff = (dist - r.rest) / dist * 0.5
                    if i != 0 { r.pts[i].x += dx * diff; r.pts[i].y += dy * diff }
                    if i + 1 != n - 1 { r.pts[i + 1].x -= dx * diff; r.pts[i + 1].y -= dy * diff }
                }
                r.pts[0] = s.a
                r.pts[n - 1] = s.b
            }
            ropes[s.key] = r
        }
        ropes = ropes.filter { keep.contains($0.key) }
    }

    func drawGarland(_ ctx: CGContext) {
        let warm = prefs.garlandWarm
        let colors: [(CGFloat, CGFloat, CGFloat)] = warm
            ? [(1, 0.82, 0.5)]
            : [(1, 0.2, 0.25), (1, 0.8, 0.2), (0.25, 0.9, 0.4), (0.3, 0.6, 1), (1, 0.45, 0.85)]
        let lit: CGFloat = garlandAuto ? nightLevel : 1
        var k = 0
        for key in ropes.keys.sorted() {
            guard let r = ropes[key], r.pts.count >= 2 else { continue }
            // провод — сглаженная кривая через точки верёвки
            let wire = CGMutablePath()
            wire.move(to: r.pts[0])
            for i in 1..<r.pts.count {
                let mid = CGPoint(x: (r.pts[i - 1].x + r.pts[i].x) / 2, y: (r.pts[i - 1].y + r.pts[i].y) / 2)
                wire.addQuadCurve(to: mid, control: r.pts[i - 1])
            }
            wire.addLine(to: r.pts[r.pts.count - 1])
            ctx.addPath(wire)
            ctx.setStrokeColor(rgb(0.06, 0.16, 0.09))
            ctx.setLineWidth(1.6)
            ctx.strokePath()
            // лампочки каждые ~34 пт вдоль провода
            var acc: CGFloat = 17
            for i in 1..<r.pts.count {
                let a = r.pts[i - 1], b = r.pts[i]
                let seg = hypot(b.x - a.x, b.y - a.y)
                var tpos = acc
                while tpos < seg {
                    let u = tpos / max(seg, 0.001)
                    let p = CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
                    let c = colors[k % colors.count]
                    let wave = 0.5 + 0.5 * sin(t * 3 - CGFloat(k) * 0.7)
                    let tw = 0.5 + 0.5 * sin(t * 7.3 + CGFloat(k * 37 % 11))
                    let bri = (warm ? 0.6 + 0.4 * max(wave, tw) : 0.35 + 0.65 * max(wave, tw * 0.6)) * lit
                    let center = CGPoint(x: p.x, y: p.y - 9)
                    glowSpot(ctx, center, 18, c, 0.55 * bri)
                    ctx.setFillColor(rgb(0.25, 0.25, 0.25))
                    ctx.fill(CGRect(x: p.x - 2.5, y: p.y - 5, width: 5, height: 5))
                    let m = 0.45 + 0.55 * bri
                    ctx.setFillColor(rgb(c.0 * m, c.1 * m, c.2 * m))
                    ctx.fillEllipse(in: CGRect(x: center.x - 4, y: center.y - 6, width: 8, height: 11))
                    ctx.setFillColor(rgb(1, 1, 1, 0.6 * bri))
                    ctx.fillEllipse(in: CGRect(x: center.x - 2.2, y: center.y, width: 2.5, height: 3.5))
                    k += 1
                    tpos += 34
                }
                acc = tpos - seg
            }
        }
        if prefs.editGarland && prefs.garlandMode == 2 {
            for j in prefs.gJoints {
                let p = jointPos(j)
                let sel = selectedJoint == j.id
                let r: CGFloat = sel ? 9 : 7
                ctx.setFillColor(sel ? rgb(1, 0.6, 0.1, 0.95) : rgb(0.2, 0.5, 1, 0.85))
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                ctx.setStrokeColor(j.attached ? rgb(0.3, 0.95, 0.4) : rgb(1, 1, 1))
                ctx.setLineWidth(2.5)
                ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            }
        }
    }

    /// Новая/перенесённая точка: если она на окне или виджете — привязываем к нему.
    func makeJoint(id: Int, at p: CGPoint) -> GJoint {
        for wr in winRects where wr.rect.insetBy(dx: -14, dy: -14).contains(p) {
            var q = p
            if abs(p.y - wr.rect.maxY) < 16 { q.y = wr.rect.maxY - 2 }
            q.x = min(max(q.x, wr.rect.minX), wr.rect.maxX)
            jointWin[id] = wr.id
            return GJoint(id: id, x: Double(q.x), y: Double(q.y), owner: wr.owner,
                          ox: Double(q.x - wr.rect.minX), oy: Double(q.y - wr.rect.maxY), attached: true)
        }
        jointWin[id] = nil
        return GJoint(id: id, x: Double(p.x), y: Double(p.y), owner: "", ox: 0, oy: 0, attached: false)
    }

    func ropeKey(near p: CGPoint) -> String? {
        for (key, r) in ropes {
            for q in r.pts where hypot(q.x - p.x, q.y - p.y) < 10 { return key }
        }
        return nil
    }

    func garlandMouseDown(_ p: CGPoint, right: Bool, option: Bool) {
        guard prefs.garlandMode == 2 else { return }
        var js = prefs.gJoints
        if let i = js.firstIndex(where: { hypot(jointPos($0).x - p.x, jointPos($0).y - p.y) < 12 }) {
            let id = js[i].id
            if right {
                js.remove(at: i)
                prefs.gSegs.removeAll { $0.a == id || $0.b == id }
                prefs.gJoints = js
                if selectedJoint == id { selectedJoint = nil }
                dragJoint = nil
                return
            }
            if let sel = selectedJoint, sel != id {
                if let si = prefs.gSegs.firstIndex(where: { ($0.a == sel && $0.b == id) || ($0.a == id && $0.b == sel) }) {
                    prefs.gSegs.remove(at: si)
                } else {
                    prefs.gSegs.append(GSeg(a: sel, b: id))
                }
            }
            selectedJoint = id
            dragJoint = id
            return
        }
        if right {
            // правый клик по проводу — удалить этот отрезок
            if let key = ropeKey(near: p), key.hasPrefix("c") {
                let ids = key.dropFirst().split(separator: "-").compactMap { Int($0) }
                if ids.count == 2 { prefs.gSegs.removeAll { $0.a == ids[0] && $0.b == ids[1] } }
            }
            return
        }
        let nid = (js.map { $0.id }.max() ?? 0) + 1
        js.append(makeJoint(id: nid, at: p))
        prefs.gJoints = js
        if let sel = selectedJoint, !option, js.contains(where: { $0.id == sel }) {
            prefs.gSegs.append(GSeg(a: sel, b: nid))
        }
        selectedJoint = nid
        dragJoint = nid
    }

    func garlandDrag(_ p: CGPoint) {
        guard let id = dragJoint, let i = prefs.gJoints.firstIndex(where: { $0.id == id }) else { return }
        var js = prefs.gJoints
        js[i] = makeJoint(id: id, at: p)
        prefs.gJoints = js
    }

    // MARK: - Ёлка

    func rebuildTree() {
        guard prefs.treeOn else {
            treeImage = nil
            treeLights = []
            return
        }
        let H = treeHeightPt
        let W = H * 0.8
        var rng = SeededRandom(seed: UInt64(prefs.treeSeed) &+ UInt64(prefs.treeSize) &* 7919)
        var lights: [CGPoint] = []
        if season != .winter {
            let s = season
            treeImage = makeImage(width: W, height: H + 30) { ctx in
                ctx.translateBy(x: W / 2, y: 4)
                switch s {
                case .summer: self.drawAppleBody(ctx, H: H, rng: &rng)
                case .spring: self.drawBlossomBody(ctx, H: H, rng: &rng)
                default: self.drawMapleBody(ctx, H: H, rng: &rng)
                }
            }
            treeLights = []
            return
        }
        treeImage = makeImage(width: W, height: H + 30) { ctx in
            ctx.translateBy(x: W / 2, y: 4)
            self.drawTreeBody(ctx, H: H, rng: &rng, lights: &lights)
        }
        treeLights = lights
    }

    func drawTreeBody(_ ctx: CGContext, H: CGFloat, rng: inout SeededRandom, lights: inout [CGPoint]) {
        func halfWidth(_ y: CGFloat) -> CGFloat {
            let f = (y - H * 0.08) / (H * 0.92)
            return max(0, 1 - f) * H * 0.34
        }
        // ствол
        ctx.setFillColor(rgb(0.3, 0.18, 0.1))
        ctx.fill(CGRect(x: -H * 0.035, y: 0, width: H * 0.07, height: H * 0.11))
        let grad = linGrad(rgb(0.14, 0.44, 0.22), rgb(0.03, 0.18, 0.09))
        let tiers = 7
        for i in 0..<tiers {
            let yb = H * 0.08 + CGFloat(i) / CGFloat(tiers) * H * 0.76
            let ytop = min(H, yb + H * 0.27)
            let hw = halfWidth(yb) + H * 0.025
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -hw, y: yb))
            let teeth = 8
            for k in 0...teeth {
                let u = CGFloat(k) / CGFloat(teeth)
                let jitter = CGFloat.random(in: -H * 0.006...H * 0.006, using: &rng)
                p.addLine(to: CGPoint(x: -hw + 2 * hw * u, y: yb + (k % 2 == 0 ? 0 : H * 0.028) + jitter))
            }
            p.addLine(to: CGPoint(x: 0, y: ytop))
            p.closeSubpath()
            ctx.saveGState()
            ctx.addPath(p)
            ctx.clip()
            ctx.drawLinearGradient(grad, start: CGPoint(x: -hw, y: ytop), end: CGPoint(x: hw, y: yb), options: [])
            // хвоинки
            ctx.setStrokeColor(rgb(0.02, 0.12, 0.06, 0.55))
            ctx.setLineWidth(0.8)
            for _ in 0..<45 {
                let x = CGFloat.random(in: -hw...hw, using: &rng)
                let y = CGFloat.random(in: yb...(yb + (ytop - yb) * 0.8), using: &rng)
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addLine(to: CGPoint(x: x + (x > 0 ? 4 : -4), y: y - 3))
            }
            ctx.strokePath()
            ctx.restoreGState()
            // снег на лапах
            ctx.setFillColor(rgb(0.96, 0.97, 1, 0.95))
            for k in stride(from: 0, through: 8, by: 2) {
                let x = -hw + 2 * hw * CGFloat(k) / 8
                let sw = H * 0.035
                ctx.fillEllipse(in: CGRect(x: x - sw * 0.7, y: yb + H * 0.012, width: sw * 1.4, height: sw * 0.42))
            }
            ctx.fillEllipse(in: CGRect(x: -hw * 0.4, y: yb + (ytop - yb) * 0.45, width: hw * 0.5, height: H * 0.017))
        }
        func spot() -> CGPoint {
            let y = CGFloat.random(in: H * 0.13...H * 0.8, using: &rng)
            let hw = halfWidth(y) * 0.78
            return CGPoint(x: CGFloat.random(in: -hw...hw, using: &rng), y: y)
        }
        if prefs.gingerbread {
            for _ in 0..<Int(H / 28) {
                let p = spot()
                let s = H * 0.012
                ctx.setFillColor(rgb(0.62, 0.36, 0.16))
                ctx.fillEllipse(in: CGRect(x: p.x - 2 * s, y: p.y + 2 * s, width: 4 * s, height: 4 * s))
                ctx.addPath(CGPath(roundedRect: CGRect(x: p.x - 2.2 * s, y: p.y - 3 * s, width: 4.4 * s, height: 5.5 * s),
                                   cornerWidth: 1.5 * s, cornerHeight: 1.5 * s, transform: nil))
                ctx.fillPath()
                ctx.setFillColor(rgb(1, 1, 1))
                ctx.fillEllipse(in: CGRect(x: p.x - 0.5 * s, y: p.y, width: s, height: s))
            }
        }
        if prefs.bells {
            for _ in 0..<Int(H / 24) {
                let p = spot()
                let s = H * 0.022
                let bell = CGMutablePath()
                bell.move(to: CGPoint(x: p.x - s * 0.4, y: p.y + s * 0.9))
                bell.addQuadCurve(to: CGPoint(x: p.x - s, y: p.y - s * 0.6), control: CGPoint(x: p.x - s * 0.6, y: p.y))
                bell.addLine(to: CGPoint(x: p.x + s, y: p.y - s * 0.6))
                bell.addQuadCurve(to: CGPoint(x: p.x + s * 0.4, y: p.y + s * 0.9), control: CGPoint(x: p.x + s * 0.6, y: p.y))
                bell.closeSubpath()
                ctx.saveGState()
                ctx.addPath(bell)
                ctx.clip()
                ctx.drawLinearGradient(linGrad(rgb(1, 0.88, 0.45), rgb(0.7, 0.5, 0.1)),
                                       start: CGPoint(x: p.x - s, y: p.y), end: CGPoint(x: p.x + s, y: p.y), options: [])
                ctx.restoreGState()
                ctx.setFillColor(rgb(0.5, 0.35, 0.08))
                ctx.fillEllipse(in: CGRect(x: p.x - s * 0.25, y: p.y - s * 0.9, width: s * 0.5, height: s * 0.5))
            }
        }
        if prefs.baubles {
            let pal: [(CGFloat, CGFloat, CGFloat)] = [(0.85, 0.1, 0.12), (0.95, 0.75, 0.2), (0.2, 0.4, 0.9), (0.85, 0.85, 0.9), (0.7, 0.15, 0.6)]
            for _ in 0..<Int(H / 9) {
                let p = spot()
                let r = H * 0.024
                let c = pal[Int.random(in: 0..<pal.count, using: &rng)]
                ctx.saveGState()
                ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                ctx.clip()
                let g = linGrad(rgb(min(1, c.0 + 0.45), min(1, c.1 + 0.45), min(1, c.2 + 0.45)), rgb(c.0 * 0.5, c.1 * 0.5, c.2 * 0.5))
                ctx.drawRadialGradient(g, startCenter: CGPoint(x: p.x - r * 0.35, y: p.y + r * 0.35), startRadius: 0,
                                       endCenter: p, endRadius: r * 1.1, options: [.drawsAfterEndLocation])
                ctx.restoreGState()
                ctx.setFillColor(rgb(0.8, 0.7, 0.4))
                ctx.fill(CGRect(x: p.x - r * 0.25, y: p.y + r * 0.85, width: r * 0.5, height: r * 0.35))
            }
        }
        if prefs.lights {
            let n = Int(H / 5)
            ctx.setStrokeColor(rgb(0.05, 0.12, 0.06, 0.8))
            ctx.setLineWidth(0.7)
            for i in 0..<n {
                let f = CGFloat(i) / CGFloat(n)
                let y = H * 0.1 + f * H * 0.76
                let x = halfWidth(y) * 0.85 * sin(f * .pi * 9)
                let pt = CGPoint(x: x, y: y)
                if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
                lights.append(pt)
            }
            ctx.strokePath()
        }
        // верхушка
        let top = CGPoint(x: 0, y: H * 0.97)
        switch prefs.topper {
        case "snowflake":
            ctx.setStrokeColor(rgb(0.92, 0.96, 1))
            ctx.setLineWidth(2)
            ctx.setLineCap(.round)
            let r = H * 0.055
            for k in 0..<6 {
                let a = CGFloat(k) * .pi / 3
                let e = CGPoint(x: top.x + cos(a) * r, y: top.y + sin(a) * r)
                ctx.move(to: top)
                ctx.addLine(to: e)
                let m = CGPoint(x: top.x + cos(a) * r * 0.6, y: top.y + sin(a) * r * 0.6)
                for side in [-1.0, 1.0] {
                    let b = a + CGFloat(side) * 0.6
                    ctx.move(to: m)
                    ctx.addLine(to: CGPoint(x: m.x + cos(b) * r * 0.3, y: m.y + sin(b) * r * 0.3))
                }
            }
            ctx.strokePath()
        case "bow":
            let s = H * 0.03
            ctx.setFillColor(rgb(0.8, 0.08, 0.12))
            ctx.fillEllipse(in: CGRect(x: top.x - 2.6 * s, y: top.y - 0.6 * s, width: 2.4 * s, height: 1.6 * s))
            ctx.fillEllipse(in: CGRect(x: top.x + 0.2 * s, y: top.y - 0.6 * s, width: 2.4 * s, height: 1.6 * s))
            ctx.fill(CGRect(x: top.x - 1.2 * s, y: top.y - 2.6 * s, width: 0.7 * s, height: 2.2 * s))
            ctx.fill(CGRect(x: top.x + 0.5 * s, y: top.y - 2.6 * s, width: 0.7 * s, height: 2.2 * s))
            ctx.setFillColor(rgb(0.6, 0.04, 0.08))
            ctx.fillEllipse(in: CGRect(x: top.x - 0.6 * s, y: top.y - 0.3 * s, width: 1.2 * s, height: 1.1 * s))
        default:
            let star = CGMutablePath()
            let ro = H * 0.06, ri = ro * 0.45
            for k in 0..<10 {
                let a = CGFloat.pi / 2 + CGFloat(k) * .pi / 5
                let r = k % 2 == 0 ? ro : ri
                let pt = CGPoint(x: top.x + cos(a) * r, y: top.y + sin(a) * r)
                if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            ctx.saveGState()
            ctx.addPath(star)
            ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(1, 0.95, 0.6), rgb(0.85, 0.6, 0.1)),
                                   start: CGPoint(x: top.x - ro, y: top.y + ro), end: CGPoint(x: top.x + ro, y: top.y - ro), options: [])
            ctx.restoreGState()
        }
    }

    func knockTree(dir: CGFloat) {
        guard treeStanding else { return }
        treeFall = 0.001
        treeFallDir = dir
        burst(treeX, ground + treeHeightPt * 0.5, 20, count: 30)
    }

    func treeStep() {
        if treeFall > 0 && treeFall < 1 {
            treeFall = min(1, treeFall + 0.02 + treeFall * 0.05)
            if treeFall >= 1 {
                let x = treeX + treeFallDir * treeHeightPt * 0.5
                burst(x, ground + 20, 30, count: 50)
                addHeap(at: x, volume: 260, span: 70)
            }
        } else if treeFall >= 1 {
            treeGoneTimer += 1.0 / 60.0
            if treeGoneTimer > 45 {
                treeFall = 0
                treeGoneTimer = 0
                treeAppear = 0
            }
        }
        if treeAppear < 1 { treeAppear = min(1, treeAppear + 1.0 / 90.0) }
    }

    func drawTree(_ ctx: CGContext) {
        guard prefs.treeOn, let img = treeImage, treeFall < 1 else { return }
        let H = treeHeightPt
        let W = H * 0.8
        ctx.saveGState()
        ctx.translateBy(x: treeX, y: ground - 4)
        if treeFall > 0 { ctx.rotate(by: -treeFallDir * treeFall * treeFall * .pi / 2) }
        ctx.setAlpha(treeAppear)
        ctx.draw(img, in: CGRect(x: -W / 2, y: -4, width: W, height: H + 30))
        // огоньки и сияние верхушки — живые
        let lit = 0.45 + 0.55 * nightLevel
        if season != .winter { ctx.restoreGState(); return }
        if prefs.lights {
            let pal: [(CGFloat, CGFloat, CGFloat)] = prefs.garlandWarm
                ? [(1, 0.82, 0.5)]
                : [(1, 0.85, 0.5), (1, 0.3, 0.3), (0.4, 0.7, 1), (0.5, 1, 0.5)]
            for (i, p) in treeLights.enumerated() {
                let tw = 0.55 + 0.45 * sin(t * 4 + CGFloat(i) * 1.7)
                let c = pal[i % pal.count]
                glowSpot(ctx, p, 7, c, 0.6 * tw * lit)
                ctx.setFillColor(rgb(c.0, c.1, c.2, 0.6 + 0.4 * tw))
                ctx.fillEllipse(in: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3))
            }
        }
        if prefs.topper == "star" {
            glowSpot(ctx, CGPoint(x: 0, y: H * 0.97), H * 0.16, (1, 0.85, 0.4), 0.35 * lit + 0.1 * sin(t * 2))
        }
        ctx.restoreGState()
    }

    // MARK: - Домики у Dock

    static func decorSets(_ n: Int) -> ([DecorItem], [DecorItem]) {
        switch n {
        case 2:
            return ([.lamp, .stall(0.8, 0.12, 0.15), .stall(0.1, 0.45, 0.25), .fir(46)],
                    [.fir(52), .stall(0.15, 0.3, 0.7), .lamp])
        case 3:
            return ([.brownstone(0.55, 0.25, 0.18), .lamp, .brownstone(0.42, 0.3, 0.25)],
                    [.lamp, .brownstone(0.6, 0.5, 0.38), .fir(50)])
        case 4:
            return ([.fir(58), .gifts, .fir(40)], [.gifts, .fir(62), .gifts])
        default:
            return ([.fir(56), .house(0.55, 0.36, 0.22, true), .lamp, .house(0.62, 0.2, 0.18, false), .fir(44)],
                    [.fir(48), .house(0.45, 0.55, 0.62, false), .fir(60)])
        }
    }

    func decorWidth(_ it: DecorItem) -> CGFloat {
        switch it {
        case .house: return 50
        case .fir(let h): return h * 0.6
        case .lamp: return 12
        case .stall: return 48
        case .brownstone: return 46
        case .gifts: return 36
        case .pumpkins: return 38
        case .flowers: return 36
        }
    }

    func rebuildDecor() {
        decorLeft = nil
        decorRight = nil
        decorGlowsL = []
        decorGlowsR = []
        guard prefs.decorSet > 0 else { return }
        let sc: CGFloat = [0.8, 1.1, 1.45][max(0, min(2, prefs.decorSize))]
        var sets = SnowView.decorSets(prefs.decorSet)
        if isAutumn {
            // осенью вместо подарков — тыквы, и тыквы у первого домика
            func autumnize(_ items: [DecorItem]) -> [DecorItem] {
                var out: [DecorItem] = []
                var added = false
                for it in items {
                    if case .gifts = it { if prefs.pumpkins { out.append(.pumpkins) }; continue }
                    out.append(it)
                    if !added && prefs.pumpkins {
                        switch it {
                        case .house, .brownstone, .stall: out.append(.pumpkins); added = true
                        default: break
                        }
                    }
                }
                return out
            }
            sets = (autumnize(sets.0), autumnize(sets.1))
        } else if isSummer || isSpring {
            // летом и весной вместо подарков — клумбы
            func summerize(_ items: [DecorItem]) -> [DecorItem] {
                var out: [DecorItem] = []
                var added = false
                for it in items {
                    if case .gifts = it { if prefs.flowerBeds { out.append(.flowers) }; continue }
                    out.append(it)
                    if !added && prefs.flowerBeds {
                        switch it {
                        case .house, .brownstone, .stall: out.append(.flowers); added = true
                        default: break
                        }
                    }
                }
                return out
            }
            sets = (summerize(sets.0), summerize(sets.1))
        }
        let l = buildCluster(sets.0, sc)
        decorLeft = l.0
        decorGlowsL = l.1
        decorSizeL = l.2
        let r = buildCluster(sets.1, sc)
        decorRight = r.0
        decorGlowsR = r.1
        decorSizeR = r.2
    }

    func buildCluster(_ items: [DecorItem], _ sc: CGFloat) -> (CGImage?, [CGRect], CGSize) {
        let gap: CGFloat = 6
        var wTotal: CGFloat = 10
        for it in items { wTotal += decorWidth(it) + gap }
        wTotal *= sc
        let hTotal: CGFloat = 96 * sc
        var glows: [CGRect] = []
        let img = makeImage(width: wTotal, height: hTotal) { ctx in
            ctx.scaleBy(x: sc, y: sc)
            var x: CGFloat = 5
            for it in items {
                ctx.saveGState()
                ctx.translateBy(x: x, y: 0)
                let g = self.drawDecorItem(ctx, it)
                ctx.restoreGState()
                for r in g {
                    glows.append(CGRect(x: (r.minX + x) * sc, y: r.minY * sc, width: r.width * sc, height: r.height * sc))
                }
                x += self.decorWidth(it) + gap
            }
        }
        return (img, glows, CGSize(width: wTotal, height: hTotal))
    }

    func drawDecorItem(_ ctx: CGContext, _ it: DecorItem) -> [CGRect] {
        let snow = season != .winter ? rgb(0, 0, 0, 0) : rgb(0.96, 0.97, 1)
        switch it {
        case .flowers:
            return drawFlowerBed(ctx)
        case .pumpkins:
            return drawPumpkins(ctx)
        case let .house(r, g, b, wood):
            ctx.saveGState()
            ctx.addRect(CGRect(x: 3, y: 0, width: 44, height: 30))
            ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(r * 1.15, g * 1.15, b * 1.15), rgb(r * 0.7, g * 0.7, b * 0.7)),
                                   start: CGPoint(x: 0, y: 30), end: CGPoint(x: 0, y: 0), options: [])
            if wood {
                ctx.setStrokeColor(rgb(0, 0, 0, 0.25))
                ctx.setLineWidth(0.8)
                var y: CGFloat = 5
                while y < 30 { ctx.move(to: CGPoint(x: 3, y: y)); ctx.addLine(to: CGPoint(x: 47, y: y)); y += 5 }
                ctx.strokePath()
            }
            ctx.restoreGState()
            ctx.setFillColor(rgb(0.5, 0.25, 0.2))
            ctx.fill(CGRect(x: 33, y: 36, width: 6, height: 14))
            ctx.setFillColor(rgb(0.25, 0.15, 0.12))
            ctx.move(to: CGPoint(x: 0, y: 29)); ctx.addLine(to: CGPoint(x: 50, y: 29)); ctx.addLine(to: CGPoint(x: 25, y: 50))
            ctx.closePath(); ctx.fillPath()
            ctx.setFillColor(snow)
            ctx.move(to: CGPoint(x: -2, y: 28)); ctx.addLine(to: CGPoint(x: 25, y: 52)); ctx.addLine(to: CGPoint(x: 52, y: 28))
            ctx.addLine(to: CGPoint(x: 50, y: 32)); ctx.addLine(to: CGPoint(x: 25, y: 48)); ctx.addLine(to: CGPoint(x: 0, y: 32))
            ctx.closePath(); ctx.fillPath()
            ctx.fill(CGRect(x: 32, y: 49, width: 8, height: 3))
            ctx.setFillColor(rgb(0.3, 0.18, 0.1))
            ctx.fill(CGRect(x: 21, y: 0, width: 8, height: 15))
            let wins = [CGRect(x: 8, y: 12, width: 9, height: 9), CGRect(x: 33, y: 12, width: 9, height: 9)]
            for w in wins {
                ctx.setFillColor(rgb(0.92, 0.9, 0.85))
                ctx.fill(w.insetBy(dx: -1.2, dy: -1.2))
                ctx.setFillColor(rgb(0.14, 0.16, 0.24))
                ctx.fill(w)
                ctx.setFillColor(snow)
                ctx.fill(CGRect(x: w.minX - 1.5, y: w.minY - 2.5, width: w.width + 3, height: 1.8))
            }
            ctx.fillEllipse(in: CGRect(x: 0, y: -3, width: 50, height: 6))
            return wins
        case .fir(let h):
            let cx = h * 0.3
            ctx.setFillColor(rgb(0.3, 0.18, 0.1))
            ctx.fill(CGRect(x: cx - 1.5, y: 0, width: 3, height: h * 0.12))
            for i in 0..<4 {
                let yb = h * 0.08 + CGFloat(i) * h * 0.21
                let hw = h * 0.29 * (1 - CGFloat(i) * 0.2)
                ctx.setFillColor(rgb(0.05 + 0.02 * CGFloat(i), 0.22 + 0.04 * CGFloat(i), 0.12))
                ctx.move(to: CGPoint(x: cx - hw, y: yb)); ctx.addLine(to: CGPoint(x: cx + hw, y: yb))
                ctx.addLine(to: CGPoint(x: cx, y: yb + h * 0.34)); ctx.closePath(); ctx.fillPath()
                ctx.setFillColor(snow)
                ctx.fillEllipse(in: CGRect(x: cx - hw * 0.9, y: yb, width: hw * 0.8, height: h * 0.025))
                ctx.fillEllipse(in: CGRect(x: cx + hw * 0.15, y: yb, width: hw * 0.7, height: h * 0.022))
            }
            ctx.setFillColor(snow)
            ctx.move(to: CGPoint(x: cx, y: h * 0.97)); ctx.addLine(to: CGPoint(x: cx - 3, y: h * 0.88))
            ctx.addLine(to: CGPoint(x: cx + 2, y: h * 0.89)); ctx.closePath(); ctx.fillPath()
            return []
        case .lamp:
            ctx.setFillColor(rgb(0.12, 0.12, 0.14))
            ctx.fill(CGRect(x: 5, y: 0, width: 2, height: 34))
            ctx.fill(CGRect(x: 2, y: 33, width: 8, height: 9))
            ctx.setFillColor(rgb(0.55, 0.5, 0.35))
            let glass = CGRect(x: 3.5, y: 34.5, width: 5, height: 6)
            ctx.fill(glass)
            ctx.setFillColor(rgb(0.12, 0.12, 0.14))
            ctx.move(to: CGPoint(x: 1, y: 42)); ctx.addLine(to: CGPoint(x: 11, y: 42)); ctx.addLine(to: CGPoint(x: 6, y: 46))
            ctx.closePath(); ctx.fillPath()
            ctx.setFillColor(snow)
            ctx.fillEllipse(in: CGRect(x: 1.5, y: 43, width: 9, height: 3))
            return [glass]
        case let .stall(r, g, b):
            ctx.saveGState()
            ctx.addRect(CGRect(x: 0, y: 0, width: 48, height: 16))
            ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(0.58, 0.38, 0.22), rgb(0.38, 0.24, 0.13)),
                                   start: CGPoint(x: 0, y: 16), end: CGPoint(x: 0, y: 0), options: [])
            ctx.restoreGState()
            ctx.setFillColor(rgb(0.35, 0.22, 0.12))
            ctx.fill(CGRect(x: 2, y: 16, width: 3, height: 20))
            ctx.fill(CGRect(x: 43, y: 16, width: 3, height: 20))
            let goods: [(CGFloat, CGFloat, CGFloat)] = [(0.9, 0.2, 0.2), (0.95, 0.75, 0.2), (0.3, 0.6, 0.3), (0.9, 0.5, 0.1)]
            for k in 0..<7 {
                let c = goods[k % goods.count]
                ctx.setFillColor(rgb(c.0, c.1, c.2))
                ctx.fillEllipse(in: CGRect(x: 6 + CGFloat(k) * 5.5, y: 16, width: 4.5, height: 4.5))
            }
            let awning = CGMutablePath()
            awning.move(to: CGPoint(x: -3, y: 34)); awning.addLine(to: CGPoint(x: 51, y: 34))
            awning.addLine(to: CGPoint(x: 47, y: 44)); awning.addLine(to: CGPoint(x: 1, y: 44)); awning.closeSubpath()
            ctx.saveGState()
            ctx.addPath(awning)
            ctx.clip()
            var x: CGFloat = -3
            var odd = false
            while x < 52 {
                ctx.setFillColor(odd ? rgb(0.97, 0.96, 0.94) : rgb(r, g, b))
                ctx.fill(CGRect(x: x, y: 34, width: 6, height: 10))
                x += 6
                odd.toggle()
            }
            ctx.restoreGState()
            ctx.setFillColor(rgb(r, g, b))
            var sx: CGFloat = -3
            while sx < 51 { ctx.fillEllipse(in: CGRect(x: sx, y: 31.5, width: 6, height: 5)); sx += 6 }
            ctx.setFillColor(snow)
            ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 42.5, width: 48, height: 4), cornerWidth: 2, cornerHeight: 2, transform: nil))
            ctx.fillPath()
            var lightsR: [CGRect] = []
            var lx: CGFloat = 6
            while lx < 44 { lightsR.append(CGRect(x: lx, y: 29, width: 2, height: 2)); lx += 6 }
            ctx.setFillColor(rgb(0.6, 0.55, 0.4))
            for l in lightsR { ctx.fillEllipse(in: l) }
            return lightsR
        case let .brownstone(r, g, b):
            ctx.saveGState()
            ctx.addRect(CGRect(x: 0, y: 0, width: 46, height: 72))
            ctx.clip()
            ctx.drawLinearGradient(linGrad(rgb(r * 1.15, g * 1.15, b * 1.15), rgb(r * 0.75, g * 0.75, b * 0.75)),
                                   start: CGPoint(x: 0, y: 0), end: CGPoint(x: 46, y: 72), options: [])
            ctx.setStrokeColor(rgb(0, 0, 0, 0.12))
            ctx.setLineWidth(0.6)
            var y: CGFloat = 4
            while y < 72 { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: 46, y: y)); y += 4 }
            ctx.strokePath()
            ctx.restoreGState()
            ctx.setFillColor(rgb(0.82, 0.78, 0.7))
            ctx.fill(CGRect(x: -2, y: 70, width: 50, height: 4))
            ctx.setFillColor(snow)
            ctx.addPath(CGPath(roundedRect: CGRect(x: -2, y: 73, width: 50, height: 3.5), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
            ctx.fillPath()
            var wins: [CGRect] = []
            for row in [24.0, 40.0, 56.0] {
                for col_ in [6.0, 19.0, 32.0] {
                    let w = CGRect(x: col_, y: row, width: 8, height: 11)
                    ctx.setFillColor(rgb(0.85, 0.82, 0.75))
                    ctx.fill(w.insetBy(dx: -1, dy: -1))
                    ctx.setFillColor(rgb(0.14, 0.16, 0.24))
                    ctx.fill(w)
                    ctx.setFillColor(snow)
                    ctx.fill(CGRect(x: w.minX - 1.5, y: w.minY - 2.2, width: w.width + 3, height: 1.6))
                    wins.append(w)
                }
            }
            ctx.setFillColor(rgb(0.3, 0.18, 0.12))
            ctx.fill(CGRect(x: 19, y: 3, width: 9, height: 15))
            ctx.setFillColor(rgb(0.7, 0.68, 0.64))
            ctx.fill(CGRect(x: 15, y: 0, width: 17, height: 3))
            ctx.setFillColor(snow)
            ctx.fill(CGRect(x: 15, y: 2.4, width: 17, height: 1.4))
            ctx.setStrokeColor(rgb(0.1, 0.4, 0.15))
            ctx.setLineWidth(2.5)
            ctx.strokeEllipse(in: CGRect(x: 20, y: 9.5, width: 7, height: 7))
            ctx.setFillColor(rgb(0.85, 0.1, 0.12))
            ctx.fillEllipse(in: CGRect(x: 22.2, y: 8, width: 2.6, height: 2.6))
            return wins
        case .gifts:
            let boxes: [(CGRect, (CGFloat, CGFloat, CGFloat), (CGFloat, CGFloat, CGFloat))] = [
                (CGRect(x: 2, y: 0, width: 14, height: 12), (0.8, 0.12, 0.15), (0.95, 0.85, 0.4)),
                (CGRect(x: 18, y: 0, width: 11, height: 16), (0.12, 0.45, 0.25), (0.9, 0.15, 0.15)),
                (CGRect(x: 8, y: 12, width: 10, height: 8), (0.95, 0.75, 0.2), (0.2, 0.35, 0.8)),
                (CGRect(x: 30, y: 0, width: 6, height: 7), (0.2, 0.35, 0.8), (1, 1, 1)),
            ]
            for (rect, c, rib) in boxes {
                ctx.saveGState()
                ctx.addRect(rect)
                ctx.clip()
                ctx.drawLinearGradient(linGrad(rgb(c.0 * 1.2, c.1 * 1.2, c.2 * 1.2), rgb(c.0 * 0.7, c.1 * 0.7, c.2 * 0.7)),
                                       start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
                ctx.restoreGState()
                ctx.setFillColor(rgb(rib.0, rib.1, rib.2))
                ctx.fill(CGRect(x: rect.midX - 1, y: rect.minY, width: 2, height: rect.height))
                ctx.fill(CGRect(x: rect.minX, y: rect.midY - 1, width: rect.width, height: 2))
                ctx.fillEllipse(in: CGRect(x: rect.midX - 3.5, y: rect.maxY - 1, width: 3.5, height: 2.5))
                ctx.fillEllipse(in: CGRect(x: rect.midX, y: rect.maxY - 1, width: 3.5, height: 2.5))
                ctx.setFillColor(snow)
                ctx.fill(CGRect(x: rect.minX, y: rect.maxY - 0.8, width: rect.width * 0.45, height: 1.2))
            }
            return []
        }
    }

    func drawDecor(_ ctx: CGContext) {
        guard prefs.decorSet > 0 else { return }
        let base = ground - 3
        if let img = decorLeft {
            let ox: CGFloat = 12
            ctx.draw(img, in: CGRect(x: ox, y: base, width: decorSizeL.width, height: decorSizeL.height))
            drawDecorGlows(ctx, decorGlowsL, ox, base)
        }
        if let img = decorRight {
            let ox = bounds.width - 12 - decorSizeR.width
            ctx.draw(img, in: CGRect(x: ox, y: base, width: decorSizeR.width, height: decorSizeR.height))
            drawDecorGlows(ctx, decorGlowsR, ox, base)
        }
    }

    func drawDecorGlows(_ ctx: CGContext, _ rects: [CGRect], _ ox: CGFloat, _ oy: CGFloat) {
        let lv = nightLevel
        guard lv > 0.03 else { return }
        for (i, r) in rects.enumerated() {
            let rr = r.offsetBy(dx: ox, dy: oy)
            let flick = 0.92 + 0.08 * sin(t * 3 + CGFloat(i))
            glowSpot(ctx, CGPoint(x: rr.midX, y: rr.midY), max(rr.width, rr.height) * 1.8, (1, 0.75, 0.4), 0.35 * lv * flick)
            ctx.setFillColor(rgb(1, 0.82, 0.48, 0.92 * lv))
            ctx.fill(rr)
        }
    }

    // MARK: - Снегоуборщик и дворник сами по себе

    var averageSnow: CGFloat {
        heights.isEmpty ? 0 : heights.reduce(0, +) / CGFloat(heights.count)
    }

    func autoServices() {
        if isSpring && prefs.autoPlow && tractorX == nil && averageSnow < 6 && CGFloat.random(in: 0...1) < 1 / (60 * 300) {
            callTractor()
        }
        if isSummer {
            // летом машина и садовник появляются просто так, время от времени
            let means: [CGFloat] = [400, 220, 110]
            if prefs.autoPlow && tractorX == nil && CGFloat.random(in: 0...1) < 1 / (60 * means[max(0, min(2, prefs.plowRate))]) {
                callTractor()
            }
            if prefs.janitor && !walkers.contains(where: { $0.kind == .janitor }) && CGFloat.random(in: 0...1) < 1 / (60 * 150) {
                spawn(.janitor)
            }
            return
        }
        let avg = averageSnow
        if prefs.autoPlow && tractorX == nil && avg > 6 {
            let means: [CGFloat] = [300, 150, 70]
            var chance = 1 / (60 * means[max(0, min(2, prefs.plowRate))])
            if avg > 15 { chance *= 3 }
            if CGFloat.random(in: 0...1) < chance { callTractor() }
        }
        if prefs.janitor && tractorX == nil && avg > 8 && !walkers.contains(where: { $0.kind == .janitor })
            && CGFloat.random(in: 0...1) < 1 / (60 * 90) {
            spawn(.janitor)
        }
    }

    // MARK: - Случайные события

    func eventStep() {
        guard prefs.eventsOn, walkers.count < 6 else { return }
        let means: [CGFloat] = [150, 70, 30]
        let mean = means[max(0, min(2, prefs.eventRate))]
        if CGFloat.random(in: 0...1) < 1 / (60 * mean) { spawnRandomEvent() }
    }

    func spawnRandomEvent() {
        var kinds: [WalkerKind] = []
        if prefs.people { kinds.append(.person) }
        if prefs.kids && !walkers.contains(where: { $0.kind == .kid }) { kinds.append(.kid) }
        if prefs.dogs { kinds.append(.dog) }
        if prefs.cats { kinds.append(.cat) }
        if prefs.yeti && season == .winter && !walkers.contains(where: { $0.kind == .yeti }) { kinds.append(.yeti) }
        guard let k = kinds.randomElement() else { return }
        spawn(k)
    }

    func newWalker(_ kind: WalkerKind, _ x: CGFloat, _ dir: CGFloat, _ speed: CGFloat) -> Walker {
        var wk = Walker(id: nextWalkerID, kind: kind, x: x, dir: dir, speed: speed)
        nextWalkerID += 1
        wk.c1 = SnowView.jackets.randomElement() ?? (0.2, 0.3, 0.6)
        wk.c2 = SnowView.jackets.randomElement() ?? (0.8, 0.1, 0.1)
        wk.phase = CGFloat.random(in: 0...6)
        return wk
    }

    func spawn(_ kind: WalkerKind) {
        let w = bounds.width
        let fromLeft = Bool.random()
        let x0: CGFloat = fromLeft ? -40 : w + 40
        let d: CGFloat = fromLeft ? 1 : -1
        switch kind {
        case .person:
            var a = newWalker(.person, x0, d, CGFloat.random(in: 0.8...1.1))
            a.scale = CGFloat.random(in: 0.95...1.08)
            walkers.append(a)
            if Bool.random() {
                var b = newWalker(.person, x0 - d * 26, d, a.speed)
                b.scale = a.scale * 0.94
                walkers.append(b)
            }
        case .kid where isSpring:
            // весной — ребёнок с воздушным змеем просто идёт через экран
            var a = newWalker(.kid, x0, d, 1.2)
            a.stopX = d > 0 ? w + 200 : -200
            a.scale = 0.7
            walkers.append(a)
        case .kid:
            var a = newWalker(.kid, -40, 1, 1.6)
            a.stopX = w * CGFloat.random(in: 0.28...0.38)
            a.throwsLeft = 4
            a.scale = 0.7
            var b = newWalker(.kid, w + 40, -1, 1.6)
            b.stopX = w * CGFloat.random(in: 0.6...0.72)
            b.throwsLeft = 4
            b.scale = 0.68
            b.timer = 40
            walkers.append(a)
            walkers.append(b)
        case .dog:
            var a = newWalker(.dog, x0, d, 2.6)
            a.stopX = w * CGFloat.random(in: 0.3...0.7)
            a.c1 = SnowView.dogColors.randomElement() ?? (0.55, 0.35, 0.18)
            walkers.append(a)
        case .cat:
            var a = newWalker(.cat, x0, d, 0.75)
            a.stopX = w * CGFloat.random(in: 0.25...0.75)
            a.c1 = SnowView.catColors.randomElement() ?? (0.9, 0.55, 0.2)
            walkers.append(a)
        case .janitor:
            var a = newWalker(.janitor, x0, d, 0.75)
            a.c1 = (1, 0.45, 0.05)
            a.c2 = (0.3, 0.27, 0.25)
            walkers.append(a)
        case .yeti:
            var a = newWalker(.yeti, x0, d, 1.0)
            a.c1 = (0.93, 0.96, 1)
            walkers.append(a)
        }
    }

    func walkerHeight(_ a: Walker) -> CGFloat {
        switch a.kind {
        case .person, .kid: return 60 * a.scale
        case .dog: return 26
        case .cat: return 20
        case .yeti: return 80
        case .janitor: return 60
        }
    }

    func walkerHit(_ sb: Snowball) -> Int? {
        for (i, a) in walkers.enumerated() where a.id != sb.owner {
            let base = surface(a.x) - 3
            if abs(sb.x - a.x) < 10 * a.scale + sb.r && sb.y > base && sb.y < base + walkerHeight(a) { return i }
        }
        return nil
    }

    func throwSnowball(from a: Walker, to o: Walker) {
        if isAutumn { tossLeaves(from: a, to: o); return }
        if isSummer { kidBubbles(from: a); return }
        if isSpring { return }
        let sx = a.x + a.dir * 8 * a.scale
        let sy = surface(a.x) + 40 * a.scale
        let tx = o.x
        let ty = surface(o.x) + 28 * o.scale
        let T = CGFloat.random(in: 45...60)
        var sb = Snowball(x: sx, y: sy, vx: (tx - sx) / T, vy: (ty - sy + 0.15 * T * T) / T, r: 4)
        sb.owner = a.id
        snowballs.append(sb)
    }

    func walkerStep() {
        let w = bounds.width
        var i = 0
        while i < walkers.count {
            var a = walkers[i]
            a.hit = max(0, a.hit - 0.03)
            var moving = true
            switch a.kind {
            case .person:
                moving = true
            case .kid:
                if a.state == 0 && (a.x - a.stopX) * a.dir >= 0 { a.state = 1 }
                if a.state == 1 {
                    a.timer += 1
                    if let o = walkers.first(where: { $0.kind == .kid && $0.id != a.id && $0.state == 1 }) {
                        a.dir = o.x > a.x ? 1 : -1
                        if a.timer > 80 && a.throwsLeft > 0 {
                            a.timer = CGFloat.random(in: 0...25)
                            throwSnowball(from: a, to: o)
                            a.throwsLeft -= 1
                        }
                    } else if a.timer > 200 {
                        a.throwsLeft = 0
                    }
                    if a.throwsLeft <= 0 && a.timer > 40 {
                        a.state = 2
                        a.speed = 2.2
                        a.dir = a.x < w / 2 ? -1 : 1
                    }
                }
                moving = a.state != 1
            case .dog:
                if a.state == 0 && (a.x - a.stopX) * a.dir >= 0 { a.state = 1; a.timer = 0 }
                if a.state == 1 {
                    a.timer += 1
                    let dx = a.x + a.dir * 14
                    let k = index(dx)
                    if Int(a.timer) % 3 == 0 && !isSummer && !heights.isEmpty && heights[k] > 1 && particles.count < 1500 {
                        heights[k] -= 0.6
                        particles.append(Particle(x: dx, y: ground + heights[k], vx: -a.dir * CGFloat.random(in: 1...3),
                                                  vy: CGFloat.random(in: 2...4), r: isSpring ? CGFloat.random(in: 1.05...1.4) : CGFloat.random(in: 1.5...3)))
                    }
                    if a.timer > 130 { a.state = 2 }
                }
                moving = a.state != 1
            case .cat:
                if a.state == 0 && (a.x - a.stopX) * a.dir >= 0 { a.state = 1; a.timer = 0 }
                if a.state == 1 {
                    a.timer += 1
                    if a.timer > 240 { a.state = 2 }
                }
                moving = a.state != 1
            case .yeti:
                if a.state == 0 {
                    var target: CGFloat? = nil
                    for sm in snowmen where (sm.x - a.x) * a.dir > -10 {
                        if let tg = target { if abs(sm.x - a.x) < abs(tg - a.x) { target = sm.x } } else { target = sm.x }
                    }
                    if treeStanding && (treeX - a.x) * a.dir > -10 {
                        if let tg = target { if abs(treeX - a.x) < abs(tg - a.x) { target = treeX } } else { target = treeX }
                    }
                    if let tx = target, abs(tx - a.x) < 26 {
                        if let k = snowmen.firstIndex(where: { abs($0.x - tx) < 1 }) {
                            breakSnowman(at: k)
                        } else if treeStanding {
                            knockTree(dir: a.dir)
                        }
                        a.state = 1
                        a.timer = 0
                    }
                } else if a.state == 1 {
                    a.timer += 1
                    if a.timer > 70 { a.state = 0 }
                }
                moving = a.state != 1
            case .janitor:
                if tractorX != nil && a.state != 2 {
                    // приехала машина — дворник уступает ей работу
                    a.state = 2
                    a.speed = 1.3
                }
                if a.state == 0 {
                    if a.timer > 0 { a.timer -= 1 }
                    let front = a.x + a.dir * 16
                    if a.timer <= 0 && front > 0 && front < w && !heights.isEmpty && heights[index(front)] > 10 {
                        a.state = 1
                        a.timer = 0
                    }
                } else if a.state == 1 {
                    a.timer += 1
                    if Int(a.timer) % 22 == 11 {
                        // копок лопатой: снег спереди убирается, часть летит за спину
                        let front = a.x + a.dir * 16
                        for k in index(front - 7)...index(front + 7) {
                            heights[k] = max(1, heights[k] - 2.4)
                        }
                        for _ in 0..<5 where particles.count < 1500 {
                            particles.append(Particle(x: a.x - a.dir * 4, y: surface(a.x) + 30,
                                                      vx: -a.dir * CGFloat.random(in: 1.5...3.5),
                                                      vy: CGFloat.random(in: 2.5...4.5), r: isSpring ? CGFloat.random(in: 1.05...1.4) : CGFloat.random(in: 1.5...3)))
                        }
                    }
                    if a.timer > 160 || heights[index(a.x + a.dir * 16)] < 3 {
                        a.state = 0
                        a.timer = 50
                    }
                }
                moving = a.state != 1
            }
            if moving {
                let sp = a.speed * (a.hit > 0 ? 1.8 : 1)
                a.x += sp * a.dir
                a.phase += sp * 0.11
                let stepLen: CGFloat = a.kind == .yeti ? 20 : 12
                if abs(a.x - a.lastPrint) > stepLen {
                    a.lastPrint = a.x
                    let k = index(a.x)
                    if !heights.isEmpty && heights[k] > 2 {
                        heights[k] -= min(heights[k] * 0.12, a.kind == .yeti ? 2.5 : 1)
                    }
                }
            } else {
                a.phase += 0.02
            }
            if (a.dir > 0 && a.x > w + 60) || (a.dir < 0 && a.x < -60) {
                walkers.remove(at: i)
                continue
            }
            walkers[i] = a
            i += 1
        }
    }

    // MARK: - Рисование персонажей

    func drawWalkers(_ ctx: CGContext) {
        for a in walkers {
            let base = surface(a.x) - 3
            ctx.saveGState()
            ctx.translateBy(x: a.x, y: base + (a.hit > 0 ? sin(a.hit * .pi) * 6 : 0))
            ctx.setFillColor(rgb(0.15, 0.22, 0.45, 0.3))
            let sw = (a.kind == .yeti ? 26 : (a.kind == .dog ? 18 : 12)) * a.scale
            ctx.fillEllipse(in: CGRect(x: -sw, y: -3, width: sw * 2, height: 6))
            if a.dir < 0 { ctx.scaleBy(x: -1, y: 1) }
            ctx.scaleBy(x: a.scale, y: a.scale)
            switch a.kind {
            case .person: drawPerson(ctx, a, kid: false)
            case .kid: drawPerson(ctx, a, kid: true)
            case .dog: drawDog(ctx, a)
            case .cat: drawCat(ctx, a)
            case .yeti: drawYeti(ctx, a)
            case .janitor: drawJanitor(ctx, a)
            }
            ctx.restoreGState()
        }
    }

    func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ width: CGFloat, _ c: CGColor) {
        ctx.setStrokeColor(c)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }

    func drawPerson(_ ctx: CGContext, _ a: Walker, kid: Bool) {
        let walking = a.state != 1
        let sw = walking ? sin(a.phase) * 0.45 : 0
        let pants = rgb(0.13, 0.14, 0.2)
        let coat = rgb(a.c1.0, a.c1.1, a.c1.2)
        let coatDark = rgb(a.c1.0 * 0.6, a.c1.1 * 0.6, a.c1.2 * 0.6)
        let hat = rgb(a.c2.0, a.c2.1, a.c2.2)
        let skin = rgb(0.96, 0.8, 0.68)
        let hip = CGPoint(x: 0, y: 24)
        func foot(_ ang: CGFloat) -> CGPoint { CGPoint(x: sin(ang) * 22, y: max(0, 24 - cos(ang) * 24)) }
        // ноги
        line(ctx, hip, foot(-sw), 5, rgb(0.09, 0.1, 0.15))
        line(ctx, hip, foot(sw), 5, pants)
        for f in [foot(-sw), foot(sw)] {
            ctx.setFillColor(rgb(0.25, 0.15, 0.1))
            ctx.fillEllipse(in: CGRect(x: f.x - 2.5, y: f.y - 1, width: 7, height: 4))
        }
        // рука сзади
        let sh = CGPoint(x: 0, y: 43)
        line(ctx, sh, CGPoint(x: sh.x - sin(sw * 0.8) * 15, y: sh.y - cos(sw * 0.8) * 15), 4.5, coatDark)
        // куртка
        let bodyRect = kid ? CGRect(x: -8.5, y: 21, width: 17, height: 24) : CGRect(x: -7.5, y: 18, width: 15, height: 27)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: bodyRect, cornerWidth: 5, cornerHeight: 5, transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(linGrad(coat, coatDark), start: CGPoint(x: -8, y: 45), end: CGPoint(x: 8, y: 18), options: [])
        ctx.restoreGState()
        // рука спереди (у ребёнка — замах при броске)
        var ang = -sw * 0.8
        if kid && a.state == 1 && a.timer > 55 && a.timer < 80 { ang = -2.6 }
        let hand = CGPoint(x: sh.x - sin(ang) * 15, y: sh.y - cos(ang) * 15)
        line(ctx, sh, hand, 4.5, coat)
        if kid && isSpring { drawKite(ctx, hand: hand) }
        ctx.setFillColor(isSummer ? skin : hat)
        ctx.fillEllipse(in: CGRect(x: hand.x - 2.3, y: hand.y - 2.3, width: 4.6, height: 4.6))
        if kid && a.state == 1 && a.timer > 55 && a.timer < 80 {
            if isSummer {
                // палочка для пузырей
                ctx.setStrokeColor(rgb(0.95, 0.4, 0.6))
                ctx.setLineWidth(1)
                ctx.strokeEllipse(in: CGRect(x: hand.x - 2.5, y: hand.y + 1, width: 5, height: 5))
            } else if isAutumn, let img = leafSprite(0.71) {
                ctx.draw(img, in: CGRect(x: hand.x - 5, y: hand.y - 1, width: 10, height: 10))
            } else {
                ctx.setFillColor(rgb(1, 1, 1))
                ctx.fillEllipse(in: CGRect(x: hand.x - 3, y: hand.y, width: 6, height: 6))
            }
        }
        // шарф, голова, шапка (летом — без шарфа, вместо шапки волосы)
        let summer = isSummer
        if !summer {
            ctx.setFillColor(hat)
            ctx.fill(CGRect(x: -6.5, y: 43, width: 13, height: 4))
            ctx.fill(CGRect(x: -6, y: 36, width: 3.5, height: 8))
        }
        ctx.setFillColor(skin)
        ctx.fillEllipse(in: CGRect(x: -5, y: 46, width: 12, height: 12))
        ctx.setFillColor(rgb(0.15, 0.1, 0.1))
        ctx.fillEllipse(in: CGRect(x: 3.5, y: 52.5, width: 1.6, height: 1.6))
        ctx.setFillColor(rgb(0.95, 0.6, 0.55, 0.6))
        ctx.fillEllipse(in: CGRect(x: 2, y: 48.5, width: 3, height: 2))
        ctx.setFillColor(summer ? rgb(0.28 + a.c2.0 * 0.15, 0.18 + a.c2.1 * 0.08, 0.1) : hat)
        let cap = CGMutablePath()
        cap.addArc(center: CGPoint(x: 1, y: 53), radius: 6.5, startAngle: 0.15, endAngle: .pi - 0.15, clockwise: false)
        cap.closeSubpath()
        ctx.addPath(cap)
        ctx.fillPath()
        if !summer {
            ctx.setFillColor(rgb(0.97, 0.97, 0.97))
            ctx.fillEllipse(in: CGRect(x: -1.5, y: 58, width: kid ? 6 : 5, height: kid ? 6 : 5))
        }
        if !kid && a.kind == .person && season != .winter && prefs.rain && prefs.umbrellas { drawUmbrella(ctx, a) }
    }

    func drawJanitor(_ ctx: CGContext, _ a: Walker) {
        drawPerson(ctx, a, kid: false)
        // светоотражающие полосы на жилете
        ctx.setFillColor(rgb(0.85, 0.88, 0.9))
        ctx.fill(CGRect(x: -7.5, y: 27, width: 15, height: 1.6))
        ctx.fill(CGRect(x: -7.5, y: 33, width: 15, height: 1.6))
        // шапка-ушанка
        ctx.setFillColor(rgb(0.3, 0.27, 0.25))
        ctx.fill(CGRect(x: -6.5, y: 49, width: 3, height: 5))
        if isAutumn { drawRake(ctx, a); return }
        if isSummer { drawMower(ctx, a); return }
        // лопата
        let wood = rgb(0.55, 0.38, 0.2)
        let steel = rgb(0.45, 0.47, 0.5)
        if a.state == 1 {
            let sw = sin(a.timer * 0.29)
            let top = CGPoint(x: -4, y: 38)
            let end = CGPoint(x: 15 + sw * 4, y: 6 + max(0, sw) * 14)
            line(ctx, top, end, 2, wood)
            ctx.saveGState()
            ctx.translateBy(x: end.x, y: end.y)
            ctx.rotate(by: -0.5 + sw * 0.4)
            ctx.setFillColor(steel)
            ctx.fill(CGRect(x: -1, y: -4.5, width: 9, height: 9))
            if sw > 0 {
                ctx.setFillColor(rgb(0.97, 0.98, 1))
                ctx.fillEllipse(in: CGRect(x: 0, y: 2, width: 8, height: 4))
            }
            ctx.restoreGState()
        } else {
            line(ctx, CGPoint(x: -14, y: 54), CGPoint(x: 9, y: 38), 2, wood)
            ctx.saveGState()
            ctx.translateBy(x: -15, y: 55)
            ctx.rotate(by: 0.6)
            ctx.setFillColor(steel)
            ctx.fill(CGRect(x: -8, y: -4.5, width: 9, height: 9))
            ctx.restoreGState()
        }
    }

    func drawDog(_ ctx: CGContext, _ a: Walker) {
        let c = rgb(a.c1.0, a.c1.1, a.c1.2)
        let dark = rgb(a.c1.0 * 0.6, a.c1.1 * 0.6, a.c1.2 * 0.6)
        let digging = a.state == 1
        let g = digging ? sin(t * 30) * 0.7 : sin(a.phase * 1.5) * 0.6
        // ноги
        for (x, ph) in [(-9.0, 0.0), (-6.0, 1.0), (7.0, 1.0), (10.0, 0.0)] as [(CGFloat, CGFloat)] {
            let ang = (ph == 0 ? g : -g)
            line(ctx, CGPoint(x: x, y: 11), CGPoint(x: x + sin(ang) * 9, y: max(0, 11 - cos(ang) * 11)), 3, ph == 0 ? c : dark)
        }
        // хвост виляет
        line(ctx, CGPoint(x: -12, y: 17), CGPoint(x: -19, y: 22 + sin(t * 14) * 3), 3, c)
        // туловище
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: -14, y: 9, width: 28, height: 12))
        ctx.clip()
        ctx.drawLinearGradient(linGrad(c, dark), start: CGPoint(x: 0, y: 21), end: CGPoint(x: 0, y: 9), options: [])
        ctx.restoreGState()
        // голова
        let hy: CGFloat = digging ? 12 : 21
        ctx.setFillColor(c)
        ctx.fillEllipse(in: CGRect(x: 10, y: hy - 5, width: 11, height: 11))
        ctx.fillEllipse(in: CGRect(x: 17, y: hy - 5, width: 8, height: 5.5))
        ctx.setFillColor(rgb(0.08, 0.06, 0.06))
        ctx.fillEllipse(in: CGRect(x: 23.5, y: hy - 3, width: 2.6, height: 2.2))
        ctx.fillEllipse(in: CGRect(x: 16.5, y: hy + 1.5, width: 1.8, height: 1.8))
        ctx.setFillColor(dark)
        ctx.fillEllipse(in: CGRect(x: 10.5, y: hy - 2, width: 4.5, height: 8))
    }

    func drawCat(_ ctx: CGContext, _ a: Walker) {
        let c = rgb(a.c1.0, a.c1.1, a.c1.2)
        let dark = rgb(a.c1.0 * 0.65, a.c1.1 * 0.65, a.c1.2 * 0.65)
        if a.state == 1 {
            // сидит и машет хвостом
            ctx.setFillColor(c)
            ctx.fillEllipse(in: CGRect(x: -7, y: 0, width: 13, height: 16))
            ctx.fillEllipse(in: CGRect(x: -2, y: 13, width: 10, height: 9))
            ctx.move(to: CGPoint(x: 0, y: 20)); ctx.addLine(to: CGPoint(x: 1, y: 25)); ctx.addLine(to: CGPoint(x: 3, y: 21)); ctx.closePath(); ctx.fillPath()
            ctx.move(to: CGPoint(x: 4.5, y: 21)); ctx.addLine(to: CGPoint(x: 6.5, y: 25)); ctx.addLine(to: CGPoint(x: 7.5, y: 20)); ctx.closePath(); ctx.fillPath()
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: -6, y: 2))
            tail.addQuadCurve(to: CGPoint(x: -14, y: 8 + sin(t * 3) * 4), control: CGPoint(x: -14, y: 0))
            ctx.addPath(tail)
            ctx.setStrokeColor(dark)
            ctx.setLineWidth(2.4)
            ctx.setLineCap(.round)
            ctx.strokePath()
            ctx.setFillColor(rgb(0.4, 0.8, 0.3))
            ctx.fillEllipse(in: CGRect(x: 4.5, y: 17, width: 1.8, height: 1.8))
            return
        }
        let g = sin(a.phase * 1.2) * 0.5
        for (x, ph) in [(-7.0, 0.0), (-5.0, 1.0), (5.0, 1.0), (7.0, 0.0)] as [(CGFloat, CGFloat)] {
            let ang = (ph == 0 ? g : -g)
            line(ctx, CGPoint(x: x, y: 7), CGPoint(x: x + sin(ang) * 6, y: max(0, 7 - cos(ang) * 7)), 2, ph == 0 ? c : dark)
        }
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -9, y: 10))
        tail.addQuadCurve(to: CGPoint(x: -15, y: 22 + sin(t * 2) * 2), control: CGPoint(x: -18, y: 10))
        ctx.addPath(tail)
        ctx.setStrokeColor(c)
        ctx.setLineWidth(2.4)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.setFillColor(c)
        ctx.fillEllipse(in: CGRect(x: -10, y: 6, width: 20, height: 8.5))
        ctx.fillEllipse(in: CGRect(x: 7, y: 9.5, width: 9, height: 8.5))
        ctx.move(to: CGPoint(x: 8, y: 16)); ctx.addLine(to: CGPoint(x: 9, y: 21)); ctx.addLine(to: CGPoint(x: 11, y: 17)); ctx.closePath(); ctx.fillPath()
        ctx.move(to: CGPoint(x: 12.5, y: 17)); ctx.addLine(to: CGPoint(x: 14.5, y: 21)); ctx.addLine(to: CGPoint(x: 15.5, y: 15.5)); ctx.closePath(); ctx.fillPath()
        ctx.setFillColor(rgb(0.4, 0.8, 0.3))
        ctx.fillEllipse(in: CGRect(x: 12.5, y: 13.5, width: 1.8, height: 1.8))
    }

    func drawYeti(_ ctx: CGContext, _ a: Walker) {
        let roar = a.state == 1
        if roar { ctx.translateBy(x: CGFloat.random(in: -1.5...1.5), y: 0) }
        let fur = rgb(0.95, 0.97, 1)
        let shade = rgb(0.72, 0.8, 0.92)
        let g = roar ? 0 : sin(a.phase * 0.9) * 0.4
        // ноги
        line(ctx, CGPoint(x: -7, y: 14), CGPoint(x: -7 + sin(g) * 8, y: 2), 11, shade)
        line(ctx, CGPoint(x: 7, y: 14), CGPoint(x: 7 - sin(g) * 8, y: 2), 11, fur)
        // туловище с мехом
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: -20, y: 8, width: 40, height: 58))
        ctx.clip()
        ctx.drawLinearGradient(linGrad(fur, shade), start: CGPoint(x: -10, y: 66), end: CGPoint(x: 15, y: 8), options: [])
        ctx.restoreGState()
        ctx.setFillColor(fur)
        for k in 0..<14 {
            let ang = CGFloat(k) / 14 * 2 * .pi
            ctx.fillEllipse(in: CGRect(x: cos(ang) * 19 - 4.5, y: 37 + sin(ang) * 28 - 4.5, width: 9, height: 9))
        }
        // руки
        let arm = roar ? -2.4 : -g * 1.2
        line(ctx, CGPoint(x: 12, y: 46), CGPoint(x: 12 + sin(-arm) * 18, y: 46 - cos(arm) * 18), 9, fur)
        line(ctx, CGPoint(x: -12, y: 46), CGPoint(x: -12 - sin(-arm) * 14, y: 46 - cos(arm) * 18), 9, shade)
        // лицо
        ctx.setFillColor(rgb(0.62, 0.78, 0.95))
        ctx.fillEllipse(in: CGRect(x: -2, y: 40, width: 20, height: 17))
        ctx.setFillColor(rgb(0.08, 0.1, 0.18))
        ctx.fillEllipse(in: CGRect(x: 3, y: 50, width: 3, height: 3.4))
        ctx.fillEllipse(in: CGRect(x: 11, y: 50, width: 3, height: 3.4))
        if roar {
            ctx.setFillColor(rgb(0.45, 0.1, 0.2))
            ctx.fillEllipse(in: CGRect(x: 4, y: 41.5, width: 10, height: 7))
            ctx.setFillColor(rgb(1, 1, 1))
            ctx.fill(CGRect(x: 5.5, y: 46.5, width: 2, height: 2))
            ctx.fill(CGRect(x: 10.5, y: 46.5, width: 2, height: 2))
        } else {
            line(ctx, CGPoint(x: 5, y: 45), CGPoint(x: 12, y: 45.5), 1.4, rgb(0.08, 0.1, 0.18))
        }
        // рожки
        ctx.setFillColor(rgb(0.7, 0.72, 0.78))
        ctx.move(to: CGPoint(x: -8, y: 62)); ctx.addLine(to: CGPoint(x: -12, y: 72)); ctx.addLine(to: CGPoint(x: -4, y: 64)); ctx.closePath(); ctx.fillPath()
        ctx.move(to: CGPoint(x: 6, y: 64)); ctx.addLine(to: CGPoint(x: 10, y: 73)); ctx.addLine(to: CGPoint(x: 12, y: 62)); ctx.closePath(); ctx.fillPath()
    }

    // MARK: - Частичная перерисовка

    func bbox(_ pts: [CGPoint], pad: CGFloat) -> CGRect {
        guard let f = pts.first else { return .zero }
        var r = CGRect(origin: f, size: .zero)
        for p in pts { r = r.union(CGRect(origin: p, size: .zero)) }
        return r.insetBy(dx: -pad, dy: -pad)
    }

    /// Помечаем для перерисовки только те области, где что-то меняется.
    func invalidateDirty() {
        let w = bounds.width
        var rects: [CGRect] = [CGRect(x: 0, y: 0, width: w, height: ground + max(330, treeHeightPt + 70))]
        // гирлянда живёт в верхнем окне
        var gr = CGRect.zero
        for (_, r) in ropes {
            let bb = bbox(r.pts, pad: 40)
            gr = gr.isEmpty ? bb : gr.union(bb)
        }
        if prefs.editGarland { gr = bounds }
        if let gv = garlandView {
            if !gr.isEmpty { gv.setNeedsDisplay(gr) }
            if !lastGarlandRect.isEmpty { gv.setNeedsDisplay(lastGarlandRect) }
        }
        lastGarlandRect = gr
        for wr in winRects {
            rects.append(CGRect(x: wr.rect.minX - 6, y: wr.rect.maxY - 6, width: wr.rect.width + 12, height: 22))
        }
        if let sx = sleighX {
            rects.append(isSpring ? CGRect(x: sx - 30, y: sleighY - 70, width: 200, height: 150)
                                  : CGRect(x: sx - 40, y: sleighY - 30, width: 420, height: isSummer ? 140 : 80))
        }
        if !birds.isEmpty { rects.append(bbox(birds.map { CGPoint(x: $0.x, y: $0.y + 6) }, pad: 20)) }
        if !bubbles.isEmpty { rects.append(bbox(bubbles.map { CGPoint(x: $0.x, y: $0.y) }, pad: 16)) }
        if !sparks.isEmpty { rects.append(bbox(sparks.map { CGPoint(x: $0.x, y: $0.y) }, pad: 6)) }
        if !particles.isEmpty { rects.append(bbox(particles.map { CGPoint(x: $0.x, y: $0.y) }, pad: 8)) }
        if !snowballs.isEmpty { rects.append(bbox(snowballs.map { CGPoint(x: $0.x, y: $0.y) }, pad: 20)) }
        if let b = held { rects.append(CGRect(x: b.x - 50, y: b.y - 50, width: 100, height: 100)) }
        if prefs.editGarland { rects = [bounds] }
        for r in rects + lastDirty { setNeedsDisplay(r) }
        lastDirty = rects
    }
}
