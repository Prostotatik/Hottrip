import SwiftUI

/// Демо-навигация для съёмки на симуляторе: launch-аргументы открывают любой экран и состояние из каталога
/// снапшотов, с настоящим стеком навигации под ним (назад работает).
///
///     xcrun simctl launch <udid> uz.hottrip.demo -demoScreen tour -demoState operatorCoral
///
/// Без `-demoScreen` ничего не меняется: `DemoLaunch.current` = nil, приложение стартует с главной.
/// Весь демо-код — в этом файле; экраны получают состояние теми же параметрами init, что и снапшоты.
public struct DemoLaunch {
    /// Экран, состояние и имя соответствующего снапшота (`_workspace/shared/snapshots/<shot>.png`).
    public struct Entry: Sendable {
        public let screen: String
        public let state: String
        public let shot: String
    }

    /// Реестр: `-demoScreen <screen> -demoState <state>` → кадр. Состояние `default` можно не указывать.
    public static let entries: [Entry] = [
        .init(screen: "home", state: "default", shot: "01-home"),
        .init(screen: "home", state: "timerLastMinute", shot: "01b-home-timer-last-minute"),
        .init(screen: "home", state: "timerZero", shot: "01c-home-timer-zero"),
        .init(screen: "search", state: "default", shot: "02-search"),
        .init(screen: "search", state: "datesSheet", shot: "02b-search-dates-sheet"),
        .init(screen: "search", state: "budgetSheet", shot: "02c-search-budget-sheet"),
        .init(screen: "search", state: "empty", shot: "02d-search-empty-destination"),
        .init(screen: "results", state: "default", shot: "03-results"),
        .init(screen: "results", state: "empty", shot: "03b-results-empty"),
        .init(screen: "results", state: "favoriteToast", shot: "03c-results-favorite-toast"),
        .init(screen: "results", state: "hot", shot: "03d-results-hot"),
        .init(screen: "results", state: "fourAdults", shot: "03e-results-4-adults"),
        .init(screen: "results", state: "solo4oct", shot: "03f-results-solo-4oct"),
        .init(screen: "results", state: "emptyDates", shot: "03g-results-empty-dates"),
        .init(screen: "tour", state: "default", shot: "04-tour"),
        .init(screen: "tour", state: "operatorCoral", shot: "04b-tour-operator-coral"),
        .init(screen: "tour", state: "favoriteToast", shot: "04c-tour-favorite-toast"),
        .init(screen: "tour", state: "t2", shot: "04d-tour-t2"),
        .init(screen: "tour", state: "fourAdults", shot: "04e-tour-4-adults"),
        .init(screen: "tour", state: "includedOpen", shot: "04f-tour-included-open"),
        .init(screen: "tour", state: "compare", shot: "04g-tour-compare-sheet"),
        .init(screen: "payment", state: "default", shot: "05-payment"),
        .init(screen: "payment", state: "card", shot: "05b-payment-card"),
        .init(screen: "payment", state: "processing", shot: "05c-payment-processing"),
        .init(screen: "payment", state: "failure", shot: "05d-payment-failure"),
        .init(screen: "payment", state: "lockSoon", shot: "05e-payment-lock-soon"),
        .init(screen: "payment", state: "installment", shot: "05f-payment-installment"),
        .init(screen: "payment", state: "cardInvalid", shot: "05g-payment-card-invalid"),
        .init(screen: "payment", state: "fourAdults", shot: "05h-payment-4-adults"),
        .init(screen: "success", state: "default", shot: "06-success"),
        .init(screen: "success", state: "fourAdults", shot: "06b-success-4-adults"),
        .init(screen: "favorites", state: "default", shot: "07-favorites"),
        .init(screen: "favorites", state: "empty", shot: "07b-favorites-empty"),
        .init(screen: "favorites", state: "destinations", shot: "07c-favorites-destinations"),
        .init(screen: "profile", state: "default", shot: "08-profile"),
    ]

