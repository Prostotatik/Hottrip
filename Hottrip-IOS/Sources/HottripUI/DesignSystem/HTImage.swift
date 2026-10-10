import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Фото из Resources/Images (`<name>.jpg|png`), всегда `scaledToFill` в рамку, которую задаёт место применения.
/// Пока файла нет — атмосферная заглушка (spec-iter07 §6.2): небо, солнце, горы, вода и силуэт направления.
public struct HTImage: View {
    let name: String
    public init(_ name: String) { self.name = name }

    public var body: some View {
        if let image = Self.load(name) {
            Color.clear
                .overlay { image.resizable().scaledToFill() }
                .clipped()
        } else {
            HTPhotoPlaceholder(scene: .forAsset(name), seed: name.hashValueStable)
        }
    }

    /// Файл ассета по имени (без расширения); nil — файла нет, работает заглушка.
    static func load(_ name: String) -> Image? {
        for ext in ["jpg", "jpeg", "png"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Images") else { continue }
            #if canImport(UIKit)
            if let ui = UIImage(contentsOfFile: url.path) { return Image(uiImage: ui) }
            #elseif canImport(AppKit)
            if let ns = NSImage(contentsOf: url) { return Image(nsImage: ns) }
            #endif
        }
        return nil
    }
}

/// 3D-объект с прозрачным фоном (`home-star-3d`, `search-promo-3d`): файл вписывается `scaledToFit`,
/// без файла — хром, нарисованный кодом.
public struct HTObject3D: View {
    public enum Kind: String { case star = "home-star-3d", wave = "search-promo-3d" }
    let kind: Kind
    public init(_ kind: Kind) { self.kind = kind }

    public var body: some View {
        if let image = HTImage.load(kind.rawValue) {
            image.resizable().scaledToFit()
        } else {
            switch kind {
            case .star: HTChromeStar()
            case .wave: HTChromeWave()
            }
        }
    }
}

// MARK: - Сцена фото-заглушки

/// Сцена заглушки: атмосфера вместо предметов. Небо, свет, слои гор в дымке, вода или земля и один мягкий
/// силуэт на дальнем плане. Все объекты стоят у горизонта и выше: нижняя часть кадра (подписи, цены, бейджи)
/// остаётся спокойной заливкой, а левый верхний угол (чип скидки) — небом.
struct PhotoScene {
    enum Landmark {
        /// Мечеть вдали (Турция, Стамбул).
        case mosque
        /// Башни Дубая в дымке.
        case skyline
        /// Пирамиды в мареве.
        case pyramids
        /// Карстовые скалы в море (Пхукет).
        case karst
        /// Мыс с низкими тёплыми корпусами отеля (Анталья, бухта).
        case bay
        /// Полоса хвойного леса у горизонта (Белек).
        case forest
        /// Пляж: мягкая граница песка на переднем плане.
        case beach
        /// Инфинити-бассейн: вода бассейна сливается с горизонтом.
        case pool
    }

    var sky: [Color]
    var sun = UnitPoint(x: 0.72, y: 0.34)
    var sunColor = Color(hex: 0xFFF3C4)
    /// Горизонт — доля высоты.
    var horizon: CGFloat = 0.58
    var far = Color(hex: 0x5B7FA8)
    var near = Color(hex: 0x3F6690)
    /// Высоты вершин гор (доли высоты над горизонтом), слева направо; между ними плавные седловины.
    var peaks: [CGFloat] = [0.08, 0.16, 0.1, 0.2, 0.12, 0.07]
    /// Вода (с дорожкой солнца) или земля под горизонтом.
    var ground: [Color] = [Color(hex: 0x1F8FB8), Color(hex: 0x0E5C8A)]
    var water = true
    var landmark: Landmark? = nil
    var landmarkColor = Color(hex: 0x2D4A6B)
    var clouds = true
    /// Снег на вершинах дальней гряды.
    var snow = false

