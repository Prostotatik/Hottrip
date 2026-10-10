import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Хром-3D, пока нет PNG (spec-iter07 §6.2 п.4)

/// Четырёхлучевая звезда с вогнутыми сторонами: 8 граней, освещённых слева сверху, хромовые отражения,
/// блик в верхней левой лопасти и тень. Заполняет предложенную рамку.
struct HTChromeStar: View {
    private static let chrome = [Color(hex: 0xF4F7FF), Color(hex: 0x9AA8C7), Color(hex: 0xFFFFFF),
                                 Color(hex: 0x5C6C93), Color(hex: 0xE8EEFF), Color(hex: 0xF4F7FF)]

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                StarFacet(index: i).fill(Self.facetFill(i))
            }
            StarOutline()
                .fill(AngularGradient(colors: Self.chrome, center: .center, angle: .degrees(20)))
                .blendMode(.overlay)
                .opacity(0.55)
            StarOutline().stroke(Color.white.opacity(0.7), lineWidth: 1)
            GeometryReader { g in
                Ellipse()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: g.size.width * 0.05, height: g.size.height * 0.16)
                    .blur(radius: 4)
                    .position(x: g.size.width * 0.47, y: g.size.height * 0.26)
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 9, x: 0, y: 12)
        .rotation3DEffect(.degrees(12), axis: (x: 1, y: -0.5, z: 0), perspective: 0.5)
        .rotationEffect(.degrees(-16))
        .accessibilityHidden(true)
    }

    /// Грань i: лопасть i / 2, сторона i % 2. Яркость — по направлению грани к свету (слева сверху).
    private static func facetFill(_ i: Int) -> LinearGradient {
        let normal = StarFacet.bisector(i)
        let light = -135.0 * Double.pi / 180
        let b = (cos(normal - light) + 1) / 2
        // Хром: светлый край, тёмная полоса отражения посередине грани, яркое ребро к центру.
        let edge = Color(hex: 0x34436B).mix(with: Color(hex: 0xF4F7FF), by: b)
        let band = Color(hex: 0x1E2A4A).mix(with: Color(hex: 0x9AA8C7), by: b)
        let ridge = Color(hex: 0x9AA8C7).mix(with: .white, by: min(1, b + 0.4))
        let tip = StarFacet.point(angle: StarFacet.tipAngle(i / 2), radius: 0.5)
        return LinearGradient(stops: [.init(color: edge, location: 0), .init(color: band, location: 0.45),
                                      .init(color: ridge, location: 1)],
                              startPoint: UnitPoint(x: tip.x, y: tip.y), endPoint: .center)
    }
}

private struct StarFacet: Shape {
    let index: Int

    static let valleyRadius: CGFloat = 0.2
    static func tipAngle(_ lobe: Int) -> Double { (-90 + 90 * Double(lobe)) * .pi / 180 }
    static func valleyAngle(_ i: Int) -> Double { tipAngle(i / 2) + (i % 2 == 0 ? -1 : 1) * .pi / 4 }
    static func bisector(_ i: Int) -> Double { (tipAngle(i / 2) + valleyAngle(i)) / 2 }
    /// Точка в единичной рамке (0…1) по углу и радиусу от центра.
    static func point(angle: Double, radius: CGFloat) -> CGPoint {
        CGPoint(x: 0.5 + radius * CGFloat(cos(angle)), y: 0.5 + radius * CGFloat(sin(angle)))
    }

    func path(in rect: CGRect) -> Path {
        func scaled(_ p: CGPoint) -> CGPoint { CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height) }
        let tip = Self.point(angle: Self.tipAngle(index / 2), radius: 0.5)
        let valley = Self.point(angle: Self.valleyAngle(index), radius: Self.valleyRadius)
        let control = Self.point(angle: Self.bisector(index), radius: 0.24)
        var p = Path()
        p.move(to: scaled(CGPoint(x: 0.5, y: 0.5)))
        p.addLine(to: scaled(tip))
        p.addQuadCurve(to: scaled(valley), control: scaled(control))
        p.closeSubpath()
        return p
    }
}

