// SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/)
// Снегопад / листопад / дождь на видеочипе: системные частицы Core Animation (почти не грузят процессор).

import AppKit

final class SnowfallView: NSView {
    let emitter = CAEmitterLayer()
    let rainEmitter = CAEmitterLayer()
    var lastAmount: CGFloat = -1
    var lastSize = CGSize.zero
    var lastSeason: Season? = nil
    var lastRain: CGFloat = -1

    static let flake = SceneView.radialImage(size: 32, stops: [
        (0, 1, 1, 1, 1), (0.35, 1, 1, 1, 0.85), (0.7, 1, 1, 1, 0.25), (1, 1, 1, 1, 0)])
    static let bokeh = SceneView.radialImage(size: 64, stops: [
        (0, 1, 1, 1, 0.5), (0.6, 1, 1, 1, 0.38), (0.85, 1, 1, 1, 0.12), (1, 1, 1, 1, 0)])

    /// Капля дождя — тонкий светлый штрих.
    static let drop: CGImage? = {
        let w = 4, h = 64
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [CGColor(red: 0.85, green: 0.9, blue: 1, alpha: 0),
                                    CGColor(red: 0.85, green: 0.9, blue: 1, alpha: 0.9)] as CFArray,
                           locations: [0, 1])!
        ctx.addRect(CGRect(x: 1, y: 0, width: 2, height: h))
        ctx.clip()
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
        return ctx.makeImage()
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.addSublayer(emitter)
        layer?.addSublayer(rainEmitter)
        for e in [emitter, rainEmitter] {
            e.emitterShape = .line
            e.renderMode = .unordered
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    // мышь проходит насквозь
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func cell(_ name: String, _ img: CGImage?, rate: Float, vel: CGFloat, scale: CGFloat,
              alpha: CGFloat, height: CGFloat) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.name = name
        c.contents = img
        c.birthRate = rate
        c.velocity = vel
        c.velocityRange = vel * 0.3
        c.emissionLongitude = -.pi / 2
        c.emissionRange = 0.18
        c.lifetime = Float((height + 120) / (vel * 0.7))
        c.scale = scale
        c.scaleRange = scale * 0.4
        c.alphaRange = 0.2
        c.color = CGColor(red: 1, green: 1, blue: 1, alpha: alpha)
        c.spin = 0.3
        c.spinRange = 0.8
        c.yAcceleration = -3
        return c
    }

    /// Падающий лист: медленный, кружится, ветер его сносит сильнее, чем снег.
    func leafCell(_ name: String, _ img: CGImage?, rate: Float, vel: CGFloat, scale: CGFloat,
                  alpha: CGFloat, height: CGFloat) -> CAEmitterCell {
        let c = cell(name, img, rate: rate, vel: vel, scale: scale, alpha: alpha, height: height)
        c.emissionRange = 0.7
        c.spin = 1.2
        c.spinRange = 3.5
        c.velocityRange = vel * 0.5
        c.yAcceleration = -2
        c.lifetime = Float((height + 160) / (vel * 0.55))
        c.alphaRange = 0.1
        return c
    }

