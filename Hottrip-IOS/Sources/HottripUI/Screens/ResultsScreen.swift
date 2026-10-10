import SwiftUI

/// Результаты поиска (spec-iter07 §5.1): шапка с направлением и датами, сортировка, свежесть цен, карточки туров.
/// Карточка — источник зум-перехода в тур (P0-4).
public struct ResultsScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htSafeArea) private var safe
    @Environment(\.htReduceMotion) private var reduceMotion
    @Environment(\.htRenderMode) private var mode
    @State private var query: SearchQuery
    @State private var sort: SortOrder = .cheaper
    @State private var updatedAt: Date
    @State private var toastTour: Tour?
    @State private var toastVisible = false
    @State private var pickingDates = false

    public init(query: SearchQuery, updatedAt: Date = MockData.pricesUpdatedAt, toastTour: Tour? = nil) {
        _query = State(initialValue: query)
        _updatedAt = State(initialValue: updatedAt)
        _toastTour = State(initialValue: toastTour)
        _toastVisible = State(initialValue: toastTour != nil)
    }

    private var title: String { query.destination?.city ?? "Горящие туры" }
    private var tours: [Tour] { MockData.search(query, sort: sort) }

    public var body: some View {
        HTScreen {
            VStack(spacing: 0) {
                HTNavBar {
                    VStack(spacing: 2) {
                        Text(title).htStyle(.title).foregroundStyle(HTColor.ink)
                        // Даты и туристы — те же, по которым отфильтрована выдача и посчитаны цены.
                        Text(HTFormat.querySummary(query))
                            .htStyle(.footnote).foregroundStyle(HTColor.ink2)
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                } trailing: {
                    Button { pickingDates = true } label: {
                        HTGlassSquare { Image(systemName: "slider.horizontal.3") }
                            .htShadow(.card) // на светлом фоне без тени кнопка сливалась с ним
                    }
                    .buttonStyle(HTPressStyle(scale: 0.94))
                    .accessibilityLabel("Фильтры")
                }
                .padding(.top, safe.top - 2)
                HTScroll {
                    HTChipRail(SortOrder.allCases, selected: sort, title: \.title) { value in
                        withAnimation(reduceMotion ? nil : HTMotion.select) { sort = value }
                    }
                    .padding(.top, HTSpace.s12)
                    if tours.isEmpty { emptyState } else { list }
                }
                .refreshable {
                    try? await Task.sleep(for: .milliseconds(800))
                    withAnimation(HTMotion.fade) { updatedAt = DemoClock.now() }
                }
            }
        } bar: {
            if toastVisible, toastTour != nil {
                HTFavoriteToast {
                    if let toastTour { router.toggleFavorite(toastTour) }
                    withAnimation(HTMotion.fade) { toastVisible = false }
                }
                .padding(.bottom, safe.bottom)
                .transition(HTFavoriteToast.transition(reduceMotion: reduceMotion))
            }
        }
        .htToastAutoHide($toastVisible, key: toastTour?.id, mode: mode, reduceMotion: reduceMotion)
        .sheet(isPresented: $pickingDates) { DatesPicker(query: $query) { pickingDates = false } }
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Нашли \(HTFormat.tours(tours.count))").htStyle(.bodyS).foregroundStyle(HTColor.ink2)
                Spacer()
                HTClock(period: 60) { now in
                    Text(freshness(now)).htStyle(.footnote).foregroundStyle(HTColor.ink3)
                        .contentTransition(.opacity)
                }
            }
            .padding(.top, HTSpace.s8)
            HTLazyVStack(spacing: HTSpace.s16) {
                ForEach(tours) { tour in
                    ResultCard(tour: tour, onFavorite: { favoriteChanged(tour, isFavorite: $0) }) {
                        router.push(.tour(tour))
                    }
                }
            }
            .padding(.top, HTSpace.s12)
        }
        .htScreenPadding()
        .padding(.bottom, safe.bottom + HTSpace.s32)
    }

    private func favoriteChanged(_ tour: Tour, isFavorite: Bool) {
        toastTour = tour
        withAnimation(reduceMotion ? HTMotion.fade : HTMotion.toast) { toastVisible = isFavorite }
    }

    private func freshness(_ now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(updatedAt) / 60)
        return minutes < 1 ? "обновлено только что" : "обновлено \(minutes) мин назад"
    }

    private var hotWord: String { query.hotOnly ? "горящих " : "" }

    private var emptyState: some View {
        let reason = MockData.emptyReason(query)
        let message: String = switch reason {
        case .budget(let nearest): "Под этот бюджет \(hotWord)туров нет. Ближайший вариант — от \(HTFormat.uzs(nearest))."
        case .seats: "В \(hotWord)турах на эти даты не хватает мест на \(HTFormat.adults(query.adults)). Попробуйте другие даты."
        case .dates, nil: "На эти даты \(hotWord)туров нет. Сдвиньте вылет или измените число ночей."
        }
        return HTEmptyState("Ничего не нашли", message: message) {
            if case .budget(let nearest) = reason {
                let raised = nearest.roundedUp(to: 1_000_000)
                HTSecondaryButton("Поднять бюджет до \(HTFormat.millions(raised))") { query.budget = raised }
            } else {
                HTSecondaryButton("Изменить даты") { pickingDates = true }
            }
        }
        .htScreenPadding()
        .padding(.top, 96)
    }
}

extension Int {
    func roundedUp(to step: Int) -> Int { (self + step - 1) / step * step }
}