private struct StarOutline: Shape {
    func path(in rect: CGRect) -> Path {
        (0..<8).reduce(into: Path()) { $0.addPath(StarFacet(index: $1).path(in: rect)) }
    }
}

/// Хромовая волна промо-баннера: одна изогнутая лента-трубка (тёмная кромка снизу, блик сверху), без отдельных деталей.
/// Над баннером выступает только верхний конец ленты (`promoOverhang`).
struct HTChromeWave: View {
    private static let chrome = Gradient(stops: [
        .init(color: Color(hex: 0xF4F7FF), location: 0), .init(color: Color(hex: 0xB9C6E2), location: 0.3),
        .init(color: Color(hex: 0xFFFFFF), location: 0.5), .init(color: Color(hex: 0x7C8DB5), location: 0.72),
        .init(color: Color(hex: 0xC9F5E4), location: 1)])

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let tube = w * 0.19
            let ribbon = Path { p in
                p.move(to: CGPoint(x: w * 0.2, y: h * 0.98))
                p.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.46), control1: CGPoint(x: w * 0.52, y: h * 0.98),
                           control2: CGPoint(x: w * 0.34, y: h * 0.54))
                p.addCurve(to: CGPoint(x: w * 0.84, y: tube * 0.5 + 2), control1: CGPoint(x: w * 0.84, y: h * 0.38),
                           control2: CGPoint(x: w * 0.96, y: h * 0.18))
            }
            ZStack {
                ribbon.stroke(LinearGradient(gradient: Self.chrome, startPoint: .topLeading, endPoint: .bottomTrailing),
                              style: StrokeStyle(lineWidth: tube, lineCap: .round))
                // Тёмная кромка снизу-справа и блик сверху-слева — объём трубки.
                ribbon.stroke(Color(hex: 0x2E3F6B).opacity(0.4), style: StrokeStyle(lineWidth: tube * 0.3, lineCap: .round))
                    .offset(x: tube * 0.3, y: tube * 0.32)
                    .blur(radius: 3)
                ribbon.stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: tube * 0.14, lineCap: .round))
                    .offset(x: -tube * 0.22, y: -tube * 0.22)
                    .blur(radius: 1.2)
            }
            .mask(ribbon.stroke(style: StrokeStyle(lineWidth: tube, lineCap: .round)))
            .compositingGroup()
            .shadow(color: Color(hex: 0x0B1633).opacity(0.22), radius: 10, x: 0, y: 10)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Главная: фото-слот без файла (spec-iter07 §6.2 п.5)

