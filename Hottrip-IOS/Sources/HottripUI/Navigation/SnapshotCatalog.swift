import SwiftUI

/// Реестр экранов и ключевых состояний интеракций для снапшот-утилиты. Новый кадр = одна запись.
public struct SnapshotEntry {
    public let name: String
    /// Светлый статус-бар (для тёмных экранов).
    public let darkStatusBar: Bool
    /// Дополнительно рендерить «full»-версию на всю высоту контента.
    public let renderFull: Bool
    public let view: AnyView
}

@MainActor
public enum SnapshotCatalog {
    public static var entries: [SnapshotEntry] {
        let t1 = MockData.t1
        let deadline = MockData.selectionDeadline
        let f = DemoFixtures.self
        let coral = f.coral
        let fourAdults = f.fourAdults
        let belekFour = f.belekFour

        func e<V: View>(_ name: String, dark: Bool = false, full: Bool = true, now: Date = MockData.referenceDate,
                        favorites: Set<String> = MockData.defaultFavorites, _ v: V) -> SnapshotEntry {
            SnapshotEntry(name: name, darkStatusBar: dark, renderFull: full,
                          view: AnyView(v.environment(AppRouter(favorites: favorites)).environment(\.htNow, now)))
        }

        return [
            e("01-home", dark: true, full: false, TabShell(selected: .home)),
            e("01b-home-timer-last-minute", dark: true, full: false, now: deadline.addingTimeInterval(-42), TabShell(selected: .home)),
            e("01c-home-timer-zero", dark: true, full: false, now: deadline.addingTimeInterval(1), TabShell(selected: .home)),
            e("02-search", SearchScreen()),
            e("02b-search-dates-sheet", full: false, SnapshotSheet(height: SnapshotSheetMetrics.height(HTSize.datesSheet)) {
                DatesPicker(query: .constant(MockData.defaultQuery)) {}
            }),
            e("02c-search-budget-sheet", full: false, SnapshotSheet(height: SnapshotSheetMetrics.height(HTSize.budgetSheet)) {
                BudgetPicker(query: .constant(MockData.defaultQuery)) {}
            }),
            e("02d-search-empty-destination", full: false, SearchScreen(query: f.noDestination)),
            e("03-results", ResultsScreen(query: MockData.defaultQuery)),
            e("03b-results-empty", full: false, ResultsScreen(query: f.emptyBudget)),
            e("03c-results-favorite-toast", full: false, favorites: MockData.defaultFavorites.union([t1.id]),
              ResultsScreen(query: MockData.defaultQuery, toastTour: t1)),
            e("03d-results-hot", ResultsScreen(query: MockData.allHotQuery)),
            e("03e-results-4-adults", ResultsScreen(query: fourAdults)),
            e("03f-results-solo-4oct", full: false, ResultsScreen(query: f.soloDates)),
            e("03g-results-empty-dates", full: false, ResultsScreen(query: f.noDates)),
            e("04-tour", dark: true, TourDetailScreen(tour: t1)),
            e("04b-tour-operator-coral", dark: true, TourDetailScreen(tour: t1, operatorID: coral.id)),
            e("04c-tour-favorite-toast", dark: true, full: false, favorites: MockData.defaultFavorites.union([t1.id]),
              TourDetailScreen(tour: t1, toastVisible: true)),
            e("04d-tour-t2", dark: true, full: false, TourDetailScreen(tour: MockData.t2)),
            e("04e-tour-4-adults", dark: true, full: false, TourDetailScreen(tour: belekFour)),
            e("04f-tour-included-open", dark: true, full: false, TourDetailScreen(tour: t1, openIncluded: .hotel)),
            e("05-payment", PaymentScreen(tour: t1, offer: t1.bestOffer)),
            e("05b-payment-card", PaymentScreen(tour: t1, offer: t1.bestOffer, method: .card,
                                                cardNumber: f.validCard, expiry: f.cardExpiry)),
            e("05c-payment-processing", full: false, PaymentScreen(tour: t1, offer: t1.bestOffer, payState: .processing)),
            e("05d-payment-failure", full: false, PaymentScreen(tour: t1, offer: t1.bestOffer, method: .card,
                                                                cardNumber: MockData.declinedCard, expiry: f.cardExpiry, payState: .failure)),
            e("05e-payment-lock-soon", full: false, PaymentScreen(tour: t1, offer: t1.bestOffer, lockElapsed: f.lockSoonElapsed)),
            e("05f-payment-installment", PaymentScreen(tour: t1, offer: coral, method: .installment)),
            e("05g-payment-card-invalid", PaymentScreen(tour: t1, offer: t1.bestOffer, method: .card,
                                                        cardNumber: f.typoCard, expiry: f.cardExpiry)),
            e("05h-payment-4-adults", full: false, PaymentScreen(tour: belekFour, offer: belekFour.bestOffer, method: .installment)),
            e("06-success", full: false, SuccessScreen(booking: MockData.sampleBooking)),
            e("06b-success-4-adults", full: false,
              SuccessScreen(booking: MockData.booking(belekFour, belekFour.bestOffer, f.installment))),
            e("07-favorites", TabShell(selected: .favorites)),
            e("07b-favorites-empty", full: false, favorites: [], TabShell(selected: .favorites)),
            e("07c-favorites-destinations", full: false,
              FavoritesScreen(tours: MockData.allTours.filter { MockData.defaultFavorites.contains($0.id) }, segment: .destinations)),
            e("08-profile", TabShell(selected: .profile)),
        ]
    }
}

/// Кадр sheet для снапшота: `.sheet` в ImageRenderer не презентуется, поэтому поиск под затемнением,
/// поверх — сам picker в карточке r 28 с грабером.
struct SnapshotSheet<Content: View>: View {
    let height: CGFloat
    let content: Content

    init(height: CGFloat, @ViewBuilder content: () -> Content) {
        self.height = height; self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SearchScreen()
            HTColor.ink.opacity(SnapshotSheetMetrics.dim)
            content
                .padding(.bottom, HTDevice.safeArea.bottom)
                .frame(maxWidth: .infinity)
                .frame(height: height, alignment: .top)
                .background(HTColor.surface)
                .overlay(alignment: .top) {
                    Capsule().fill(HTColor.line)
                        .frame(width: SnapshotSheetMetrics.grabber.width, height: SnapshotSheetMetrics.grabber.height)
                        .padding(.top, SnapshotSheetMetrics.grabberTop)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: HTRadius.sheet, topTrailingRadius: HTRadius.sheet, style: .continuous))
        }
    }
}

/// Размеры системного sheet iOS для кадра-имитации.
enum SnapshotSheetMetrics {
    /// Detent `.height(h)`: h — высота содержимого над нижней safe area.
    static func height(_ detent: CGFloat) -> CGFloat { detent + HTDevice.safeArea.bottom }
    static let grabber = CGSize(width: 36, height: 5)
    static let grabberTop: CGFloat = 5
    static let dim = 0.35
}
