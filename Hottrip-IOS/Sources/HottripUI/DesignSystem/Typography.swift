import SwiftUI

/// Текстовый стиль (spec-iter07 §0.3): только SF Pro, кегль, межстрочный, вес, трекинг.
public struct HTTextStyle: Sendable {
    public let size: CGFloat
    public let lineHeight: CGFloat
    public let weight: Font.Weight
    public let tracking: CGFloat
    public let monoDigits: Bool

    public init(_ size: CGFloat, _ lineHeight: CGFloat, _ weight: Font.Weight, tracking: CGFloat = 0, monoDigits: Bool = false) {
        self.size = size; self.lineHeight = lineHeight; self.weight = weight
        self.tracking = tracking; self.monoDigits = monoDigits
    }

    public func sized(_ newSize: CGFloat) -> HTTextStyle {
        HTTextStyle(newSize, lineHeight * newSize / size, weight, tracking: tracking, monoDigits: monoDigits)
    }

    public func weight(_ w: Font.Weight) -> HTTextStyle {
        HTTextStyle(size, lineHeight, w, tracking: tracking, monoDigits: monoDigits)
    }

    public var font: Font {
        let f = Font.system(size: size, weight: weight)
        return monoDigits ? f.monospacedDigit() : f
    }

    /// Дополнительный межстрочный интервал поверх натурального (~1,2 кегля у SF).
    var extraLeading: CGFloat { max(0, lineHeight - size * 1.2) }
}

public extension HTTextStyle {
    /// Кегль сверен с референсом: «ГОРЯЩИЕ» ≈ 344 pt в ширину при высоте прописных ≈ 51 pt — это SF Pro Black
    /// Expanded 70 (обычная ширина дала бы 280 pt и «мелкий» заголовок); строки через 56.
    static let heroDisplay = HTTextStyle(70, 56, .black, tracking: -1.5)
    static let h1 = HTTextStyle(32, 36, .bold, tracking: -0.6)
    static let h2Photo = HTTextStyle(28, 32, .bold, tracking: -0.4)
    static let title = HTTextStyle(20, 24, .bold, tracking: -0.3)
    static let h3 = HTTextStyle(18, 22, .semibold, tracking: -0.2)
    static let headline = HTTextStyle(17, 22, .semibold, tracking: -0.2)
    static let body = HTTextStyle(16, 21, .medium)
    static let bodyStrong = HTTextStyle(16, 21, .semibold)
    static let callout = HTTextStyle(15, 21, .regular)
    static let calloutStrong = HTTextStyle(15, 20, .semibold)
    static let bodyS = HTTextStyle(14, 19, .regular)
    static let bodySMedium = HTTextStyle(14, 19, .medium)
    static let footnote = HTTextStyle(13, 17, .regular)
    static let caption = HTTextStyle(12, 16, .medium)
    static let tab = HTTextStyle(11, 13, .medium)
    static let price = HTTextStyle(28, 32, .bold, tracking: -0.4, monoDigits: true)
    static let priceM = HTTextStyle(22, 26, .bold, tracking: -0.3, monoDigits: true)
    static let priceS = HTTextStyle(20, 24, .bold, tracking: -0.2, monoDigits: true)
    static let button = HTTextStyle(17, 22, .semibold, tracking: -0.1)
    static let timerDigit = HTTextStyle(30, 34, .semibold, monoDigits: true)
}

public extension View {
    func htStyle(_ style: HTTextStyle) -> some View {
        self.font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.extraLeading)
    }
}