/// Небо, облака, иллюминатор (рама r 120, обводка 22) с видом на горы и море и крылом справа.
/// Как на референсе, иллюминатор почти во весь экран: рама x −4…406, y 96…552 на экране 402 × 874 (те же доли
/// на любом экране), боковые края рамы у кромок экрана, верх растворяется в небе. Текст hero лежит на «стекле»,
/// а не пересекает серебристую раму.
struct HTHomeHeroPlaceholder: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let frame = CGRect(x: w * -4 / 402, y: h * 96 / 874, width: w * 410 / 402, height: h * 456 / 874)
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(hex: 0x2F6FD6), Color(hex: 0x5B9BEA), Color(hex: 0x9CC8F5)],
                               startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.7))
                clouds(w: w, h: h)
                window(frame.size)
                    .offset(x: frame.minX, y: frame.minY)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private func clouds(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array([(0.62, 0.17, 0.5), (0.1, 0.26, 0.4), (0.75, 0.3, 0.34)].enumerated()), id: \.offset) { _, c in
                Ellipse()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: w * c.2, height: w * c.2 * 0.28)
                    .blur(radius: 14)
                    .offset(x: w * c.0 - w * c.2 / 2, y: h * c.1)
            }
        }
    }

    private func window(_ size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 120, style: .continuous)
        return ZStack {
            Canvas { ctx, s in
                let r = CGRect(origin: .zero, size: s)
                HTPhotoPlaceholder.draw(Self.view, in: r, ctx: &ctx, seed: 7)
            }
            .clipShape(shape)
            shape.strokeBorder(LinearGradient(colors: [Color(hex: 0xE9EEF6), Color(hex: 0x9FB0C8)], startPoint: .topLeading,
                                              endPoint: .bottomTrailing), lineWidth: 22)
            shape.inset(by: 21).strokeBorder(Color(hex: 0x0B1633).opacity(0.22), lineWidth: 2)
        }
        .frame(width: size.width, height: size.height)
        // Верх иллюминатора (скругления рамы) растворяется в небе до уровня теглайна.
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.4),
                                     .init(color: .black, location: 0.64)], startPoint: .top, endPoint: .bottom))
        // Крыло поверх растворения — справа от текста, поэтому остаётся плотным.
        .overlay {
            Canvas { ctx, s in
                // Крыло в правой части иллюминатора, под зоной текста: верхняя плоскость и тёмная кромка снизу.
                var wing = Path()
                wing.move(to: CGPoint(x: s.width * 1.02, y: s.height * 0.654))
                wing.addLine(to: CGPoint(x: s.width * 0.622, y: s.height * 0.487))
                wing.addLine(to: CGPoint(x: s.width * 0.681, y: s.height * 0.473))
                wing.addLine(to: CGPoint(x: s.width * 1.02, y: s.height * 0.557))
                wing.closeSubpath()
                ctx.fill(wing, with: .linearGradient(Gradient(colors: [.white, Color(hex: 0xC9D6EA)]),
                                                     startPoint: CGPoint(x: s.width, y: s.height * 0.515),
                                                     endPoint: CGPoint(x: s.width * 0.622, y: s.height * 0.654)))
                var edge = Path()
                edge.move(to: CGPoint(x: s.width * 0.622, y: s.height * 0.487))
                edge.addLine(to: CGPoint(x: s.width * 1.02, y: s.height * 0.654))
                ctx.stroke(edge, with: .color(Color(hex: 0x5B6F8F)), lineWidth: 3)
            }
            .clipShape(shape.inset(by: 22))
        }
        .shadow(color: Color(hex: 0x0A1A45).opacity(0.35), radius: 16, x: 0, y: 10)
    }

    /// Вид из иллюминатора: светлое небо, горы у горизонта и море внизу.
    private static let view = PhotoScene(
        sky: [Color(hex: 0x4F8FE0), Color(hex: 0x8DBDF0), Color(hex: 0xDCE8F2)],
        sun: UnitPoint(x: 0.85, y: 0.69), sunColor: Color(hex: 0xFFF6DA), horizon: 0.72,
        far: Color(hex: 0x6F8CB5), near: Color(hex: 0x4F6F98), peaks: [0.07, 0.14, 0.1, 0.17, 0.08, 0.055],
        ground: [Color(hex: 0x2D8FC4), Color(hex: 0x0F4C86)], clouds: false)
}

// MARK: - Бренды (код, spec-iter07 §4.2, §6.1)

/// Плитка способа оплаты 56 × 56: фирменный градиент и белый знак. Если в Resources появится
/// `pay-<kind>.png`, показывается файл.
struct HTBrandTile: View {
    let kind: PaymentMethod.Kind

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HTRadius.tile, style: .continuous)
        Group {
            if let image = HTImage.load("pay-\(kind == .card ? "humo-uzcard" : kind.rawValue)") {
                image.resizable().scaledToFill()
            } else {
                shape.fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { glyph.foregroundStyle(.white) }
            }
        }
        .frame(width: HTSize.brandTile, height: HTSize.brandTile)
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private var colors: [Color] {
        switch kind {
        case .payme: HTColor.Brand.payme
        case .click: HTColor.Brand.click
        case .uzum: HTColor.Brand.uzum
        case .card: HTColor.Brand.humo
        case .installment: HTColor.Brand.installment
        }
    }

    @ViewBuilder private var glyph: some View {
        switch kind {
        case .payme: Text("Pay").font(.system(size: 20, weight: .bold, design: .rounded))
        case .click: Text("Click").font(.system(size: 16, weight: .bold, design: .rounded))
        case .uzum: Image(systemName: "power").font(.system(size: 26, weight: .bold))
        case .card:
            Text("H").font(.system(size: 26, weight: .black))
                .overlay(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 1.5).fill(HTColor.Brand.humoStripe)
                        .frame(width: 3, height: 12).offset(x: 7)
                }
        case .installment: Image(systemName: "creditcard").font(.system(size: 22, weight: .semibold))
        }
    }
}