    typealias C = Color
    static let skyDay = [C(hex: 0x6FA9EC), C(hex: 0xB5D6F4), C(hex: 0xF1E6D2)]
    static let seaTurquoise = [C(hex: 0x3DB7C6), C(hex: 0x0E6A94)]
    static let poolWater = [C(hex: 0x6FDCE4), C(hex: 0x2C9FC0)]

    /// Сцена по имени ассета. У одного отеля обложка, миниатюра и галерея (`-cover` / `-thumb` / `-gallery`)
    /// рисуются одинаково, а первый кадр галереи t1 совпадает с обложкой — зум-переход не меняет картинку.
    static func forAsset(_ name: String) -> PhotoScene {
        // Миниатюра — та же сцена, что обложка тура: в избранном и на оплате видно направление.
        if name.hasSuffix("-thumb") { return forAsset(String(name.dropLast("-thumb".count)) + "-cover") }
        switch name {
        case "dest-turkey":
            return .init(sky: skyDay, sun: UnitPoint(x: 0.78, y: 0.3), horizon: 0.64, peaks: [0.04, 0.07, 0.05, 0.06],
                         ground: seaTurquoise, landmark: .mosque, landmarkColor: C(hex: 0x3A5478))
        case "dest-uae":
            return .init(sky: [C(hex: 0xE4865A), C(hex: 0xF0B584), C(hex: 0xF9E1C2)], sun: UnitPoint(x: 0.26, y: 0.56),
                         sunColor: C(hex: 0xFFE7B8), horizon: 0.68, far: C(hex: 0xC98A63), near: C(hex: 0xB0714F),
                         peaks: [0.015, 0.02, 0.015], ground: [C(hex: 0x3B5F86), C(hex: 0x1C3558)], landmark: .skyline,
                         landmarkColor: C(hex: 0x6A5670), clouds: false)
        case "dest-egypt":
            return .init(sky: [C(hex: 0x86BDEB), C(hex: 0xD3E6F0), C(hex: 0xF3DCB2)], sun: UnitPoint(x: 0.8, y: 0.24),
                         horizon: 0.68, far: C(hex: 0xD9B98C), near: C(hex: 0xCFA26C), peaks: [0.015, 0.025, 0.015],
                         ground: [C(hex: 0xE3B77E), C(hex: 0xC28A4E)], water: false, landmark: .pyramids,
                         landmarkColor: C(hex: 0xB9834E), clouds: false)
        case "dest-georgia":
            return .init(sky: [C(hex: 0x7FB2E6), C(hex: 0xC4DDF2), C(hex: 0xE8EFDD)], sun: UnitPoint(x: 0.3, y: 0.22),
                         horizon: 0.64, far: C(hex: 0x8AA2BF), near: C(hex: 0x5A7F6A), peaks: [0.2, 0.3, 0.24, 0.34, 0.22],
                         ground: [C(hex: 0x6E9468), C(hex: 0x33573D)], water: false, snow: true)
        case "dest-thailand":
            return .init(sky: [C(hex: 0x62A6EA), C(hex: 0xB4DAF2), C(hex: 0xF3ECD6)], sun: UnitPoint(x: 0.7, y: 0.26),
                         horizon: 0.62, near: C(hex: 0x3B7A5E), peaks: [0.02, 0.04, 0.02],
                         ground: [C(hex: 0x39C2C4), C(hex: 0x0D6C8E)], landmark: .karst, landmarkColor: C(hex: 0x2F6150))
        default: break
        }
        if name.hasPrefix("tour-t1-") {
            switch name.dropFirst("tour-t1-".count) {
            case "2":
                // Пляж отеля: светлый песок, лагуна, мягкие горы.
                return .init(sky: skyDay, sun: UnitPoint(x: 0.3, y: 0.24), horizon: 0.44, peaks: [0.06, 0.12, 0.09, 0.05],
                             ground: [C(hex: 0x58CBD0), C(hex: 0x1C8BAE)], landmark: .beach, landmarkColor: C(hex: 0xE9D3AE))
            case "3":
                // Вид из номера на море: золотой час, дорожка солнца.
                return .init(sky: [C(hex: 0x7C9CD6), C(hex: 0xE9B98E), C(hex: 0xF8DDB4)], sun: UnitPoint(x: 0.56, y: 0.36),
                             sunColor: C(hex: 0xFFE2A8), horizon: 0.46, far: C(hex: 0x8E8AAE), near: C(hex: 0x6C6C92),
                             peaks: [0.1, 0.05, 0, 0, 0.04, 0.09], ground: [C(hex: 0x4A7FA8), C(hex: 0x1D3F6C)], clouds: false)
            case "4":
                return .init(sky: skyDay, sun: UnitPoint(x: 0.25, y: 0.28), horizon: 0.46, peaks: [0.1, 0.07, 0.13],
                             ground: poolWater, landmark: .pool)
            default:
                // Обложка: бухта под Таврскими горами, на мысе справа низкие тёплые корпуса отеля.
                return .init(sky: skyDay, horizon: 0.42, peaks: [0.1, 0.18, 0.13, 0.21, 0.12, 0.08],
                             ground: seaTurquoise, landmark: .bay, landmarkColor: C(hex: 0x4C7556))
            }
        }
        if name.hasPrefix("tour-antalya-alt-1") {
            // Belek Pine: хвойный лес сплошной полосой у горизонта, над зоной бейджа ничего нет.
            return .init(sky: skyDay, sun: UnitPoint(x: 0.66, y: 0.22), horizon: 0.42, peaks: [0.03, 0.05, 0.04],
                         ground: seaTurquoise, landmark: .forest, landmarkColor: C(hex: 0x3E5F57))
        }
        if name.hasPrefix("tour-antalya-alt-2") {
            return .init(sky: skyDay, sun: UnitPoint(x: 0.2, y: 0.26), horizon: 0.44, peaks: [0.05, 0.09, 0.06],
                         ground: poolWater, landmark: .pool)
        }
        if name.hasPrefix("tour-antalya-alt-3") {
            return .init(sky: skyDay, horizon: 0.6, near: C(hex: 0x4A6E57), peaks: [0.24, 0.34, 0.28, 0.2], ground: seaTurquoise)
        }
        if name.hasPrefix("tour-t2-") {
            // Шарм-эш-Шейх: красные горы Синая в мареве и Красное море.
            return .init(sky: [C(hex: 0x86BDEB), C(hex: 0xD3E6F0), C(hex: 0xF3DCB2)], sun: UnitPoint(x: 0.78, y: 0.2),
                         horizon: 0.46, far: C(hex: 0xC99A78), near: C(hex: 0xA8694A), peaks: [0.1, 0.18, 0.12, 0.22, 0.14],
                         ground: [C(hex: 0x1FA6C8), C(hex: 0x0B4F86)], clouds: false)
        }
        if name.hasPrefix("tour-t3-") { return forAsset("dest-uae") }
        if name.hasPrefix("tour-t4-") { return forAsset("dest-turkey") }
        if name.hasPrefix("tour-t5-") { return forAsset("dest-thailand") }
        if name.hasPrefix("tour-t6-") { return forAsset("dest-georgia") }
        return .init(sky: skyDay)
    }
}

