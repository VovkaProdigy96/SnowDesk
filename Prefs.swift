// SnowDesk — © 2026 VovkaProdigy96 · CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/)
// Настройки SnowDesk: хранятся в UserDefaults, окно настроек на SwiftUI.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Точка крепления гирлянды. Если attached — она привязана к окну или виджету (смещение ox, oy от его левого верхнего угла).
struct GJoint: Codable, Equatable {
    var id: Int
    var x: Double
    var y: Double
    var owner: String
    var ox: Double
    var oy: Double
    var attached: Bool
}

/// Отрезок гирлянды между двумя точками.
struct GSeg: Codable, Equatable {
    var a: Int
    var b: Int
}

/// Время года. Готовы зима и осень; весна и лето — в работе.
enum Season: Int, CaseIterable {
    case winter = 0, spring, summer, autumn

    var title: String {
        switch self {
        case .winter: return "Зима"
        case .spring: return "Весна"
        case .summer: return "Лето"
        case .autumn: return "Осень"
        }
    }
    var ready: Bool { true }

    /// Сезон по календарю.
    static func byDate(_ date: Date = Date()) -> Season {
        switch Calendar.current.component(.month, from: date) {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        default: return .autumn
        }
    }
}

final class Prefs: ObservableObject {
    // о программе
    static let appVersion = "3.0"
    static let author = "VovkaProdigy96"
    static let githubURL = "https://github.com/VovkaProdigy96/SnowDesk"
    static let licenseURL = "https://creativecommons.org/licenses/by-nc/4.0/deed.ru"

    static let shared = Prefs()
    let d = UserDefaults.standard

    /// Растёт при каждом изменении — по нему сцена понимает, что надо перерисовать кэш.
    @Published var version = 0

    @Published var windowSnow: Bool { didSet { save(windowSnow, "windowSnow") } }
    @Published var snowAmount: Double { didSet { save(snowAmount, "snowAmount") } }
    @Published var windAngle: Double { didSet { save(windAngle, "windAngle") } }
    @Published var windStrength: Double { didSet { save(windStrength, "windStrength") } }
    @Published var gusts: Bool { didSet { save(gusts, "gusts") } }

    @Published var treeOn: Bool { didSet { save(treeOn, "treeOn") } }
    @Published var treeSize: Int { didSet { save(treeSize, "treeSize") } }
    @Published var topper: String { didSet { save(topper, "topper") } }
    @Published var baubles: Bool { didSet { save(baubles, "baubles") } }
    @Published var lights: Bool { didSet { save(lights, "lights") } }
    @Published var bells: Bool { didSet { save(bells, "bells") } }
    @Published var gingerbread: Bool { didSet { save(gingerbread, "gingerbread") } }
    @Published var treeSeed: Int { didSet { save(treeSeed, "treeSeed") } }

    @Published var garlandMode: Int { didSet { save(garlandMode, "garlandMode") } }
    @Published var garlandWarm: Bool { didSet { save(garlandWarm, "garlandWarm") } }
    @Published var garlandSlack: Double { didSet { save(garlandSlack, "garlandSlack") } }
    @Published var garlandOver: Bool { didSet { save(garlandOver, "garlandOver") } }
    @Published var editGarland = false
    @Published var gJoints: [GJoint] { didSet { saveGarland() } }
    @Published var gSegs: [GSeg] { didSet { saveGarland() } }

    @Published var decorSet: Int { didSet { save(decorSet, "decorSet") } }
    @Published var decorSize: Int { didSet { save(decorSize, "decorSize") } }

    @Published var eventsOn: Bool { didSet { save(eventsOn, "eventsOn") } }
    @Published var eventRate: Int { didSet { save(eventRate, "eventRate") } }
    @Published var people: Bool { didSet { save(people, "people") } }
    @Published var kids: Bool { didSet { save(kids, "kids") } }
    @Published var dogs: Bool { didSet { save(dogs, "dogs") } }
    @Published var cats: Bool { didSet { save(cats, "cats") } }
    @Published var yeti: Bool { didSet { save(yeti, "yeti") } }

