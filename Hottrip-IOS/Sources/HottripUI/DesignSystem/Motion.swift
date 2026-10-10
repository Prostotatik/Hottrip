import SwiftUI

/// Токены движения (interactions-iter07 §2.0). Экраны берут кривые только отсюда.
/// Бесконечных анимаций нет: движение запускает действие, прокрутка или одно появление экрана.
/// dampingFraction не ниже 0,85, кроме сердца и тоста; в оплате только `calm`.
public enum HTMotion {
    public static let press = Animation.spring(response: 0.22, dampingFraction: 0.9)
    public static let select = Animation.spring(response: 0.35, dampingFraction: 0.85)
    public static let dot = Animation.spring(response: 0.35, dampingFraction: 0.85)
    public static let entrance = Animation.spring(response: 0.7, dampingFraction: 0.86)
    public static let digit = Animation.snappy(duration: 0.3)
    public static let price = Animation.snappy(duration: 0.45)
    public static let expand = Animation.spring(response: 0.45, dampingFraction: 0.9)
    public static let calm = Animation.easeInOut(duration: 0.3)
    public static let fade = Animation.easeInOut(duration: 0.2)
    public static let crossfade = Animation.easeInOut(duration: 0.15)
    public static let toast = Animation.spring(response: 0.4, dampingFraction: 0.8)
    public static let mark = Animation.spring(response: 0.45, dampingFraction: 0.7)

    public static let payDuration: Double = 1.6
    /// Галочка в CTA держится перед переходом на экран брони.
    public static let paidHold: Double = 0.4
    public static let toastDuration: Double = 2.5
    /// Плашка «оператор · цена» над CTA, когда цена в шапке тура вне экрана.
    public static let operatorNoteDuration: Double = 1.5
    /// Одноразовая подсветка поля «Куда» после выбора популярного направления.
    public static let fieldFlash: Double = 0.6
}

public extension View {
    /// Анимирует изменение `value`, если Reduce Motion выключен (иначе — мгновенно).
    func htAnimation<V: Equatable>(_ animation: Animation, value: V, reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }

    /// matchedGeometryEffect, отключаемый при Reduce Motion (тогда — мгновенная смена).
    @ViewBuilder
    func htMatchedGeometry(id: String, in ns: Namespace.ID, enabled: Bool) -> some View {
        if enabled { matchedGeometryEffect(id: id, in: ns) } else { self }
    }
}

/// `withAnimation`, уважающий Reduce Motion: вместо движения — короткий кроссфейд.
@MainActor
public func htWithAnimation(_ animation: Animation, reduceMotion: Bool, _ body: () -> Void) {
    withAnimation(reduceMotion ? HTMotion.crossfade : animation, body)
}
