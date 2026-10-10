import SwiftUI

private struct PressedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// Кнопка сейчас нажата (стрелка CTA сдвигается на 4 pt).
    var htPressed: Bool {
        get { self[PressedKey.self] }
        set { self[PressedKey.self] = newValue }
    }
}

/// Нажатие (interactions-iter07 P0-3): scale 0,97 и чуть темнее, `HTMotion.press`.
/// При Reduce Motion остаётся только затемнение.
public struct HTPressStyle: ButtonStyle {
    let scale: CGFloat
    public init(scale: CGFloat = 0.97) { self.scale = scale }

    public func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, scale: scale)
    }

    private struct PressBody: View {
        @Environment(\.htReduceMotion) private var reduceMotion
        let configuration: Configuration
        let scale: CGFloat
        var body: some View {
            configuration.label
                .environment(\.htPressed, configuration.isPressed)
                .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
                .brightness(configuration.isPressed ? -0.04 : 0)
                .animation(HTMotion.press, value: configuration.isPressed)
        }
    }
}

/// Главная CTA: лайм-капсула, текст `onLime`, лаймовая тень. Disabled — та же кнопка на 50 %.
/// `haptic` — лёгкий удар на главных действиях (горящие, найти, забронировать, оплатить).
public struct HTPrimaryButton<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var taps = 0
    let height: CGFloat
    let haptic: Bool
    let action: () -> Void
    let label: Label

    public init(height: CGFloat = HTSize.cta, haptic: Bool = false, action: @escaping () -> Void,
                @ViewBuilder label: () -> Label) {
        self.height = height; self.haptic = haptic; self.action = action; self.label = label()
    }

    public var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            // Капсула (фон, тень, размер) неподвижна: смена содержимого (фазы оплаты) переходит только внутри неё
            // и обрезается по форме кнопки. ZStack — стабильный контейнер, иначе переход `label` с if/switch
            // увозил всю капсулу вместе с фоном и тенью (P0-7).
            ZStack { label }
                .htStyle(.button)
                .foregroundStyle(HTColor.onLime)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(Capsule())
                .background(HTColor.lime, in: Capsule())
                .htShadow(.lime)
                .contentShape(Capsule())
        }
        .buttonStyle(HTPressStyle())
        .opacity(isEnabled ? 1 : 0.5)
        .animation(HTMotion.fade, value: isEnabled)
        .sensoryFeedback(.impact(weight: .light), trigger: taps) { _, _ in haptic }
    }
}

public extension HTPrimaryButton where Label == HTButtonTitle {
    init(_ title: String, arrow: Bool = false, haptic: Bool = false, action: @escaping () -> Void) {
        self.init(haptic: haptic, action: action) { HTButtonTitle(title: title, arrow: arrow) }
    }
}

/// Текст CTA со стрелкой: при нажатии стрелка уезжает на 4 pt вправо.
public struct HTButtonTitle: View {
    @Environment(\.htPressed) private var pressed
    @Environment(\.htReduceMotion) private var reduceMotion
    let title: String
    let arrow: Bool

    public var body: some View {
        HStack(spacing: HTSpace.s8) {
            Text(title).lineLimit(1).minimumScaleFactor(0.85)
            if arrow {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .offset(x: pressed && !reduceMotion ? 4 : 0)
            }
        }
        .padding(.horizontal, HTSpace.s20)
    }
}

/// Вторичная кнопка: капсула с обводкой `ink`.
public struct HTSecondaryButton: View {
    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .htStyle(.button)
                .foregroundStyle(HTColor.ink)
                .padding(.horizontal, HTSpace.s24)
                .frame(height: 50)
                .overlay(Capsule().strokeBorder(HTColor.ink, lineWidth: HTSize.strongStroke))
                .contentShape(Capsule())
        }
        .buttonStyle(HTPressStyle())
    }
}

/// Текстовая кнопка 16 semibold (зона нажатия 44).
public struct HTTextButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    public init(_ title: String, color: Color = HTColor.ink, action: @escaping () -> Void) {
        self.title = title; self.color = color; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .htStyle(.bodyStrong)
                .foregroundStyle(color)
                .frame(minHeight: HTSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(HTPressStyle())
    }
}

/// Кнопка «назад»: `arrow.left` (поиск, выдача, тур) или `chevron.left` (оплата), без подложки, зона 44.
public struct HTBackButton: View {
    @Environment(AppRouter.self) private var router
    let icon: String
    let color: Color
    let size: CGFloat

    public init(chevron: Bool = false, color: Color = HTColor.ink, size: CGFloat = HTIcon.large) {
        self.icon = chevron ? "chevron.left" : "arrow.left"; self.color = color; self.size = size
    }

    public var body: some View {
        Button { router.pop() } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: HTSize.hitArea, height: HTSize.hitArea, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Назад")
        .accessibilityIdentifier("nav.back")
    }
}

/// Стеклянный квадрат r 14 поверх фото (♡, ↗): светлый материал, белая заливка 55 %, обводка 60 %.
public struct HTGlassSquare<Icon: View>: View {
    let size: CGFloat
    let icon: Icon

    public init(size: CGFloat = HTSize.photoButton, @ViewBuilder icon: () -> Icon) {
        self.size = size; self.icon = icon()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: HTRadius.tile, style: .continuous)
        icon
            .font(.system(size: HTIcon.base, weight: .semibold))
            .foregroundStyle(HTColor.ink)
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: shape)
            .background(Color.white.opacity(0.55), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.6), lineWidth: HTSize.hairline))
            .environment(\.colorScheme, .light)
            .frame(width: max(size, HTSize.hitArea), height: max(size, HTSize.hitArea))
            .contentShape(Rectangle())
    }
}

/// Сердце избранного на фото: bounce, лёгкий хаптик, заливка `ink` в избранном.
struct HTHeartButton: View {
    @Environment(\.htReduceMotion) private var reduceMotion
    let isFavorite: Bool
    var size: CGFloat = HTSize.photoButton
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HTGlassSquare(size: size) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: reduceMotion ? false : isFavorite)
            }
        }
        .buttonStyle(HTPressStyle(scale: 0.94))
        .sensoryFeedback(.impact(weight: .light), trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Убрать из избранного" : "В избранное")
    }
}