    @Published var snowing: Bool { didSet { save(snowing, "snowing") } }
    @Published var play: Bool { didSet { save(play, "play") } }
    @Published var shovel = false
    @Published var wallpaper: Bool { didSet { save(wallpaper, "wallpaper") } }
    @Published var demo = false
    @Published var garlandOn: Bool { didSet { save(garlandOn, "garlandOn") } }
    @Published var garlandAuto: Bool { didSet { save(garlandAuto, "garlandAuto") } }
    @Published var overWindows: Bool { didSet { save(overWindows, "overWindows") } }
    @Published var widgetSnow: Bool { didSet { save(widgetSnow, "widgetSnow") } }
    @Published var autoPlow: Bool { didSet { save(autoPlow, "autoPlow") } }
    @Published var plowRate: Int { didSet { save(plowRate, "plowRate") } }
    @Published var janitor: Bool { didSet { save(janitor, "janitor") } }
    @Published var carMode: Int { didSet { save(carMode, "carMode") } }
    @Published var carFlip: Bool { didSet { save(carFlip, "carFlip") } }
    @Published var carImagePath: String { didSet { save(carImagePath, "carImagePath") } }

    // сезоны: 0 — по календарю, 1…4 — зима, весна, лето, осень вручную
    @Published var seasonMode: Int { didSet { save(seasonMode, "seasonMode") } }
    @Published var garlandAllYear: Bool { didSet { save(garlandAllYear, "garlandAllYear") } }
    // осень
    @Published var leafAmount: Double { didSet { save(leafAmount, "leafAmount") } }
    @Published var rain: Bool { didSet { save(rain, "rain") } }
    @Published var rainAmount: Double { didSet { save(rainAmount, "rainAmount") } }
    @Published var pumpkins: Bool { didSet { save(pumpkins, "pumpkins") } }
    @Published var umbrellas: Bool { didSet { save(umbrellas, "umbrellas") } }
    @Published var clouds: Bool { didSet { save(clouds, "clouds") } }
    // лето
    @Published var fluffAmount: Double { didSet { save(fluffAmount, "fluffAmount") } }
    @Published var butterflies: Bool { didSet { save(butterflies, "butterflies") } }
    @Published var fireflies: Bool { didSet { save(fireflies, "fireflies") } }
    @Published var flowerBeds: Bool { didSet { save(flowerBeds, "flowerBeds") } }
    // весна
    @Published var petalAmount: Double { didSet { save(petalAmount, "petalAmount") } }
    @Published var meltSpeed: Double { didSet { save(meltSpeed, "meltSpeed") } }
    @Published var birds: Bool { didSet { save(birds, "birds") } }
    @Published var fog: Bool { didSet { save(fog, "fog") } }

    /// Текущий сезон. Пока весна и лето не готовы, вместо них идёт зима.
    var season: Season {
        let s = seasonMode == 0 ? Season.byDate() : (Season(rawValue: seasonMode - 1) ?? .winter)
        return s.ready ? s : .winter
    }
    var isAutumn: Bool { season == .autumn }
    var isSummer: Bool { season == .summer }
    var isSpring: Bool { season == .spring }
    /// Дождь (осенью) или гроза (летом) сейчас идут.
    var raining: Bool { season != .winter && rain }
    /// Сила «осадков» текущего сезона: снегопад зимой, листопад осенью.
    var fallAmount: Double { isAutumn ? leafAmount : (isSummer ? fluffAmount : (isSpring ? petalAmount : snowAmount)) }

    static let actionNote = Notification.Name("SnowDeskAction")

