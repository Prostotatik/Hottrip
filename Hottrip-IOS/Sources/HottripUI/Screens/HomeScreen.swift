import SwiftUI

/// Главная (spec-iter07 §1): один экран без прокрутки. Фото иллюминатора на весь экран, хром-звезда,
/// «ГОРЯЩИЕ ТУРЫ», лайм-CTA, «Успей забронировать» и таймер из трёх стеклянных плиток над таб-баром.
/// Координаты — по макету 402 × 874: верхний блок от safe area, нижний от нижнего края.
public struct HomeScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htSafeArea) private var safe
    @Environment(\.htReduceMotion) private var reduceMotion
    @Environment(\.htRenderMode) private var mode
    @State private var entered = false

    public init() {}

    /// Вход hero (P0-1) уже в финальном состоянии: сыгран, повторный показ, снапшот.
    private var settled: Bool { entered || router.homeIntroPlayed || mode == .snapshot }

    public var body: some View {
        GeometryReader { g in
            let h = g.size.height
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: [.init(color: HTColor.sky500, location: 0),
                                       .init(color: HTColor.night700, location: 0.6),
                                       .init(color: HTColor.night900, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                heroPhoto
                    .frame(width: g.size.width, height: h)
                    .scaleEffect(settled || reduceMotion ? 1 : 1.08)
                    .opacity(settled ? 1 : 0)
                    .animation(reduceMotion ? HTMotion.fade : HTMotion.entrance, value: settled)
                    .clipped()
                scrim(height: h)
                HTObject3D(.star)
                    .frame(width: HTSize.star.width, height: HTSize.star.height)
                    .rotation3DEffect(.degrees(settled || reduceMotion ? 0 : -18), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .offset(x: 10, y: 360 + (settled || reduceMotion ? 0 : 24))
                    .opacity(settled ? 1 : 0)
                    .animation(reduceMotion ? HTMotion.fade : HTMotion.entrance.delay(0.12), value: settled)
                header.padding(.top, safe.top - 6)
                headline.padding(.top, safe.top + Self.headlineTop)
                sparkles.padding(.top, safe.top + Self.headlineTop)
                bottom.frame(height: h, alignment: .bottom)
            }
            .frame(width: g.size.width, height: h, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .htStatusBar(light: true)
        .task {
            guard !router.homeIntroPlayed else { return }
            try? await Task.sleep(for: .milliseconds(60))
            entered = true
            router.homeIntroPlayed = true
        }
    }

    // MARK: Фото и скримы

    @ViewBuilder private var heroPhoto: some View {
        if HTImage.load("home-hero") != nil {
            HTImage("home-hero")
        } else {
            HTHomeHeroPlaceholder()
        }
    }

    /// Сверху `night900` 35 % → 0 к y 300 (читаемость шапки); снизу с y 540 до 700 — в `night900` 92 %:
    /// зона CTA, таймера и таб-бара всегда тёмно-синяя.
    private func scrim(height h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [HTColor.night900.opacity(0.35), HTColor.night900.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 300)
            LinearGradient(stops: [.init(color: HTColor.night900.opacity(0), location: 0),
                                   .init(color: HTColor.night900.opacity(0.92), location: 160 / (h - 540)),
                                   .init(color: HTColor.night900.opacity(0.92), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: h - 540)
                .offset(y: 540)
        }
        .frame(height: h, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: Шапка и заголовок

    private var header: some View {
        HStack(spacing: HTSpace.s12) {
            HTWordmark()
            Spacer(minLength: 0)
            HStack(spacing: HTSpace.s6) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: HTIcon.small, weight: .semibold))
                Text("Узбекистан").font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(width: 128, height: 38)
            .htGlassDark(Capsule())
            Image(systemName: "line.3.horizontal")
                .font(.system(size: HTIcon.large, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 24, height: HTSize.hitArea)
                .accessibilityLabel("Меню")
        }
        .htScreenPadding()
        .frame(height: 40)
    }

    /// Верх блока «ГОРЯЩИЕ ТУРЫ» под строкой состояния.
    private static let headlineTop: CGFloat = 66

    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ГОРЯЩИЕ").frame(height: HTTextStyle.heroDisplay.lineHeight)
                Text("ТУРЫ").frame(height: HTTextStyle.heroDisplay.lineHeight)
            }
            .htStyle(.heroDisplay)
            .fontWidth(.expanded)
            .foregroundStyle(HTColor.lime)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .entrance(settled, delay: 0.05, reduceMotion: reduceMotion)
            Text("из Узбекистана")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 10)
                .entrance(settled, delay: 0.1, reduceMotion: reduceMotion)
            Text("Пока другие думают —\nты отдыхаешь")
                .htStyle(HTTextStyle(15, 20, .regular))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 16)
                .entrance(settled, delay: 0.1, reduceMotion: reduceMotion)
        }
        .htScreenPadding()
    }

    /// Три искры ✦ вокруг теглайна. Координаты — от верха блока заголовка (`headlineTop`), а не от фото:
    /// искры привязаны к тексту и не зависят от того, где на hero-фото окажется рама иллюминатора.
    private var sparkles: some View {
        ZStack(alignment: .topLeading) {
            sparkle(14).offset(x: 200, y: 172)
            sparkle(12).offset(x: 3, y: 194)
            sparkle(16).offset(x: 30, y: 224)
        }
        .opacity(settled ? 1 : 0)
        .animation(HTMotion.fade.delay(0.3), value: settled)
        .accessibilityHidden(true)
    }

    private func sparkle(_ size: CGFloat) -> some View {
        Image(systemName: "sparkle").font(.system(size: size, weight: .medium)).foregroundStyle(.white)
    }

    // MARK: CTA и таймер

    private var bottom: some View {
        VStack(spacing: 0) {
            HTPrimaryButton(height: HTSize.heroCta, haptic: true, action: { router.push(.results(MockData.allHotQuery)) }) {
                HotCTALabel()
            }
            .accessibilityIdentifier("home.hot")
            .htScreenPadding()
            HTClock { now in SelectionTimer(phase: SelectionPhase.at(now)) }
                .padding(.top, 28)
        }
        // Низ подписей таймера — на 874 − 736 = 138 pt над краем экрана.
        .padding(.bottom, 138)
    }
}

