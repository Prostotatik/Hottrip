import SwiftUI

/// Сумма «9 480 000 UZS» одной строкой; цифры прокатываются `numericText`.
public struct HTPriceText: View {
    @Environment(\.htReduceMotion) private var reduceMotion
    let value: Int
    let style: HTTextStyle
    let color: Color

    public init(_ value: Int, style: HTTextStyle = .priceS, color: Color = HTColor.ink) {
        self.value = value; self.style = style; self.color = color
    }

    public var body: some View {
        Text(HTFormat.uzs(value))
            .htStyle(style)
            .foregroundStyle(color)
            .lineLimit(1)
            // При Reduce Motion цифры не катятся, а сменяются кроссфейдом.
            .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(value)))
    }
}

/// Зачёркнутая старая цена.
public struct HTOldPrice: View {
    let value: Int
    let color: Color
    let size: CGFloat
    public init(_ value: Int, color: Color = HTColor.ink3, size: CGFloat = 13) {
        self.value = value; self.color = color; self.size = size
    }
    public var body: some View {
        Text(HTFormat.uzs(value))
            .font(.system(size: size))
            .monospacedDigit()
            .strikethrough(color: color)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Лайм-чип скидки «−32%», капсула h 26.
public struct HTDiscountChip: View {
    let percent: Int
    public init(_ percent: Int) { self.percent = percent }
    public var body: some View {
        Text(HTFormat.discount(percent))
            .font(.system(size: 13, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(HTColor.onLime)
            .contentTransition(.numericText(value: Double(percent)))
            .padding(.horizontal, HTSpace.s10)
            .frame(height: 26)
            .background(HTColor.lime, in: Capsule())
            .accessibilityLabel("Скидка \(percent) процентов")
    }
}

/// Лайм-бейдж «🔥 Горящий тур».
public struct HTHotBadge: View {
    public init() {}
    public var body: some View {
        HStack(spacing: HTSpace.s6) {
            Image(systemName: "flame.fill").font(.system(size: HTIcon.micro, weight: .semibold))
            Text("Горящий тур").font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(HTColor.onLime)
        .padding(.horizontal, HTSpace.s12)
        .frame(height: HTSize.badge)
        .background(HTColor.lime, in: Capsule())
    }
}

/// Радио 22: выбранное — кольцо 2 pt и точка 10 `azure` (точка растёт 0,4 → 1); невыбранное — кольцо 1,5 `ink3`.
public struct HTRadio: View {
    @Environment(\.htReduceMotion) private var reduceMotion
    let isOn: Bool
    public init(_ isOn: Bool) { self.isOn = isOn }
    public var body: some View {
        ZStack {
            Circle().strokeBorder(isOn ? HTColor.azure : HTColor.ink3, lineWidth: isOn ? 2 : HTSize.strongStroke)
            Circle().fill(HTColor.azure)
                .frame(width: HTSize.radioDot, height: HTSize.radioDot)
                .scaleEffect(isOn ? 1 : 0.4)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: HTSize.radio, height: HTSize.radio)
        .htAnimation(HTMotion.select, value: isOn, reduceMotion: reduceMotion)
    }
}

/// Переключатель: вкл — лаймовый трек, белый кноб.
public struct HTSwitch: View {
    @Environment(\.htReduceMotion) private var reduceMotion
    @Binding var isOn: Bool
    let label: String

    public init(isOn: Binding<Bool>, label: String) { self._isOn = isOn; self.label = label }

    public var body: some View {
        let size = HTSize.toggle
        let knob = size.height - 2 * HTSpace.s2
        Button { isOn.toggle() } label: {
            Capsule()
                .fill(isOn ? HTColor.lime : HTColor.line)
                .frame(width: size.width, height: size.height)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle().fill(HTColor.surface).frame(width: knob, height: knob).padding(HTSpace.s2)
                        .htShadow(.card)
                }
                .htAnimation(HTMotion.select, value: isOn, reduceMotion: reduceMotion)
                .frame(minHeight: HTSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "включено" : "выключено")
    }
}

/// Чип-капсула h 36. Выбранный — `ink` с белым текстом (сортировка) или `lime` (даты в sheet).
public struct HTChip: View {
    public enum Accent { case ink, lime }
    let title: String
    let isOn: Bool
    let accent: Accent
    let action: () -> Void

    public init(_ title: String, isOn: Bool, accent: Accent = .ink, action: @escaping () -> Void) {
        self.title = title; self.isOn = isOn; self.accent = accent; self.action = action
    }

    public var body: some View {
        let fill = accent == .ink ? HTColor.ink : HTColor.lime
        let text = accent == .ink ? Color.white : HTColor.onLime
        Button(action: action) {
            Text(title)
                .htStyle(.bodySMedium)
                .foregroundStyle(isOn ? text : HTColor.ink)
                .padding(.horizontal, HTSpace.s14)
                .frame(height: HTSize.chip)
                .background(isOn ? fill : HTColor.surface, in: Capsule())
                .overlay { if !isOn { Capsule().strokeBorder(HTColor.line, lineWidth: HTSize.hairline) } }
                .frame(minHeight: HTSize.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(HTPressStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Горизонтальная лента чипов с полями экрана.
public struct HTChipRail<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    let selected: Item?
    let accent: HTChip.Accent
    let onSelect: (Item) -> Void

    public init(_ items: [Item], selected: Item?, accent: HTChip.Accent = .ink, title: @escaping (Item) -> String,
                onSelect: @escaping (Item) -> Void) {
        self.items = items; self.selected = selected; self.accent = accent; self.title = title; self.onSelect = onSelect
    }

    public var body: some View {
        HTHScroll {
            HStack(spacing: HTSpace.s8) {
                ForEach(items, id: \.self) { item in
                    HTChip(title(item), isOn: item == selected, accent: accent) { onSelect(item) }
                }
            }
            .padding(.horizontal, HTSpace.screen)
        }
    }
}

/// Заголовок секции `h3`, справа опционально ссылка `azure` 14.
public struct HTSectionHeader: View {
    let title: String
    let style: HTTextStyle
    let action: String?
    let onAction: () -> Void

    public init(_ title: String, style: HTTextStyle = .h3, action: String? = nil, onAction: @escaping () -> Void = {}) {
        self.title = title; self.style = style; self.action = action; self.onAction = onAction
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).htStyle(style).foregroundStyle(HTColor.ink).accessibilityAddTraits(.isHeader)
            Spacer(minLength: HTSpace.s8)
            if let action {
                Button(action: onAction) {
                    Text(action).htStyle(.bodySMedium).foregroundStyle(HTColor.azure)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Словесный знак HOTTRIP: SF Pro Black Italic Expanded 22.
public struct HTWordmark: View {
    let size: CGFloat
    let color: Color
    public init(size: CGFloat = 22, color: Color = .white) { self.size = size; self.color = color }
    public var body: some View {
        Text("HOTTRIP")
            .font(.system(size: size, weight: .black).width(.expanded))
            // У SF Pro Expanded Black нет курсива — наклон 12° аффинным сдвигом.
            .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.21, d: 1, tx: size * 0.1, ty: 0))
            .tracking(-0.5)
            .foregroundStyle(color)
            .accessibilityLabel("Hottrip")
    }
}

/// Волосяной разделитель `line`.
public struct HTHairline: View {
    let color: Color
    public init(_ color: Color = HTColor.line) { self.color = color }
    public var body: some View { color.frame(height: HTSize.hairline) }
}

public extension View {
    /// Белая карточка: `surface`, скругление, тень `card`, по желанию обводка `line`.
    func htCard(radius: CGFloat = HTRadius.card, stroke: Bool = false, shadow: HTShadow? = .card) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(HTColor.surface, in: shape)
            .overlay { if stroke { shape.strokeBorder(HTColor.line, lineWidth: HTSize.hairline) } }
            .shadow(color: shadow?.color ?? .clear, radius: shadow?.radius ?? 0, x: 0, y: shadow?.y ?? 0)
    }

    /// Боковые поля экрана 20 pt.
    func htScreenPadding() -> some View { padding(.horizontal, HTSpace.screen) }
}

/// Миниатюра отеля 96 × 104 r 14 (сводка оплаты, бронь).
struct HTThumb: View {
    let name: String
    var size = HTSize.thumb
    var body: some View {
        HTImage(name)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: HTRadius.tile, style: .continuous))
    }
}

/// Пустое состояние: хром-звезда 140, заголовок, подсказка, действие.
struct HTEmptyState<Action: View>: View {
    let title: String
    let message: String
    let action: Action

    init(_ title: String, message: String, @ViewBuilder action: () -> Action) {
        self.title = title; self.message = message; self.action = action()
    }

    var body: some View {
        VStack(spacing: HTSpace.s12) {
            HTObject3D(.star).frame(width: HTSize.starSmall.width, height: HTSize.starSmall.height)
                .padding(.bottom, HTSpace.s8)
            Text(title).htStyle(.title).foregroundStyle(HTColor.ink)
            Text(message).htStyle(.bodyS).foregroundStyle(HTColor.ink2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            action.padding(.top, HTSpace.s8)
        }
        .frame(maxWidth: .infinity)
    }
}