    init() {
        let u = UserDefaults.standard
        windowSnow = u.object(forKey: "windowSnow") as? Bool ?? true
        snowAmount = u.object(forKey: "snowAmount") as? Double ?? 0.6
        windAngle = u.object(forKey: "windAngle") as? Double ?? 0
        windStrength = u.object(forKey: "windStrength") as? Double ?? 0
        gusts = u.object(forKey: "gusts") as? Bool ?? true
        treeOn = u.object(forKey: "treeOn") as? Bool ?? true
        treeSize = u.object(forKey: "treeSize") as? Int ?? 1
        topper = u.object(forKey: "topper") as? String ?? "star"
        baubles = u.object(forKey: "baubles") as? Bool ?? true
        lights = u.object(forKey: "lights") as? Bool ?? true
        bells = u.object(forKey: "bells") as? Bool ?? false
        gingerbread = u.object(forKey: "gingerbread") as? Bool ?? false
        treeSeed = u.object(forKey: "treeSeed") as? Int ?? 7
        garlandMode = u.object(forKey: "garlandMode") as? Int ?? 0
        garlandWarm = u.object(forKey: "garlandWarm") as? Bool ?? false
        garlandSlack = u.object(forKey: "garlandSlack") as? Double ?? 0.5
        garlandOver = u.object(forKey: "garlandOver") as? Bool ?? false
        gJoints = u.data(forKey: "gJoints").flatMap { try? JSONDecoder().decode([GJoint].self, from: $0) } ?? []
        gSegs = u.data(forKey: "gSegs").flatMap { try? JSONDecoder().decode([GSeg].self, from: $0) } ?? []
        decorSet = u.object(forKey: "decorSet") as? Int ?? 1
        decorSize = u.object(forKey: "decorSize") as? Int ?? 1
        eventsOn = u.object(forKey: "eventsOn") as? Bool ?? true
        eventRate = u.object(forKey: "eventRate") as? Int ?? 1
        people = u.object(forKey: "people") as? Bool ?? true
        kids = u.object(forKey: "kids") as? Bool ?? true
        dogs = u.object(forKey: "dogs") as? Bool ?? true
        cats = u.object(forKey: "cats") as? Bool ?? true
        yeti = u.object(forKey: "yeti") as? Bool ?? true
        snowing = u.object(forKey: "snowing") as? Bool ?? true
        play = u.object(forKey: "play") as? Bool ?? true
        wallpaper = u.object(forKey: "wallpaper") as? Bool ?? true
        garlandOn = u.object(forKey: "garlandOn") as? Bool ?? true
        garlandAuto = u.object(forKey: "garlandAuto") as? Bool ?? true
        overWindows = u.object(forKey: "overWindows") as? Bool ?? false
        widgetSnow = u.object(forKey: "widgetSnow") as? Bool ?? true
        autoPlow = u.object(forKey: "autoPlow") as? Bool ?? true
        plowRate = u.object(forKey: "plowRate") as? Int ?? 1
        janitor = u.object(forKey: "janitor") as? Bool ?? true
        carMode = u.object(forKey: "carMode") as? Int ?? 0
        carFlip = u.object(forKey: "carFlip") as? Bool ?? false
        carImagePath = u.object(forKey: "carImagePath") as? String ?? ""
        seasonMode = u.object(forKey: "seasonMode") as? Int ?? 0
        garlandAllYear = u.object(forKey: "garlandAllYear") as? Bool ?? false
        leafAmount = u.object(forKey: "leafAmount") as? Double ?? 0.55
        rain = u.object(forKey: "rain") as? Bool ?? false
        rainAmount = u.object(forKey: "rainAmount") as? Double ?? 0.5
        pumpkins = u.object(forKey: "pumpkins") as? Bool ?? true
        umbrellas = u.object(forKey: "umbrellas") as? Bool ?? true
        clouds = u.object(forKey: "clouds") as? Bool ?? true
        fluffAmount = u.object(forKey: "fluffAmount") as? Double ?? 0.35
        butterflies = u.object(forKey: "butterflies") as? Bool ?? true
        fireflies = u.object(forKey: "fireflies") as? Bool ?? true
        flowerBeds = u.object(forKey: "flowerBeds") as? Bool ?? true
        petalAmount = u.object(forKey: "petalAmount") as? Double ?? 0.4
        meltSpeed = u.object(forKey: "meltSpeed") as? Double ?? 0.35
        birds = u.object(forKey: "birds") as? Bool ?? true
        fog = u.object(forKey: "fog") as? Bool ?? true
    }