    func update(size: CGSize, amount: CGFloat, snowing: Bool, wind: CGFloat,
                season: Season = .winter, rain: CGFloat = 0) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if size != lastSize || abs(amount - lastAmount) > 0.01 || season != lastSeason {
            lastSize = size
            lastAmount = amount
            lastSeason = season
            emitter.frame = CGRect(origin: .zero, size: size)
            emitter.emitterPosition = CGPoint(x: size.width / 2, y: size.height + 30)
            emitter.emitterSize = CGSize(width: size.width * 1.5, height: 1)
            let k = Float(size.width / 1440 * amount)
            if season == .summer {
                // тополиный пух — редкий, медленный, парит
                func fluff(_ name: String, rate: Float, vel: CGFloat, scale: CGFloat, alpha: CGFloat) -> CAEmitterCell {
                    let c = cell(name, Fluff.sprite, rate: rate, vel: vel, scale: scale, alpha: alpha, height: size.height)
                    c.emissionRange = 1.2
                    c.yAcceleration = -0.6
                    c.velocityRange = vel * 0.6
                    c.spin = 0.2
                    c.spinRange = 0.6
                    c.lifetime = Float((size.height + 200) / (vel * 0.4))
                    return c
                }
                emitter.emitterCells = [
                    fluff("far", rate: 7 * k, vel: 12, scale: 0.3, alpha: 0.6),
                    fluff("mid", rate: 4 * k, vel: 18, scale: 0.5, alpha: 0.85),
                    fluff("near", rate: 1 * k, vel: 26, scale: 0.85, alpha: 0.9),
                ]
            } else if season == .spring {
                var cells: [CAEmitterCell] = []
                let imgs = Petals.sprites
                let n = Float(max(1, imgs.count))
                for (i, img) in imgs.enumerated() {
                    cells.append(leafCell("far\(i)", img, rate: 10 * k / n, vel: 22, scale: 0.18, alpha: 0.8, height: size.height))
                    cells.append(leafCell("mid\(i)", img, rate: 5 * k / n, vel: 32, scale: 0.3, alpha: 0.95, height: size.height))
                    cells.append(leafCell("near\(i)", img, rate: 1 * k / n, vel: 48, scale: 0.5, alpha: 1, height: size.height))
                }
                emitter.emitterCells = cells
            } else if season == .autumn {
                // дальние листья — мелкие, ближние — крупные
                var cells: [CAEmitterCell] = []
                let imgs = Leaves.sprites
                let n = Float(max(1, imgs.count))
                for (i, img) in imgs.enumerated() {
                    cells.append(leafCell("far\(i)", img, rate: 9 * k / n, vel: 26, scale: 0.22, alpha: 0.75, height: size.height))
                    cells.append(leafCell("mid\(i)", img, rate: 5 * k / n, vel: 40, scale: 0.36, alpha: 0.95, height: size.height))
                    cells.append(leafCell("near\(i)", img, rate: 1.2 * k / n, vel: 62, scale: 0.6, alpha: 1, height: size.height))
                }
                emitter.emitterCells = cells
            } else {
                emitter.emitterCells = [
                    cell("far", SnowfallView.flake, rate: 55 * k, vel: 28, scale: 0.12, alpha: 0.55, height: size.height),
                    cell("mid", SnowfallView.flake, rate: 26 * k, vel: 48, scale: 0.2, alpha: 0.85, height: size.height),
                    cell("near", SnowfallView.bokeh, rate: 4 * k, vel: 85, scale: 0.36, alpha: 0.7, height: size.height),
                ]
            }
        }
        emitter.birthRate = snowing ? 1 : 0
        if let cells = emitter.emitterCells {
            for c in cells {
                guard let n = c.name else { continue }
                let f: CGFloat = n.hasPrefix("far") ? 4 : (n.hasPrefix("mid") ? 6 : 9)
                let leafy: CGFloat = season == .autumn || season == .spring ? 1.8 : 1
                emitter.setValue(wind * f * leafy, forKeyPath: "emitterCells.\(n).xAcceleration")
            }
        }

        // дождь — отдельный слой, капли падают быстро и почти прямо
        if size != rainEmitter.frame.size || abs(rain - lastRain) > 0.01 {
            lastRain = rain
            rainEmitter.frame = CGRect(origin: .zero, size: size)
            rainEmitter.emitterPosition = CGPoint(x: size.width / 2, y: size.height + 40)
            rainEmitter.emitterSize = CGSize(width: size.width * 1.4, height: 1)
            if rain > 0 {
                let k = Float(size.width / 1440 * rain)
                func drop(_ name: String, rate: Float, vel: CGFloat, scale: CGFloat, alpha: CGFloat) -> CAEmitterCell {
                    let c = CAEmitterCell()
                    c.name = name
                    c.contents = SnowfallView.drop
                    c.birthRate = rate
                    c.velocity = vel
                    c.velocityRange = vel * 0.15
                    c.emissionLongitude = -.pi / 2
                    c.emissionRange = 0.03
                    c.lifetime = Float((size.height + 100) / vel)
                    c.scale = scale
                    c.scaleRange = scale * 0.3
                    c.color = CGColor(red: 1, green: 1, blue: 1, alpha: alpha)
                    c.alphaRange = 0.15
                    return c
                }
                rainEmitter.emitterCells = [
                    drop("rfar", rate: 260 * k, vel: 900, scale: 0.28, alpha: 0.28),
                    drop("rnear", rate: 70 * k, vel: 1300, scale: 0.45, alpha: 0.4),
                ]
            } else {
                rainEmitter.emitterCells = []
            }
        }
        rainEmitter.birthRate = rain > 0 ? 1 : 0
        // косой дождь по ветру: поворачиваем направление вылета
        for n in ["rfar", "rnear"] where rain > 0 {
            rainEmitter.setValue(-CGFloat.pi / 2 + max(-0.35, min(0.35, wind * 0.06)),
                                 forKeyPath: "emitterCells.\(n).emissionLongitude")
        }
        CATransaction.commit()
    }
}