/// «🔥 Горящие предложения →»: пламя и текст слева, стрелка справа.
private struct HotCTALabel: View {
    @Environment(\.htPressed) private var pressed
    @Environment(\.htReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: HTSpace.s14) {
            Image(systemName: "flame.fill").font(.system(size: HTIcon.large, weight: .semibold))
            Text("Горящие предложения")
            Spacer(minLength: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: HTIcon.base, weight: .semibold))
                .offset(x: pressed && !reduceMotion ? 4 : 0)
        }
        .padding(.horizontal, HTSpace.s20)
    }
}

/// «Успей забронировать» + три стеклянные плитки ЧЧ : ММ : СС с подписями (P0-2).
/// Меняются только изменившиеся разряды (`numericText`, `HTMotion.digit`). Последняя минута — цифры и обводка
/// лаймом, один раз без пульса; ноль — «Подборка обновляется», плитки приглушены.
struct SelectionTimer: View {
    @Environment(\.htReduceMotion) private var reduceMotion
    let phase: SelectionPhase

    private var parts: [(value: Int, label: String)] {
        let r = phase.remaining
        return [(r / 3600, "часов"), (r % 3600 / 60, "минут"), (r % 60, "секунд")]
    }

    var body: some View {
        let hot = phase.isLastMinute
        VStack(spacing: 0) {
            Text(phase.caption)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.opacity)
                .animation(HTMotion.fade, value: phase.caption)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                    if i > 0 {
                        Text(":").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                            .frame(width: 22, height: HTSize.timerTile.height)
                    }
                    VStack(spacing: 4) {
                        Text(String(format: "%02d", part.value))
                            .htStyle(.timerDigit)
                            .foregroundStyle(hot ? HTColor.lime : .white)
                            .contentTransition(.numericText(countsDown: true))
                            .htAnimation(HTMotion.digit, value: part.value, reduceMotion: reduceMotion)
                            .frame(width: HTSize.timerTile.width, height: HTSize.timerTile.height)
                            .htGlassDark(RoundedRectangle(cornerRadius: HTRadius.tile, style: .continuous),
                                         stroke: hot ? HTColor.lime.opacity(0.7) : nil)
                        Text(part.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize()
                    }
                }
            }
            .opacity(phase.isExpired ? 0.5 : 1)
            .padding(.top, HTSpace.s8)
            .animation(HTMotion.fade, value: hot)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phase.caption): \(HTFormat.hms(phase.remaining))")
    }
}

extension View {
    /// Тёмное стекло (spec-iter07 §0.2 `glassDark`): материал, белая заливка 12 %, обводка 18 %.
    func htGlassDark<S: InsettableShape>(_ shape: S, stroke: Color? = nil) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .background(Color.white.opacity(0.12), in: shape)
            .overlay(shape.strokeBorder(stroke ?? Color.white.opacity(0.18), lineWidth: HTSize.hairline))
            .environment(\.colorScheme, .dark)
    }

    /// Одноразовый вход элемента hero: подъём на 12 pt и проявление (Reduce Motion — только проявление).
    func entrance(_ settled: Bool, delay: Double, reduceMotion: Bool) -> some View {
        self
            .opacity(settled ? 1 : 0)
            .offset(y: settled || reduceMotion ? 0 : 12)
            .animation(reduceMotion ? HTMotion.fade : HTMotion.entrance.delay(delay), value: settled)
    }
}