    public let entry: Entry
    let tab: HTTab
    let path: [AppRoute]
    let favorites: Set<String>
    /// Демо-«сейчас» в момент запуска (таймеры идут живыми от этой точки).
    let clockStart: Date
    /// Экран верхнего маршрута стека в нужном состоянии.
    let topScreen: AnyView?
    /// Содержимое вкладки вместо стандартного (избранное на вкладке «Направления»).
    let tabScreen: AnyView?

    /// Разбор `-demoScreen` / `-demoState` (аргументы вида `-key value` попадают в UserDefaults).
    @MainActor public static let current: DemoLaunch? = {
        let defaults = UserDefaults.standard
        guard let screen = defaults.string(forKey: "demoScreen") else { return nil }
        let state = defaults.string(forKey: "demoState") ?? "default"
        guard let entry = entries.first(where: { $0.screen == screen && $0.state == state }) else {
            print("DemoLaunch: неизвестный кадр \(screen)/\(state); доступны: "
                  + entries.map { "\($0.screen)/\($0.state)" }.joined(separator: ", "))
            return nil
        }
        return make(entry)
    }()

    @MainActor private static func make(_ entry: Entry) -> DemoLaunch {
        let f = DemoFixtures.self
        let t1 = MockData.t1
        var tab = HTTab.home
        var path: [AppRoute] = []
        var favorites = MockData.defaultFavorites
        var clock = MockData.referenceDate
        var top: AnyView?
        var tabScreen: AnyView?
        let toResults: [AppRoute] = [.results(MockData.defaultQuery)]
        let toTour: [AppRoute] = toResults + [.tour(t1)]

        switch (entry.screen, entry.state) {
        case ("home", "timerLastMinute"): clock = MockData.selectionDeadline.addingTimeInterval(-42)
        case ("home", "timerZero"): clock = MockData.selectionDeadline.addingTimeInterval(1)
        case ("home", _): break

        case ("search", let state):
            let query = state == "empty" ? f.noDestination : MockData.defaultQuery
            path = [.search(query)]
            switch state {
            case "datesSheet": top = AnyView(SearchScreen(query: query, sheet: .dates))
            case "budgetSheet": top = AnyView(SearchScreen(query: query, sheet: .budget))
            default: break
            }

        case ("results", let state):
            let query: SearchQuery = switch state {
            case "empty": f.emptyBudget
            case "hot": MockData.allHotQuery
            case "fourAdults": f.fourAdults
            case "solo4oct": f.soloDates
            case "emptyDates": f.noDates
            default: MockData.defaultQuery
            }
            path = [.results(query)]
            if state == "favoriteToast" {
                favorites.insert(t1.id)
                top = AnyView(ResultsScreen(query: query, toastTour: t1))
            }

        case ("tour", let state):
            path = toTour
            switch state {
            case "operatorCoral":
                top = AnyView(TourDetailScreen(tour: t1, operatorID: f.coral.id))
            case "favoriteToast":
                favorites.insert(t1.id)
                top = AnyView(TourDetailScreen(tour: t1, toastVisible: true))
            case "t2":
                path = toResults + [.tour(MockData.t2)]
            case "fourAdults":
                path = [.results(f.fourAdults), .tour(f.belekFour)]
            case "includedOpen":
                top = AnyView(TourDetailScreen(tour: t1, openIncluded: .hotel))
            case "compare":
                top = AnyView(TourDetailScreen(tour: t1, comparing: true))
            default: break
            }

        case ("payment", let state):
            path = toTour + [.payment(t1, t1.bestOffer)]
            let best = t1.bestOffer
            switch state {
            case "card":
                top = AnyView(PaymentScreen(tour: t1, offer: best, method: .card, cardNumber: f.validCard, expiry: f.cardExpiry))
            case "processing":
                top = AnyView(PaymentScreen(tour: t1, offer: best, payState: .processing))
            case "failure":
                top = AnyView(PaymentScreen(tour: t1, offer: best, method: .card, cardNumber: MockData.declinedCard,
                                            expiry: f.cardExpiry, payState: .failure))
            case "lockSoon":
                top = AnyView(PaymentScreen(tour: t1, offer: best, lockElapsed: f.lockSoonElapsed))
            case "installment":
                path = toTour + [.payment(t1, f.coral)]
                top = AnyView(PaymentScreen(tour: t1, offer: f.coral, method: .installment))
            case "cardInvalid":
                top = AnyView(PaymentScreen(tour: t1, offer: best, method: .card, cardNumber: f.typoCard, expiry: f.cardExpiry))
            case "fourAdults":
                path = [.results(f.fourAdults), .tour(f.belekFour), .payment(f.belekFour, f.belekFour.bestOffer)]
                top = AnyView(PaymentScreen(tour: f.belekFour, offer: f.belekFour.bestOffer, method: .installment))
            default: break
            }

        case ("success", let state):
            if state == "fourAdults" {
                path = [.results(f.fourAdults), .tour(f.belekFour),
                        .success(MockData.booking(f.belekFour, f.belekFour.bestOffer, f.installment))]
            } else {
                path = toTour + [.success(MockData.sampleBooking)]
            }

        case ("favorites", let state):
            tab = .favorites
            if state == "empty" { favorites = [] }
            if state == "destinations" {
                tabScreen = AnyView(FavoritesScreen(tours: MockData.allTours.filter { favorites.contains($0.id) },
                                                    segment: .destinations))
            }

        case ("profile", _): tab = .profile
        default: break
        }
        return DemoLaunch(entry: entry, tab: tab, path: path, favorites: favorites, clockStart: clock,
                          topScreen: top, tabScreen: tabScreen)
    }

