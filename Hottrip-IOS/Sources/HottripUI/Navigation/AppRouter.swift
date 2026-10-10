import SwiftUI
import Observation

/// Маршруты push-навигации. Экраны получают данные параметрами — снапшот-утилита собирает любой экран с моками.
public enum AppRoute: Hashable {
    case search(SearchQuery)
    case results(SearchQuery)
    case tour(Tour)
    case payment(Tour, OperatorOffer)
    case success(Booking)
}

@Observable
public final class AppRouter {
    public var selectedTab: HTTab
    public var path: [AppRoute]
    public var favorites: Set<String>
    /// Тон строки состояния по ключу экрана: true — светлый текст (см. StatusBar.swift).
    var statusBarTones: [String: Bool] = [:]
    /// Вход hero главной уже сыгран: при возврате на главную он не повторяется (P0-1).
    var homeIntroPlayed = false
    /// Демо-запуск: экран вкладки в нужном состоянии (только при старте; вкладку переключили — обычный экран).
    var demoTabScreen: AnyView?

    public init(selectedTab: HTTab = .home, path: [AppRoute] = [], favorites: Set<String> = MockData.defaultFavorites) {
        self.selectedTab = selectedTab; self.path = path; self.favorites = favorites
    }

    public func push(_ route: AppRoute) { path.append(route) }
    public func pop() { if !path.isEmpty { path.removeLast() } }
    /// Заменяет верхний экран стека (оплата → успех: к оплаченной оплате нельзя вернуться свайпом).
    public func replaceTop(with route: AppRoute) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }
    public func popToRoot() { path.removeAll() }
    /// «Поиск» — не вкладка, а полноэкранный экран поверх текущей (spec-iter07 §2.2: без таб-бара, со стрелкой назад).
    public func select(_ tab: HTTab) {
        if tab == .search { push(.search(MockData.defaultQuery)); return }
        demoTabScreen = nil
        if tab == selectedTab { popToRoot() } else { selectedTab = tab }
    }
    public func goHome() { popToRoot(); selectedTab = .home }
    public func toggleFavorite(_ tour: Tour) {
        if favorites.contains(tour.id) { favorites.remove(tour.id) } else { favorites.insert(tour.id) }
    }
    public func isFavorite(_ tour: Tour) -> Bool { favorites.contains(tour.id) }
    func setStatusBar(light: Bool, for key: String) {
        if statusBarTones[key] != light { statusBarTones[key] = light }
    }
}

extension AppRoute {
    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .search(let q): SearchScreen(query: q)
        case .results(let q): ResultsScreen(query: q)
        case .tour(let t): TourDetailScreen(tour: t)
        case .payment(let t, let o): PaymentScreen(tour: t, offer: o)
        case .success(let b): SuccessScreen(booking: b)
        }
    }
}