    func saveGarland() {
        if let a = try? JSONEncoder().encode(gJoints) { d.set(a, forKey: "gJoints") }
        if let b = try? JSONEncoder().encode(gSegs) { d.set(b, forKey: "gSegs") }
    }

    func save(_ v: Any, _ key: String) {
        d.set(v, forKey: key)
        version &+= 1
    }

    /// Горизонтальная составляющая ветра для сцены.
    var windX: CGFloat { CGFloat(cos(windAngle) * windStrength * 5) }

    /// Команда сцене (слепить снеговика, вызвать машину и т.п.).
    func act(_ name: String) {
        NotificationCenter.default.post(name: Prefs.actionNote, object: name)
    }

    /// Выбор своей картинки машины: копируем её к себе, чтобы она не пропала.
    func chooseCarImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.message = "Выбери картинку машины — лучше PNG с прозрачным фоном, вид сбоку"
        guard panel.runModal() == .OK, let src = panel.url else { return }
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let dir = support.appendingPathComponent("SnowDesk", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dst = dir.appendingPathComponent("car." + (src.pathExtension.isEmpty ? "png" : src.pathExtension.lowercased()))
        try? fm.removeItem(at: dst)
        do {
            try fm.copyItem(at: src, to: dst)
            carImagePath = dst.path
            carMode = 1
        } catch {
            NSSound.beep()
        }
    }

    /// «Удиви меня» — случайный наряд ёлки.
    func surprise() {
        topper = ["star", "snowflake", "bow"].randomElement() ?? "star"
        baubles = Bool.random()
        lights = Bool.random() || !baubles
        bells = Bool.random()
        gingerbread = Bool.random()
        treeSeed = Int.random(in: 1...100000)
    }
}

// MARK: - Компас ветра

struct WindCompass: View {
    @Binding var angle: Double
    @Binding var strength: Double

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = min(geo.size.width, geo.size.height) / 2 - 8
            let tip = CGPoint(x: c.x + CGFloat(cos(angle) * strength) * r,
                              y: c.y - CGFloat(sin(angle) * strength) * r)
            ZStack {
                Circle().fill(Color.blue.opacity(0.07))
                Circle().stroke(Color.secondary.opacity(0.45), lineWidth: 2)
                Path { p in
                    p.move(to: c)
                    p.addLine(to: tip)
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                Circle().fill(Color.blue).frame(width: 14, height: 14).position(tip)
                Text("\(Int(strength * 100))%").font(.caption).position(x: c.x, y: c.y + r * 0.6)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let dx = Double(v.location.x - c.x)
                let dy = Double(c.y - v.location.y)
                angle = atan2(dy, dx)
                strength = min(1, (dx * dx + dy * dy).squareRoot() / Double(r))
            })
        }
        .frame(width: 150, height: 150)
    }
}

// MARK: - Окно настроек

struct SettingsView: View {
    @ObservedObject var p = Prefs.shared

    var body: some View {
        TabView {
            mainTab.tabItem { Text("Главное") }
            if p.isAutumn {
                autumnTab.tabItem { Text("🍂 Осень") }
            } else if p.isSummer {
                summerTab.tabItem { Text("☀️ Лето") }
            } else if p.isSpring {
                springTab.tabItem { Text("🌸 Весна") }
            } else {
                snowTab.tabItem { Text("Снег и ветер") }
            }
            carTab.tabItem { Text("Машина") }
            if p.season != .winter {
                mapleTab.tabItem { Text(p.isSummer ? "Яблоня" : (p.isSpring ? "Вишня" : "Клён")) }
            } else {
                treeTab.tabItem { Text("Ёлка") }
            }
            garlandTab.tabItem { Text("Гирлянда") }
            decorTab.tabItem { Text("Домики") }
            eventsTab.tabItem { Text("События") }
            aboutTab.tabItem { Text("О программе") }
        }
        .padding()
        .frame(width: 760, height: 500)
    }