/// Атмосферная заглушка фото, нарисованная одним Canvas (статична — скриншоты стабильны).
struct HTPhotoPlaceholder: View {
    let scene: PhotoScene
    let seed: UInt32

    var body: some View {
        Canvas { ctx, size in
            Self.draw(scene, in: CGRect(origin: .zero, size: size), ctx: &ctx, seed: seed)
        }
        .accessibilityHidden(true)
    }

    static func draw(_ s: PhotoScene, in r: CGRect, ctx: inout GraphicsContext, seed: UInt32) {
        let w = r.width, h = r.height
        let hy = r.minY + h * s.horizon
        let haze = s.sky.last ?? .white
        let unit = max(w, h)

        // Небо и солнце: широкое мягкое свечение + светлое ядро.
        ctx.fill(Path(r), with: .linearGradient(Gradient(colors: s.sky), startPoint: CGPoint(x: r.midX, y: r.minY),
                                                 endPoint: CGPoint(x: r.midX, y: hy)))
        let sun = CGPoint(x: r.minX + w * s.sun.x, y: r.minY + h * s.sun.y)
        glow(at: sun, radius: unit * 0.55, color: s.sunColor, opacity: 0.75, ctx: &ctx)
        glow(at: sun, radius: unit * 0.09, color: .white, opacity: 0.8, ctx: &ctx)
        if s.clouds { clouds(in: r, above: hy, seed: seed, ctx: &ctx) }

        // Дальняя гряда → дымка → ближняя гряда → дымка: воздушная перспектива вместо контуров.
        let farPath = ridge(s.peaks, base: hy, in: r, seed: seed, detail: 0.06)
        ctx.fill(farPath, with: .color(s.far.opacity(0.75)))
        if s.snow {
            // Снег от самой высокой вершины (с запасом на рельеф `detail`) до середины высоты гряды:
            // шапки получают все заметные вершины, а не одна.
            let peak = h * (s.peaks.max() ?? 0)
            let top = hy - peak * 1.1, depth = peak * 0.6
            ctx.drawLayer { layer in
                layer.clip(to: farPath)
                layer.fill(Path(CGRect(x: r.minX, y: top, width: w, height: depth)),
                           with: .linearGradient(Gradient(colors: [.white.opacity(0.9), .white.opacity(0)]),
                                                 startPoint: CGPoint(x: r.midX, y: top),
                                                 endPoint: CGPoint(x: r.midX, y: top + depth)))
            }
        }
        hazeBand(base: hy, height: h * 0.2, color: haze, opacity: 0.55, in: r, ctx: &ctx)
        if let l = s.landmark, [.mosque, .skyline, .pyramids].contains(l) {
            // Силуэт дальнего плана — до второй дымки, чтобы он в ней растворялся.
            drawLandmark(l, s: s, base: hy, in: r, ctx: &ctx)
            hazeBand(base: hy, height: h * 0.12, color: haze, opacity: 0.35, in: r, ctx: &ctx)
        }
        let near = ridge(s.peaks.reversed().map { $0 * 0.55 }, base: hy, in: r, seed: seed &+ 17, detail: 0.08, shift: 0.18)
        ctx.fill(near, with: .color(s.near.opacity(0.8)))
        hazeBand(base: hy, height: h * 0.06, color: haze, opacity: 0.4, in: r, ctx: &ctx)
        if let l = s.landmark, [.karst, .bay, .forest].contains(l) {
            drawLandmark(l, s: s, base: hy, in: r, ctx: &ctx)
        }

        // Вода / земля: спокойный градиент, у горизонта светлая кромка, от солнца мягкая дорожка.
        let below = CGRect(x: r.minX, y: hy, width: w, height: r.maxY - hy)
        ctx.fill(Path(below), with: .linearGradient(Gradient(colors: s.ground), startPoint: CGPoint(x: r.midX, y: hy),
                                                     endPoint: CGPoint(x: r.midX, y: r.maxY)))
        ctx.fill(Path(CGRect(x: r.minX, y: hy, width: w, height: below.height * 0.18)),
                 with: .linearGradient(Gradient(colors: [haze.opacity(s.water ? 0.45 : 0.35), haze.opacity(0)]),
                                       startPoint: CGPoint(x: r.midX, y: hy),
                                       endPoint: CGPoint(x: r.midX, y: hy + below.height * 0.18)))
        if s.water {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: max(2, w * 0.02)))
                let pathW = w * 0.2, pathH = below.height * 0.5
                layer.fill(Path(ellipseIn: CGRect(x: sun.x - pathW / 2, y: hy - pathH * 0.1, width: pathW, height: pathH)),
                           with: .linearGradient(Gradient(colors: [s.sunColor.opacity(0.55), s.sunColor.opacity(0)]),
                                                 startPoint: CGPoint(x: sun.x, y: hy), endPoint: CGPoint(x: sun.x, y: hy + pathH)))
            }
        }
        if let l = s.landmark, [.beach, .pool].contains(l) {
            drawLandmark(l, s: s, base: hy, in: r, ctx: &ctx)
        }
        grain(in: r, seed: seed, ctx: &ctx)
    }

    private static func glow(at c: CGPoint, radius: CGFloat, color: Color, opacity: Double, ctx: inout GraphicsContext) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                 with: .radialGradient(Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
                                       center: c, startRadius: 0, endRadius: radius))
    }

    /// Два-три размытых облака в верхней трети неба.
    private static func clouds(in r: CGRect, above hy: CGFloat, seed: UInt32, ctx: inout GraphicsContext) {
        var rng = LCG(seed: seed &+ 5)
        let w = r.width, skyH = hy - r.minY
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: max(4, w * 0.035)))
            for i in 0..<3 {
                let cw = w * (0.32 + CGFloat(rng.next() % 20) / 100)
                let x = r.minX + w * (CGFloat(i) * 0.36 - 0.1 + CGFloat(rng.next() % 12) / 100)
                let y = r.minY + skyH * (0.14 + CGFloat(rng.next() % 26) / 100)
                layer.fill(Path(ellipseIn: CGRect(x: x, y: y, width: cw, height: cw * 0.16)), with: .color(.white.opacity(0.5)))
            }
        }
    }

    /// Дымка над горизонтом: цвет низа неба, от горизонта вверх в прозрачность.
    private static func hazeBand(base: CGFloat, height: CGFloat, color: Color, opacity: Double, in r: CGRect,
                                 ctx: inout GraphicsContext) {
        ctx.fill(Path(CGRect(x: r.minX, y: base - height, width: r.width, height: height + 0.5)),
                 with: .linearGradient(Gradient(colors: [color.opacity(0), color.opacity(opacity)]),
                                       startPoint: CGPoint(x: r.midX, y: base - height), endPoint: CGPoint(x: r.midX, y: base)))
    }

    /// Гряда гор плавной линией: вершины `peaks`, седловины между ними, мелкий детерминированный рельеф.
    private static func ridge(_ peaks: [CGFloat], base: CGFloat, in r: CGRect, seed: UInt32, detail: CGFloat,
                              shift: CGFloat = 0) -> Path {
        var p = Path()
        guard !peaks.isEmpty else { return p }
        // Опорные точки: вершина, седловина, вершина…
        var xs: [CGFloat] = [-0.05], ys: [CGFloat] = [peaks[0] * 0.4]
        let step = 1 / CGFloat(peaks.count)
        for (i, peak) in peaks.enumerated() {
            xs.append(step * (CGFloat(i) + 0.5 + shift)); ys.append(peak)
            xs.append(step * (CGFloat(i) + 1 + shift)); ys.append(peak * 0.42)
        }
        xs.append(1.2); ys.append(ys.last ?? 0)
        var rng = LCG(seed: seed)
        let phase1 = CGFloat(rng.next() % 628) / 100, phase2 = CGFloat(rng.next() % 628) / 100
        p.move(to: CGPoint(x: r.minX, y: base + 1))
        let samples = max(24, Int(r.width / 3))
        var k = 0
        for n in 0...samples {
            let t = CGFloat(n) / CGFloat(samples)
            while k < xs.count - 2 && t > xs[k + 1] { k += 1 }
            let span = max(0.0001, xs[k + 1] - xs[k])
            let u = min(1, max(0, (t - xs[k]) / span))
            // Вогнутые склоны: пологие седловины и заострённые вершины (а не «волны» smoothstep).
            let rising = ys[k + 1] > ys[k]
            let e = rising ? pow(u, 1.35) : 1 - pow(1 - u, 1.35)
            var height = ys[k] + (ys[k + 1] - ys[k]) * e
            height *= 1 + detail * (0.7 * sin(t * 23 + phase1) + 0.3 * sin(t * 61 + phase2))
            p.addLine(to: CGPoint(x: r.minX + r.width * t, y: base - r.height * max(0, height)))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: base + 1))
        p.closeSubpath()
        return p
    }

    private static func drawLandmark(_ l: PhotoScene.Landmark, s: PhotoScene, base: CGFloat, in r: CGRect,
                                     ctx: inout GraphicsContext) {
        let w = r.width, h = r.height
        let skyH = base - r.minY
        let color = s.landmarkColor
        switch l {
        case .mosque:
            // Дальний план: ≈ половина ширины кадра, правее центра; левый верхний угол (чип скидки) свободен.
            let u = min(w * (w < h ? 0.66 : 0.46), skyH * 1.05)
            let cx = r.minX + w * 0.6, b = base + 1
            var p = Path()
            p.addRect(CGRect(x: cx - u * 0.36, y: b - u * 0.09, width: u * 0.72, height: u * 0.09))
            p.addEllipse(in: CGRect(x: cx - u * 0.19, y: b - u * 0.09 - u * 0.17, width: u * 0.38, height: u * 0.34))
            for dx in [-0.24, 0.24] as [CGFloat] {
                p.addEllipse(in: CGRect(x: cx + u * dx - u * 0.09, y: b - u * 0.09 - u * 0.08, width: u * 0.18, height: u * 0.16))
            }
            for (dx, t) in [(-0.44, 0.5), (-0.32, 0.56), (0.32, 0.56), (0.44, 0.5)] as [(CGFloat, CGFloat)] {
                let mw = u * 0.028, x = cx + u * dx, top = b - u * t
                p.addRect(CGRect(x: x - mw / 2, y: top, width: mw, height: b - top))
                p.move(to: CGPoint(x: x - mw / 2, y: top)); p.addLine(to: CGPoint(x: x, y: top - u * 0.06))
                p.addLine(to: CGPoint(x: x + mw / 2, y: top)); p.closeSubpath()
            }
            ctx.fill(p, with: .color(color.opacity(0.6)))
        case .skyline:
            // Башни в дымке: ниже и светлее к краям, в центре — самая высокая.
            let u = min(w * 0.72, skyH * 1.1)
            let cx = r.minX + w * 0.56
            var towers = Path()
            let spec: [(CGFloat, CGFloat, CGFloat)] = [(-0.42, 0.1, 0.24), (-0.3, 0.09, 0.34), (-0.19, 0.1, 0.28),
                                                        (0.14, 0.1, 0.36), (0.25, 0.09, 0.26), (0.36, 0.11, 0.3)]
            for (dx, bw, t) in spec {
                towers.addRect(CGRect(x: cx + u * dx - u * bw / 2, y: base - u * t, width: u * bw, height: u * t + 1))
            }
            ctx.fill(towers, with: .color(color.opacity(0.45)))
            var spire = Path()
            spire.move(to: CGPoint(x: cx - u * 0.07, y: base + 1))
            spire.addLine(to: CGPoint(x: cx - u * 0.035, y: base - u * 0.42))
            spire.addLine(to: CGPoint(x: cx - u * 0.012, y: base - u * 0.62))
            spire.addLine(to: CGPoint(x: cx, y: base - u * 0.8))
            spire.addLine(to: CGPoint(x: cx + u * 0.012, y: base - u * 0.62))
            spire.addLine(to: CGPoint(x: cx + u * 0.035, y: base - u * 0.42))
            spire.addLine(to: CGPoint(x: cx + u * 0.07, y: base + 1))
            spire.closeSubpath()
            ctx.fill(spire, with: .color(color.opacity(0.62)))
        case .pyramids:
            // Две пирамиды в мареве справа от центра: освещённая грань и теневая.
            let u = min(w * 0.7, skyH * 1.2)
            for (dx, sz, a) in [(0.1, 0.5, 0.8), (-0.26, 0.32, 0.6)] as [(CGFloat, CGFloat, Double)] {
                let cx = r.minX + w * 0.58 + u * dx, half = u * sz * 0.5
                let top = CGPoint(x: cx, y: base - u * sz * 0.6)
                var lit = Path(), shade = Path()
                lit.move(to: top); lit.addLine(to: CGPoint(x: cx - half, y: base + 1)); lit.addLine(to: CGPoint(x: cx + half * 0.25, y: base + 1))
                shade.move(to: top); shade.addLine(to: CGPoint(x: cx + half * 0.25, y: base + 1)); shade.addLine(to: CGPoint(x: cx + half, y: base + 1))
                ctx.fill(lit, with: .color(color.opacity(a * 0.75)))
                ctx.fill(shade, with: .color(color.opacity(a)))
                ctx.fill(shade, with: .color(.black.opacity(0.1 * a)))
            }
        case .karst:
            // Скалы-останцы в море: две мягкие «капли» у горизонта в дымке, без деталей.
            let u = min(skyH * 0.5, w * 0.4)
            for (x, sz, a) in [(0.26, 1.0, 0.72), (0.74, 0.7, 0.55), (0.9, 0.42, 0.45)] as [(CGFloat, CGFloat, Double)] {
                let cx = r.minX + w * x, rw = u * 0.5 * sz, rh = u * sz
                var rock = Path()
                rock.move(to: CGPoint(x: cx - rw, y: base + 1))
                rock.addCurve(to: CGPoint(x: cx - rw * 0.1, y: base - rh),
                              control1: CGPoint(x: cx - rw * 0.9, y: base - rh * 0.55),
                              control2: CGPoint(x: cx - rw * 0.75, y: base - rh * 1.02))
                rock.addCurve(to: CGPoint(x: cx + rw, y: base + 1),
                              control1: CGPoint(x: cx + rw * 0.55, y: base - rh * 0.98),
                              control2: CGPoint(x: cx + rw * 1.05, y: base - rh * 0.45))
                rock.closeSubpath()
                ctx.fill(rock, with: .linearGradient(Gradient(colors: [color.opacity(a), color.opacity(a * 0.75)]),
                                                     startPoint: CGPoint(x: cx - rw, y: base - rh),
                                                     endPoint: CGPoint(x: cx + rw, y: base)))
            }
            hazeBand(base: base, height: u * 0.35, color: s.sky.last ?? .white, opacity: 0.35, in: r, ctx: &ctx)
        case .bay:
            // Мыс справа, у горизонта, и на нём низкие тёплые корпуса без полос — тёплые объёмы, а не «конверты».
            let bh = h * 0.05
            var cape = Path()
            cape.move(to: CGPoint(x: r.minX + w * 0.5, y: base + 1))
            cape.addCurve(to: CGPoint(x: r.maxX, y: base - bh),
                          control1: CGPoint(x: r.minX + w * 0.66, y: base - bh * 0.2),
                          control2: CGPoint(x: r.minX + w * 0.8, y: base - bh * 1.1))
            cape.addLine(to: CGPoint(x: r.maxX, y: base + h * 0.012))
            cape.closeSubpath()
            ctx.fill(cape, with: .color(color.opacity(0.85)))
            let blocks: [(CGFloat, CGFloat, CGFloat)] = [(0.66, 0.05, 0.02), (0.73, 0.06, 0.028), (0.81, 0.045, 0.024),
                                                         (0.88, 0.06, 0.032)]
            for (x, bw, bh2) in blocks {
                let t = (x - 0.5) / 0.5
                let ground = base - bh * min(1, t * 1.05) + h * 0.004
                let face = CGRect(x: r.minX + w * x, y: ground - h * bh2, width: w * bw, height: h * bh2)
                ctx.fill(Path(face), with: .color(Color(hex: 0xEDE3D3).opacity(0.92)))
                ctx.fill(Path(CGRect(x: face.maxX - face.width * 0.28, y: face.minY, width: face.width * 0.28, height: face.height)),
                         with: .color(Color(hex: 0xD9CBB5).opacity(0.95)))
            }
            hazeBand(base: base, height: bh * 1.6, color: s.sky.last ?? .white, opacity: 0.3, in: r, ctx: &ctx)
        case .forest:
            // Сплошная зубчатая полоса хвои у горизонта, высота ≤ 8 % кадра.
            var rng = LCG(seed: 91)
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: base + 1))
            // Кроны разной ширины и высоты: равный шаг читался как гребёнка.
            var x = r.minX
            while x < r.maxX {
                let tree = w * (0.014 + CGFloat(rng.next() % 16) / 1000)
                let t = h * (0.03 + CGFloat(rng.next() % 45) / 1000)
                let wobble = h * 0.012 * sin((x - r.minX) / w * 5)
                p.addLine(to: CGPoint(x: x + tree * 0.5, y: base - t - wobble))
                p.addLine(to: CGPoint(x: x + tree, y: base - h * (0.016 + CGFloat(rng.next() % 10) / 1000) - wobble))
                x += tree
            }
            p.addLine(to: CGPoint(x: r.maxX, y: base + 1))
            p.closeSubpath()
            // Лёгкое размытие: лес на дальнем берегу, а не гребёнка переднего плана.
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: max(1, w * 0.003)))
                layer.fill(p, with: .color(color.opacity(0.8)))
            }
            hazeBand(base: base, height: h * 0.03, color: s.sky.last ?? .white, opacity: 0.25, in: r, ctx: &ctx)
        case .beach:
            // Песок снизу с размытой кромкой прибоя — без линий и предметов.
            let edge = base + (r.maxY - base) * 0.42
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: max(3, w * 0.025)))
                var sand = Path()
                sand.move(to: CGPoint(x: r.minX - 20, y: edge + h * 0.05))
                sand.addCurve(to: CGPoint(x: r.maxX + 20, y: edge - h * 0.04),
                              control1: CGPoint(x: r.minX + w * 0.35, y: edge - h * 0.02),
                              control2: CGPoint(x: r.minX + w * 0.65, y: edge + h * 0.03))
                sand.addLine(to: CGPoint(x: r.maxX + 20, y: r.maxY + 20))
                sand.addLine(to: CGPoint(x: r.minX - 20, y: r.maxY + 20))
                sand.closeSubpath()
                layer.fill(sand, with: .linearGradient(Gradient(colors: [color, Color(hex: 0xC9A778)]),
                                                       startPoint: CGPoint(x: r.midX, y: edge), endPoint: CGPoint(x: r.midX, y: r.maxY)))
            }
        case .pool:
            // Инфинити-бассейн: едва заметная кромка по горизонту (вода бассейна сливается с морем),
            // ниже — светлая вода с мягкими бликами.
            ctx.fill(Path(CGRect(x: r.minX, y: base - 0.5, width: w, height: max(1, h * 0.004))),
                     with: .color(.white.opacity(0.3)))
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: max(3, w * 0.03)))
                var rng = LCG(seed: 33)
                for i in 0..<4 {
                    let y = base + (r.maxY - base) * (0.18 + 0.2 * CGFloat(i))
                    let x = r.minX + w * CGFloat(rng.next() % 60) / 100
                    layer.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w * 0.4, height: h * 0.025)),
                               with: .color(.white.opacity(0.16)))
                }
            }
        }
    }

    /// Плёночное зерно (светлые точки 4 %, тёмные 3 %): детерминированные, одинаковые между запусками.
    static func grain(in r: CGRect, seed: UInt32, ctx: inout GraphicsContext) {
        var rng = LCG(seed: seed)
        let count = Int(r.width * r.height / 90)
        for _ in 0..<count {
            let x = r.minX + CGFloat(rng.next() % 10_000) / 10_000 * r.width
            let y = r.minY + CGFloat(rng.next() % 10_000) / 10_000 * r.height
            let light = rng.next() % 2 == 0
            ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(light ? .white.opacity(0.04) : .black.opacity(0.03)))
        }
    }
}

/// Детерминированный генератор для заглушек (рельеф, облака, лес, зерно).
struct LCG {
    var state: UInt32
    init(seed: UInt32) { state = seed | 1 }
    mutating func next() -> UInt32 {
        state = state &* 1_664_525 &+ 1_013_904_223
        return state >> 16
    }
}

extension String {
    /// Стабильный между запусками хэш (String.hashValue рандомизирован).
    var hashValueStable: UInt32 {
        var h: UInt32 = 2166136261
        for b in utf8 { h = (h ^ UInt32(b)) &* 16777619 }
        return h
    }
}
