import SwiftUI

/// Строка состояния: светлая над тёмными зонами (главная, фото тура), тёмная над светлым фоном `canvas`.
///
/// Экран сообщает тон своей верхней кромки роутеру (`htStatusBar` — постоянный тон, `htStatusBarZone` — тёмная
/// зона, которая может уехать из-под строки при прокрутке). Роутер хранит тон по ключу экрана и отдаёт тон
/// экрана, который сейчас наверху стека; приложение применяет его к корневому UIHostingController.
/// Экран без модификатора — тёмный текст (светлый фон по умолчанию).
private struct StatusKeyKey: EnvironmentKey { static let defaultValue = "tab" }

extension EnvironmentValues {
    /// Ключ экрана для тона строки состояния (ставит `HottripRootView`).
    var htStatusKey: String {
        get { self[StatusKeyKey.self] }
        set { self[StatusKeyKey.self] = newValue }
    }
}

extension AppRouter {
    static func statusKey(tab: HTTab) -> String { "tab.\(tab.rawValue)" }
    static func statusKey(route: AppRoute) -> String { "route.\(route.hashValue)" }

    /// Ключ экрана, который сейчас виден.
    var visibleStatusKey: String {
        if let top = path.last { return Self.statusKey(route: top) }
        return Self.statusKey(tab: selectedTab)
    }

    /// Нужен светлый текст строки состояния.
    public var statusBarLight: Bool { statusBarTones[visibleStatusKey] ?? false }
}

extension View {
    /// Постоянный тон под строкой состояния для всего экрана.
    func htStatusBar(light: Bool) -> some View { modifier(StatusBarTone(light: light)) }

    /// Эта view — тёмная зона у верхнего края экрана: пока она закрывает строку состояния, текст строки светлый.
    /// - Parameter release: зона «отпускает» строку, когда её низ поднялся выше `safe.top + release`: дальше
    ///   экран показывает подложку и тёмный текст. Оттягивание вниз (зона ниже верха) — тоже «закрывает».
    func htStatusBarZone(release: CGFloat = 0) -> some View { modifier(StatusBarZone(release: release)) }
}

private struct StatusBarTone: ViewModifier {
    @Environment(AppRouter.self) private var router
    @Environment(\.htStatusKey) private var key
    let light: Bool

    func body(content: Content) -> some View {
        content.onAppear { router.setStatusBar(light: light, for: key) }
    }
}

private struct StatusBarZone: ViewModifier {
    @Environment(AppRouter.self) private var router
    @Environment(\.htStatusKey) private var key
    @Environment(\.htSafeArea) private var safe
    let release: CGFloat

    func body(content: Content) -> some View {
        // Низ строки состояния (+ запас) в глобальных координатах окна.
        let limit = safe.top + release
        return content.onGeometryChange(for: Bool.self) { geo in
            geo.frame(in: .global).maxY >= limit
        } action: { covers in
            router.setStatusBar(light: covers, for: key)
        }
    }
}