    /// Роутер в начальном состоянии кадра; заодно ставит демо-часы.
    @MainActor func makeRouter() -> AppRouter {
        DemoClock.start = clockStart
        let router = AppRouter(selectedTab: tab, path: path, favorites: favorites)
        router.demoTabScreen = tabScreen
        return router
    }

    /// Подмена экрана для маршрута: только для верхнего маршрута кадра.
    @MainActor func screen(for route: AppRoute) -> AnyView? {
        route == path.last ? topScreen : nil
    }
}

/// Данные состояний, общие для каталога снапшотов и демо-запуска.
@MainActor enum DemoFixtures {
    static var coral: OperatorOffer { MockData.t1.offers.first { $0.tourOperator == MockData.coral }! }
    /// Карта, которая проходит проверку Луна (Uzcard), и та же с опечаткой в последней цифре.
    static let validCard = "8600 1234 5678 9012"
    static let typoCard = "8600 1234 5678 9011"
    static let cardExpiry = "08/28"
    /// Замок цены: осталось 2:59 — над CTA появляется предупреждение.
    static let lockSoonElapsed = MockData.priceLockDuration - (2 * 60 + 59)
    /// «Куда» не выбрано: «Найти туры» неактивна (P1-8).
    static var noDestination: SearchQuery {
        var q = MockData.defaultQuery
        q.destination = nil
        return q
    }
    /// Бюджет на минимуме — пустая выдача по бюджету.
    static var emptyBudget: SearchQuery {
        var q = MockData.defaultQuery
        q.budget = MockData.budgetRange.lowerBound
        return q
    }
    /// Выбор в пикерах: 4 взрослых на Анталью (бюджет — весь диапазон: он считается за всех туристов).
    static var fourAdults: SearchQuery {
        var q = MockData.defaultQuery
        q.adults = 4
        q.budget = MockData.budgetRange.upperBound
        return q
    }
    /// Любое направление, вылет с 4 окт, 3–5 ночей, 1 взрослый.
    static var soloDates: SearchQuery {
        SearchQuery(destination: nil, dateFrom: MockData.date(10, 4), nights: 4, adults: 1,
                    budget: MockData.budgetRange.upperBound, hotOnly: true)
    }
    /// Анталья, 9–11 ночей: таких туров нет — пустое состояние по датам.
    static var noDates: SearchQuery {
        var q = MockData.defaultQuery
        q.nights = 10
        q.budget = MockData.budgetRange.upperBound
        return q
    }
    /// На четверых — Belek Pine Club: в нём 4 места (Lara Sands с 3 местами четверым не продаётся).
    static var belekFour: Tour { MockData.search(fourAdults).first { $0.id == "a1" }! }
    static var installment: PaymentMethod { MockData.paymentMethods.first { $0.kind == .installment }! }
}