    func action(_ title: String, _ name: String) -> some View {
        Button(title) { p.act(name) }.frame(maxWidth: .infinity)
    }

    var seasonPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Сезон", selection: $p.seasonMode) {
                Text("По календарю").tag(0)
                Text("❄️ Зима").tag(1)
                Text("🍂 Осень").tag(4)
                Text("🌸 Весна").tag(2)
                Text("☀️ Лето").tag(3)
            }
            .pickerStyle(.menu)
            Text(p.seasonMode == 0
                 ? "Сейчас по календарю: \(Season.byDate().title.lowercased())" + (Season.byDate().ready ? "" : " — пока не готова, показываю зиму")
                 : "Сезон выбран вручную")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var mainTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            seasonPicker
            Divider()
            HStack(alignment: .top, spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(p.isAutumn ? "Листопад" : (p.isSummer ? "Тополиный пух" : (p.isSpring ? "Лепестки вишни" : "Снегопад")), isOn: $p.snowing)
                    if p.isSpring { Toggle("Дождь", isOn: $p.rain) }
                    if p.isAutumn { Toggle("Дождь", isOn: $p.rain) }
                    if p.isSummer { Toggle("Гроза", isOn: $p.rain) }
                    Toggle("Играть мышкой", isOn: $p.play)
                    if !p.isSummer {
                        Toggle(p.isAutumn ? "Грабли (сгребать курсором)" : "Лопата (копать курсором)", isOn: $p.shovel)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Живые обои", isOn: $p.wallpaper)
                    Toggle("Облака на обоях", isOn: $p.clouds)
                    Toggle("Туман в долине", isOn: $p.fog)
                    Toggle("Сутки за 2 минуты (демо)", isOn: $p.demo)
                    Toggle(p.isAutumn ? "Листья и персонажи поверх окон" : "Снег и персонажи поверх окон", isOn: $p.overWindows)
                }
            }
            Divider()
            Text("Сделать прямо сейчас").font(.headline)
            if p.isSpring {
                HStack {
                    action("🐦 Птицы", "birds")
                    action("🪁 Воздушный змей", "kite")
                    action("❄️ Вернуть снег", "respring")
                }
                HStack {
                    action("🚙 Машина", "plow")
                    action("🧹 Дворник", "janitor")
                    action("🎲 Событие", "event")
                }
                HStack {
                    action("💨 Порыв ветра", "gust")
                    Button("Выйти из SnowDesk") { p.act("quit") }.frame(maxWidth: .infinity)
                }
            } else if p.isSummer {
                HStack {
                    action("🦋 Бабочки", "butterflies")
                    action("🫧 Пузыри", "bubbles")
                    action("🎈 Воздушный шар", "sleigh")
                }
                HStack {
                    action("🚙 Машина", "plow")
                    action("🌱 Садовник", "janitor")
                    action("🎲 Событие", "event")
                }
                HStack {
                    action("💨 Порыв ветра", "gust")
                    Button("Выйти из SnowDesk") { p.act("quit") }.frame(maxWidth: .infinity)
                }
            } else if p.isAutumn {
                HStack {
                    action("🍁 Охапка листьев", "leafgust")
                    action("🚙 Машина", "plow")
                    action("🧹 Дворник", "janitor")
                }
                HStack {
                    action("🎲 Событие", "event")
                    action("💨 Порыв ветра", "gust")
                    action("Убрать листья", "clear")
                }
                HStack {
                    Button("Выйти из SnowDesk") { p.act("quit") }.frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    action("⛄ Снеговик", "snowman")
                    action("🚙 Снегоуборщик", "plow")
                    action("🧹 Дворник", "janitor")
                }
                HStack {
                    action("🛷 Сани", "sleigh")
                    action("🐾 Йети", "yeti")
                    action("🎲 Событие", "event")
                }
                HStack {
                    action("💨 Порыв ветра", "gust")
                    action("Очистить снег", "clear")
                    Button("Выйти из SnowDesk") { p.act("quit") }.frame(maxWidth: .infinity)
                }
            }
            Spacer()
        }
        .padding()
    }

    var carTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(p.isSpring ? "Машина приезжает сама (брызги из луж)" : p.isSummer ? "Машина иногда проезжает" : (p.isAutumn ? "Машина приезжает сама (раскидывает листья)" : "Снегоуборщик приезжает сам"), isOn: $p.autoPlow)
            Picker("Как часто", selection: $p.plowRate) {
                Text("Редко").tag(0)
                Text("Обычно").tag(1)
                Text("Часто").tag(2)
            }
            .pickerStyle(.segmented)
            Toggle(p.isSpring ? "Дворник убирает остатки снега" : p.isSummer ? "Садовник с газонокосилкой" : (p.isAutumn ? "Дворник с граблями" : "Дворник с лопатой, когда машины нет"), isOn: $p.janitor)
            Divider()
            Picker("Машина", selection: $p.carMode) {
                Text("Серебристый внедорожник").tag(0)
                Text("Своя картинка").tag(1)
            }
            .pickerStyle(.segmented)
            HStack {
                Button("Выбрать картинку…") { p.chooseCarImage() }
                Text(p.carImagePath.isEmpty ? "не выбрана" : (p.carImagePath as NSString).lastPathComponent)
                    .foregroundColor(.secondary)
            }
            Toggle("Отразить (если машина на картинке смотрит влево)", isOn: $p.carFlip)
            Text("Лучше всего — PNG с прозрачным фоном, машина строго сбоку. Фон можно убрать в «Фото»: правый клик по машине → «Скопировать объект», затем в «Просмотре» → «Файл» → «Новый из буфера обмена». Мигалка и отвал добавятся сами.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }

    var snowTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Снег копится на окнах", isOn: $p.windowSnow)
            Toggle("Снег на виджетах рабочего стола", isOn: $p.widgetSnow)
            HStack {
                Text("Сила снегопада")
                Slider(value: $p.snowAmount, in: 0.15...1)
            }
            Toggle("Случайные порывы ветра", isOn: $p.gusts)
            HStack(spacing: 16) {
                WindCompass(angle: $p.windAngle, strength: $p.windStrength)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Потяни точку: направление и сила ветра.")
                    Text("В центре — штиль.").foregroundColor(.secondary)
                    Button("Штиль") { p.windStrength = 0 }
                }
            }
            Spacer()
        }
        .padding()
    }

    var treeTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Показывать ёлку", isOn: $p.treeOn)
            Picker("Высота", selection: $p.treeSize) {
                Text("Маленькая").tag(0)
                Text("Средняя").tag(1)
                Text("Большая").tag(2)
            }
            .pickerStyle(.segmented)
            Picker("Верхушка", selection: $p.topper) {
                Text("Звезда").tag("star")
                Text("Снежинка").tag("snowflake")
                Text("Бант").tag("bow")
            }
            .pickerStyle(.segmented)
            Toggle("Шары", isOn: $p.baubles)
            Toggle("Огоньки", isOn: $p.lights)
            Toggle("Колокольчики", isOn: $p.bells)
            Toggle("Пряничные человечки", isOn: $p.gingerbread)
            Button("🎲 Удиви меня") { p.surprise() }
            Spacer()
        }
        .padding()
    }

    var garlandTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Гирлянда", isOn: $p.garlandOn)
            Toggle("Вешать не только зимой", isOn: $p.garlandAllYear)
            Toggle("Загорается, только когда темно", isOn: $p.garlandAuto)
            Text("Гирлянда физическая: качается от ветра, если её задеть курсором и когда двигаешь окно.")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("Где висит", selection: $p.garlandMode) {
                Text("Вверху").tag(0)
                Text("По окнам").tag(1)
                Text("Свои точки").tag(2)
            }
            .pickerStyle(.segmented)
            Toggle("Тёплый белый свет", isOn: $p.garlandWarm)
            Toggle("Гирлянда поверх окон", isOn: $p.garlandOver)
            HStack {
                Text("Провис")
                Slider(value: $p.garlandSlack, in: 0...1)
            }
            if p.garlandMode == 2 {
                Toggle("Редактировать точки на экране (пока открыто это окно)", isOn: $p.editGarland)
                Text("Клик по пустому месту — новая точка, она соединится с выбранной. ⌥+клик — новая точка без соединения (новая гирлянда). Клик по точке выбирает её, клик по другой точке соединяет или разъединяет их. Перетаскивание двигает. Правый клик по точке удаляет её, правый клик по проводу удаляет отрезок. Точка на окне или виджете цепляется к нему и ездит вместе с ним (зелёная обводка).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Убрать все точки") { p.gJoints = []; p.gSegs = [] }
            }
            Spacer()
        }
        .padding()
    }

    var decorTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Набор у Dock", selection: $p.decorSet) {
                Text("Нет").tag(0)
                Text("Деревня").tag(1)
                Text("Ярмарка").tag(2)
                Text("Город").tag(3)
                Text("Подарки").tag(4)
            }
            Picker("Размер", selection: $p.decorSize) {
                Text("S").tag(0)
                Text("M").tag(1)
                Text("L").tag(2)
            }
            .pickerStyle(.segmented)
            if p.isAutumn { Toggle("Тыквы у домиков (ночью светятся)", isOn: $p.pumpkins) }
            if p.isSummer || p.isSpring { Toggle("Клумбы с цветами у домиков", isOn: $p.flowerBeds) }
            Text("Ночью в окнах домиков и фонарях загорается свет.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }

    var autumnTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Листья копятся на окнах", isOn: $p.windowSnow)
            Toggle("Листья на виджетах рабочего стола", isOn: $p.widgetSnow)
            HStack {
                Text("Сила листопада")
                Slider(value: $p.leafAmount, in: 0.15...1)
            }
            Toggle("Дождь", isOn: $p.rain)
            HStack {
                Text("Сила дождя")
                Slider(value: $p.rainAmount, in: 0.1...1)
            }
            .disabled(!p.rain)
            Toggle("Случайные порывы ветра", isOn: $p.gusts)
            HStack(spacing: 16) {
                WindCompass(angle: $p.windAngle, strength: $p.windStrength)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ветер срывает листья с кучи и кружит их.")
                    Text("Клик по куче листьев — пнуть, проведи мышкой — разворошить.").foregroundColor(.secondary)
                    Button("Штиль") { p.windStrength = 0 }
                }
            }
            Spacer()
        }
        .padding()
    }

    var springTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Лепестки вишни", isOn: $p.snowing)
            HStack {
                Text("Сколько лепестков")
                Slider(value: $p.petalAmount, in: 0.1...1)
            }
            .disabled(!p.snowing)
            HStack {
                Text("Скорость таяния снега")
                Slider(value: $p.meltSpeed, in: 0...1)
            }
            Button("❄️ Вернуть снег (снова начать таяние)") { p.act("respring") }
            Toggle("Птицы прилетают и садятся на окна", isOn: $p.birds)
            Toggle("Дождь", isOn: $p.rain)
            HStack {
                Text("Сила дождя")
                Slider(value: $p.rainAmount, in: 0.1...1)
            }
            .disabled(!p.rain)
            Toggle("Случайные порывы ветра", isOn: $p.gusts)
            HStack(spacing: 16) {
                WindCompass(angle: $p.windAngle, strength: $p.windStrength)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Снег тает днём быстрее, ночью медленнее. С окон капает, у Dock появляются лужи.")
                    Text("Клик по снегу или луже — брызги. Птицы пугаются курсора.").foregroundColor(.secondary)
                    Button("Штиль") { p.windStrength = 0 }
                }
            }
            Spacer()
        }
        .padding()
    }

    var summerTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Тополиный пух", isOn: $p.snowing)
            HStack {
                Text("Сколько пуха")
                Slider(value: $p.fluffAmount, in: 0.1...1)
            }
            .disabled(!p.snowing)
            Toggle("Бабочки днём", isOn: $p.butterflies)
            Toggle("Светлячки ночью", isOn: $p.fireflies)
            Toggle("Гроза с дождём и молниями", isOn: $p.rain)
            HStack {
                Text("Сила дождя")
                Slider(value: $p.rainAmount, in: 0.1...1)
            }
            .disabled(!p.rain)
            Toggle("Случайные порывы ветра", isOn: $p.gusts)
            HStack(spacing: 16) {
                WindCompass(angle: $p.windAngle, strength: $p.windStrength)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ветер качает траву и цветы у Dock.")
                    Text("Клик по траве — пух одуванчиков, бабочки боятся курсора. Проведи мышкой по траве — пузыри.").foregroundColor(.secondary)
                    Button("Штиль") { p.windStrength = 0 }
                }
            }
            Spacer()
        }
        .padding()
    }

    var mapleTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(p.isSpring ? "Показывать вишню" : (p.isSummer ? "Показывать яблоню" : "Показывать клён"), isOn: $p.treeOn)
            Picker("Высота", selection: $p.treeSize) {
                Text("Маленький").tag(0)
                Text("Средний").tag(1)
                Text("Большой").tag(2)
            }
            .pickerStyle(.segmented)
            Button("🎲 Другая крона") { p.treeSeed = Int.random(in: 1...100000) }
 Text(p.isSpring ? "Весной на месте ёлки — цветущая вишня, с неё летят лепестки." : p.isSummer ? "Летом на месте ёлки — яблоня с яблоками." : "С клёна понемногу облетают листья. Зимой на его месте снова будет ёлка.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }

    var aboutTab: some View {
        VStack(spacing: 14) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon).resizable().frame(width: 96, height: 96)
            }
            Text("SnowDesk").font(.largeTitle).bold()
            Text("Версия \(Prefs.appVersion)").foregroundColor(.secondary)
            Text("Живые времена года на рабочем столе Mac: снег и сугробы зимой, капель и цветущая вишня весной, бабочки и светлячки летом, листопад осенью — с персонажами, погодой и живыми обоями по реальному времени суток.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Divider().frame(maxWidth: 400)
            Text("Автор: \(Prefs.author)").font(.headline)
            Text("© 2026 \(Prefs.author). Программа бесплатная.")
            Text("Лицензия CC BY-NC 4.0: можно делиться и переделывать, указывая автора, но нельзя использовать в коммерческих целях.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            HStack(spacing: 20) {
                if let u = URL(string: Prefs.licenseURL) { Link("Текст лицензии", destination: u) }
                if !Prefs.githubURL.isEmpty, let u = URL(string: Prefs.githubURL) { Link("GitHub", destination: u) }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    var eventsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Случайные события", isOn: $p.eventsOn)
            Picker("Как часто", selection: $p.eventRate) {
                Text("Редко").tag(0)
                Text("Обычно").tag(1)
                Text("Часто").tag(2)
            }
            .pickerStyle(.segmented)
            Toggle("Прохожие", isOn: $p.people)
            Toggle(p.isSpring ? "Ребёнок с воздушным змеем" : p.isSummer ? "Дети пускают мыльные пузыри" : (p.isAutumn ? "Дети кидаются листьями" : "Дети играют в снежки"), isOn: $p.kids)
            Toggle("Собаки", isOn: $p.dogs)
            Toggle("Кошки", isOn: $p.cats)
            if p.season != .winter {
                Toggle("Прохожие с зонтами в дождь", isOn: $p.umbrellas)
            } else {
                Toggle("Йети-хулиган (ломает ёлку и снеговиков)", isOn: $p.yeti)
            }
            Spacer()
        }
        .padding()
    }
}
