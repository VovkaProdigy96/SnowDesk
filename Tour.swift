// SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/)
// Демо-тур для записи промо-видео: если рядом с SnowDesk.app появляется файл `demo_tour`,
// программа сама показывает всё по сценарию (~75 секунд), а потом возвращает настройки.

import AppKit

extension SnowView {
    /// Сразу насыпать снег (или листья) — чтобы не ждать накопления.
    func fillForDemo() {
        guard !heights.isEmpty else { return }
        var ph = CGFloat.random(in: 0...10)
        for k in heights.indices {
            ph += 0.015
            heights[k] = min(maxHeight, 15 + sin(ph) * 5 + sin(ph * 2.7) * 3)
        }
        for (id, var c) in caps {
            for k in c.h.indices { c.h[k] = capCapacity(c, k) * 0.9 }
            caps[id] = c
        }
    }
}

@MainActor
final class DemoTour {
    let app: AppDelegate
    var view: SnowView { app.view }
    var start = Date()
    var step = 0
    var timer: Timer?
    // что вернуть после тура
    var saved: (season: Int, demo: Bool, snow: Double, leaf: Double, snowing: Bool, rain: Bool)

    init(app: AppDelegate) {
        self.app = app
        let p = Prefs.shared
        saved = (p.seasonMode, p.demo, p.snowAmount, p.leafAmount, p.snowing, p.rain)
    }

    static var triggerURL: URL {
        Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("demo_tour")
    }

    /// Проверяется пару раз в секунду: есть файл — запускаем тур.
    static func check(_ app: AppDelegate) {
        guard app.tour == nil, FileManager.default.fileExists(atPath: triggerURL.path) else { return }
        try? FileManager.default.removeItem(at: triggerURL)
        let t = DemoTour(app: app)
        app.tour = t
        t.begin()
    }

    func begin() {
        let p = Prefs.shared
        p.snowing = true
        p.rain = false
        p.snowAmount = 1
        p.leafAmount = 0.8
        p.demo = false
        p.seasonMode = 1
        start = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Сценарий: (секунда, действие).
    lazy var script: [(Double, (DemoTour) -> Void)] = [
        (0.6, { $0.view.fillForDemo() }),
        (2.5, { $0.buildSnowman(0.38) }),
        (5.0, { $0.buildSnowman(0.62) }),
        (8.0, { $0.view.callTractor() }),
        (13.0, { $0.view.spawn(.kid) }),
        (17.0, { $0.view.spawn(.dog) }),
        (20.0, { $0.view.gust() }),
        (23.0, { $0.view.callSleigh() }),
        (26.0, { $0.setDemo(true) }),          // закат и ночь
        (38.0, { $0.setDemo(false) }),
        (39.0, { $0.season(2) }),               // весна
        (39.6, { $0.view.startSpring() }),
        (40.5, { $0.app.handleAction(Notification(name: Prefs.actionNote, object: "birds")) }),
        (42.0, { $0.view.spawn(.kid) }),
        (48.0, { $0.season(3) }),               // лето
        (49.0, { $0.app.handleAction(Notification(name: Prefs.actionNote, object: "butterflies")) }),
        (50.0, { $0.app.handleAction(Notification(name: Prefs.actionNote, object: "bubbles")) }),
        (51.0, { $0.view.callSleigh() }),
        (53.0, { $0.view.spawn(.kid) }),
        (57.0, { $0.season(4) }),               // осень
        (57.6, { $0.view.fillForDemo() }),
        (58.5, { $0.view.leafShower() }),
        (61.0, { $0.view.callTractor() }),
        (63.0, { $0.view.kickLeaves(at: CGPoint(x: $0.view.bounds.width * 0.5, y: $0.view.ground + 5), power: 1.4) }),
        (66.0, { $0.season(1) }),               // снова зима
        (66.6, { $0.view.fillForDemo() }),
        (67.5, { $0.buildSnowman(0.5) }),
        (76.0, { $0.finish() }),
    ]

    func tick() {
        let el = Date().timeIntervalSince(start)
        while step < script.count && el >= script[step].0 {
            script[step].1(self)
            step += 1
        }
    }

    func buildSnowman(_ fx: CGFloat) {
        let v = view
        let x = v.bounds.width * fx
        let s = CGFloat.random(in: 0.95...1.15)
        v.snowmen.append(Snowman(x: x, radii: [22 * s, 16 * s, 11 * s], progress: 0))
    }

    func season(_ mode: Int) { Prefs.shared.seasonMode = mode }

    func setDemo(_ on: Bool) { Prefs.shared.demo = on }

    func finish() {
        timer?.invalidate()
        let p = Prefs.shared
        p.seasonMode = saved.season
        p.demo = saved.demo
        p.snowAmount = saved.snow
        p.leafAmount = saved.leaf
        p.snowing = saved.snowing
        p.rain = saved.rain
        app.tour = nil
    }
}