/// Лого туроператора 36 × 36: белый круг с обводкой и цветная монограмма. Файл `op-<id>.png` имеет приоритет.
struct HTOperatorLogo: View {
    let tourOperator: TourOperator

    var body: some View {
        Group {
            if let image = HTImage.load("op-\(tourOperator.id)") {
                image.resizable().scaledToFit()
            } else {
                Circle().fill(HTColor.surface)
                    .overlay(Circle().strokeBorder(HTColor.line, lineWidth: HTSize.hairline))
                    .overlay { mark }
            }
        }
        .frame(width: HTSize.operatorLogo, height: HTSize.operatorLogo)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var mark: some View {
        switch tourOperator.id {
        case "anex": Text("anex").font(.system(size: 10, weight: .black)).italic().foregroundStyle(HTColor.Brand.anex)
        case "coral":
            Circle()
                .fill(LinearGradient(colors: HTColor.Brand.coral, startPoint: .top, endPoint: .bottom))
                .frame(width: 18, height: 18)
                .overlay(Capsule().fill(.white.opacity(0.85)).frame(width: 18, height: 2.5).offset(y: 1))
        default: Text("PEGAS").font(.system(size: 8, weight: .black)).foregroundStyle(HTColor.Brand.pegas)
        }
    }
}

// MARK: - Мелкие знаки

/// Иконка «стопка из трёх монет» 20 × 20, обводка 1,6 (поле «Бюджет»).
struct HTCoinsIcon: View {
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, coin = s.height * 0.26
            // Монета позади стопки, затем три «ребра» стопки снизу вверх; каждое закрашено белым, чтобы перекрыть заднее.
            ctx.stroke(Path(ellipseIn: CGRect(x: w * 0.5, y: 1.5, width: w * 0.45, height: w * 0.45)),
                       with: .color(HTColor.ink), lineWidth: 1.6)
            for i in 0..<3 {
                let r = CGRect(x: 1.5, y: s.height - 1.5 - coin * CGFloat(i + 1), width: w * 0.62, height: coin)
                let shape = Path(roundedRect: r, cornerRadius: coin / 2)
                ctx.fill(shape, with: .color(.white))
                ctx.stroke(shape, with: .color(HTColor.ink), lineWidth: 1.6)
            }
        }
        .frame(width: HTIcon.base, height: HTIcon.base)
        .accessibilityHidden(true)
    }
}

/// Иконка приложения (скрипт снапшотов пишет её в AppIcon, пока нет PNG от ассетера): хром-звезда на ночном небе.
public struct HTAppIcon: View {
    public init() {}
    public var body: some View {
        ZStack {
            LinearGradient(colors: [HTColor.sky500, HTColor.night700, HTColor.night900], startPoint: .top, endPoint: .bottom)
            HTChromeStar().frame(width: 700, height: 665)
        }
        .frame(width: 1024, height: 1024)
    }
}

extension Color {
    /// Линейное смешение двух sRGB-цветов (для граней хрома).
    func mix(with other: Color, by t: Double) -> Color {
        #if canImport(UIKit)
        let a = UIColor(self), b = UIColor(other)
        #else
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .black, b = NSColor(other).usingColorSpace(.sRGB) ?? .black
        #endif
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(min(max(t, 0), 1))
        return Color(.sRGB, red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, opacity: 1)
    }
}
