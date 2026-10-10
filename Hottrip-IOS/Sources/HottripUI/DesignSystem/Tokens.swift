import SwiftUI

/// Палитра «лайм + небо + белые карточки» (spec-iter07 §0.2). Единственное место с hex-значениями.
/// Приложение всегда светлое (UIUserInterfaceStyle = Light), поэтому цвета без тёмных вариантов.
public enum HTColor {
    public static let lime = Color(hex: 0xC8F03C)
    public static let limeSoft = Color(hex: 0xEEF9C8)
    public static let limeStroke = Color(hex: 0xC8F03C, alpha: 0.7)
    public static let limeShadow = Color(hex: 0x9CC21A, alpha: 0.35)
    public static let onLime = Color(hex: 0x0B1633)

    public static let ink = Color(hex: 0x0B1633)
    public static let ink2 = Color(hex: 0x4B5673)
    public static let ink3 = Color(hex: 0x8E97AB)
    public static let line = Color(hex: 0xE4E9F2)
    public static let canvasTop = Color(hex: 0xE6EFFA)
    public static let canvasBottom = Color(hex: 0xF5F8FC)
    public static let surface = Color(hex: 0xFFFFFF)
    public static let azure = Color(hex: 0x2F6BF5)

    public static let night900 = Color(hex: 0x0A1A45)
    public static let night700 = Color(hex: 0x123A8C)
    public static let sky500 = Color(hex: 0x3C7FE0)

    public static let onPhoto2 = Color.white.opacity(0.82)

    public static let danger = Color(hex: 0xE5484D)

    /// Фон светлых экранов: вертикальный градиент «небо после рассвета».
    public static let canvas = LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .top, endPoint: .bottom)

    /// Фирменные цвета плиток способов оплаты (§0.2): код, не картинки.
    public enum Brand {
        public static let payme = [Color(hex: 0x12C2C0), Color(hex: 0x0FA9B8)]
        public static let click = [Color(hex: 0x1E6FF2), Color(hex: 0x1456D6)]
        public static let uzum = [Color(hex: 0x7A2CF6), Color(hex: 0x5B1FD1)]
        public static let humo = [Color(hex: 0x0E4C8C), Color(hex: 0x0E4C8C)]
        public static let humoStripe = Color(hex: 0xF6B800)
        public static let installment = [Color(hex: 0xFF5A9E), Color(hex: 0xF23C84)]
        public static let anex = Color(hex: 0xE30613)
        public static let pegas = Color(hex: 0x1B3E8F)
        public static let coral = [Color(hex: 0xFF8A3D), Color(hex: 0x2F6BF5)]
    }

    /// Только для рамки телефона в снапшотах.
    public enum Chrome {
        public static let frame = Color(hex: 0x0B0A09)
        public static let backdrop = Color(hex: 0xD6DEEA)
        public static let island = Color(hex: 0x000000)
    }
}

/// Тени светлых экранов (§0.4).
public enum HTShadow {
    case card, raised, lime

    var color: Color {
        switch self {
        case .card: Color(hex: 0x0B1633, alpha: 0.06)
        case .raised: Color(hex: 0x0B1633, alpha: 0.10)
        case .lime: HTColor.limeShadow
        }
    }
    var radius: CGFloat {
        switch self {
        case .card: 10
        case .raised: 14
        case .lime: 10
        }
    }
    var y: CGFloat {
        switch self {
        case .card: 6
        case .raised: 10
        case .lime: 8
        }
    }
}

public extension View {
    func htShadow(_ shadow: HTShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}

/// Шкала отступов, кратная 2.
public enum HTSpace {
    public static let s2: CGFloat = 2
    public static let s4: CGFloat = 4
    public static let s6: CGFloat = 6
    public static let s8: CGFloat = 8
    public static let s10: CGFloat = 10
    public static let s12: CGFloat = 12
    public static let s14: CGFloat = 14
    public static let s16: CGFloat = 16
    public static let s20: CGFloat = 20
    public static let s24: CGFloat = 24
    public static let s28: CGFloat = 28
    public static let s32: CGFloat = 32

    public static let screen: CGFloat = 20
}

/// Радиусы (§0.4). Все фигуры — `.continuous`.
public enum HTRadius {
    public static let tile: CGFloat = 14
    public static let field: CGFloat = 16
    public static let card: CGFloat = 18
    public static let summary: CGFloat = 20
    public static let banner: CGFloat = 24
    public static let sheet: CGFloat = 28
    public static let tabBar: CGFloat = 30
}

/// Фиксированные размеры компонентов (spec-iter07 §1–§6).
public enum HTSize {
    public static let hitArea: CGFloat = 44
    public static let cta: CGFloat = 54
    public static let heroCta: CGFloat = 62
    public static let field: CGFloat = 50
    public static let chip: CGFloat = 36
    public static let radio: CGFloat = 22
    public static let radioDot: CGFloat = 10
    public static let hairline: CGFloat = 1
    public static let strongStroke: CGFloat = 1.5

    public static let tabBar: CGFloat = 74
    public static let tabBarInset: CGFloat = 12
    /// Низ таб-бара над нижним краем экрана (874 − 836).
    public static let tabBarBottom: CGFloat = 38
    /// Сколько снизу закрывает плавающий таб-бар: прокрутка экранов с табами заканчивается выше него.
    public static let tabBarClearance: CGFloat = tabBar + tabBarBottom
    public static let tabPill: CGFloat = 36

    public static let timerTile = CGSize(width: 60, height: 46)
    public static let star = CGSize(width: 200, height: 190)
    public static let starSmall = CGSize(width: 140, height: 133)
    public static let promo3D = CGSize(width: 180, height: 170)
    public static let promoBanner: CGFloat = 134
    /// На сколько 3D-фигура промо выходит за верх баннера.
    public static let promoOverhang: CGFloat = 12

    public static let destinationCard = CGSize(width: 114, height: 168)
    public static let gallery: CGFloat = 404
    /// Шит тура накрывает фото на 20 pt.
    public static let sheetOverlap: CGFloat = 20
    public static let galleryDot: CGFloat = 7
    public static let galleryDotActive: CGFloat = 18
    public static let photoButton: CGFloat = 44
    public static let badge: CGFloat = 30
    public static let operatorLogo: CGFloat = 36
    /// Референс: три строки занимают ≈ 148 pt (60 + 44 + 44) и целиком стоят над CTA.
    public static let operatorRow: CGFloat = 44
    public static let operatorRowBest: CGFloat = 60

    public static let summaryHeight: CGFloat = 128
    public static let thumb = CGSize(width: 96, height: 104)
    public static let paymentRow: CGFloat = 72
    public static let brandTile: CGFloat = 56

    public static let resultPhoto: CGFloat = 180
    public static let cardHeart: CGFloat = 36
    public static let roundAction: CGFloat = 44
    public static let favoriteRow: CGFloat = 112
    public static let favoriteThumb: CGFloat = 96
    public static let segmented: CGFloat = 40
    public static let avatar: CGFloat = 64
    public static let profileStats: CGFloat = 96
    public static let settingsRow: CGFloat = 52
    public static let settingsIcon: CGFloat = 32
    public static let successMark: CGFloat = 88

    public static let sliderTrack: CGFloat = 4
    public static let sliderKnob: CGFloat = 26
    public static let toggle = CGSize(width: 51, height: 31)
    public static let expiryField: CGFloat = 120
    public static let inputField: CGFloat = 50
    /// Высота sheet «Даты»: дни, ночи, туристы, итог, CTA.
    public static let datesSheet: CGFloat = 470
    public static let budgetSheet: CGFloat = 360
    public static let compareSheet: CGFloat = 420
    /// Зазор от низа активного поля до клавиатуры: парящая «Готово» iOS 27 (44) + 12 + 8.
    public static let keyboardClearance: CGFloat = 64
    /// Липкая CTA (54) + отступ до неё сверху: столько контента прячется под ней.
    public static let stickyClearance: CGFloat = 96
}

/// Иконки SF Symbols (§0.5): вес .medium, 20–22 pt.
public enum HTIcon {
    public static let base: CGFloat = 20
    public static let large: CGFloat = 22
    public static let tab: CGFloat = 24
    public static let inline: CGFloat = 16
    public static let small: CGFloat = 14
    public static let micro: CGFloat = 12
}

public extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}
