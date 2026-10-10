import SwiftUI

/// Поиск «Куда хотите поехать?» (spec-iter07 §2): три поля-карточки, «Найти туры», три популярных направления
/// и промо-баннер с 3D-фигурой. Полноэкранный, без таб-бара. Вылет из Ташкента и туристы — в sheet «Даты».
public struct SearchScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htSafeArea) private var safe
    @Environment(\.htReduceMotion) private var reduceMotion
    @State private var query: SearchQuery
    @State private var sheet: Sheet?
    /// Поле «Куда» один раз подсвечивается после выбора популярного направления (P1-8).
    @State private var flashDestination = false

    /// Какой sheet открыт (демо-запуск открывает его сразу).
    public enum Sheet: String, Identifiable, Sendable {
        case destination, dates, budget
        public var id: String { rawValue }
    }

    public init(query: SearchQuery = MockData.defaultQuery, sheet: Sheet? = nil) {
        _query = State(initialValue: query)
        _sheet = State(initialValue: sheet)
    }

    public var body: some View {
        HTScreen {
            HTScroll {
                VStack(alignment: .leading, spacing: 0) {
                    HTBackButton()
                    Text("Куда хотите\nпоехать?")
                        .htStyle(.h1).foregroundStyle(HTColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 6)
                    Text("Выберите направление, бюджет и даты, чтобы найти свой идеальный тур.")
                        .htStyle(.callout).foregroundStyle(HTColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, HTSpace.s20)
                        .padding(.top, 6)
                    fields.padding(.top, HTSpace.s12)
                    HTPrimaryButton(haptic: true, action: { router.push(.results(query)) }) {
                        HTButtonTitle(title: "Найти туры", arrow: true)
                    }
                    .disabled(query.destination == nil)
                    .accessibilityIdentifier("search.find")
                    .padding(.top, HTSpace.s20)
                    Text("Популярные направления").htStyle(.h3).foregroundStyle(HTColor.ink)
                        .padding(.top, 30)
                    popular.padding(.top, HTSpace.s8)
                    promo.padding(.top, HTSpace.s16)
                }
                .htScreenPadding()
                .padding(.top, safe.top - 12)
                .padding(.bottom, safe.bottom)
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .destination:
                DestinationPicker(selected: query.destination) { picked in
                    withAnimation(HTMotion.fade) { query.destination = picked }
                    self.sheet = nil
                }
            case .dates:
                DatesPicker(query: $query) { self.sheet = nil; router.push(.results(query)) }
            case .budget:
                BudgetPicker(query: $query) { self.sheet = nil }
            }
        }
    }

    // MARK: Поля

    private var fields: some View {
        VStack(spacing: 6) {
            SearchField(id: "Куда", value: query.destination?.countryFirst, placeholder: "Куда поедем?",
                        focused: sheet == .destination || flashDestination, action: { sheet = .destination }) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: HTIcon.base, weight: .medium))
            }
            SearchField(id: "Даты", value: DatesPicker.windowTitle(query), placeholder: "Любые даты",
                        trailing: query.nightsRange.map(HTFormat.nightsRange), focused: sheet == .dates, action: { sheet = .dates }) {
                Image(systemName: "calendar").font(.system(size: HTIcon.base, weight: .medium))
            }
            SearchField(id: "Бюджет", value: "До \(HTFormat.uzs(query.budget))", placeholder: "",
                        focused: sheet == .budget, action: { sheet = .budget }) {
                HTCoinsIcon()
            }
        }
    }

    // MARK: Популярные направления

    private var popular: some View {
        HStack(spacing: HTSpace.s10) {
            ForEach(MockData.highlights) { item in
                let q = MockData.selectionQuery(item.destination, adults: query.adults)
                DestinationCard(title: item.country, imageName: item.imageName, fromPrice: MockData.fromPrice(q)) {
                    pick(item.destination)
                }
                .accessibilityIdentifier("search.popular.\(item.id)")
            }
        }
        .sensoryFeedback(.selection, trigger: query.destination)
    }

    /// Карточка направления подставляет его в «Куда» без перехода; поле подсвечивается на 0,6 с.
    private func pick(_ destination: Destination) {
        withAnimation(HTMotion.fade) {
            query.destination = destination
            flashDestination = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(HTMotion.fieldFlash))
            withAnimation(reduceMotion ? HTMotion.crossfade : HTMotion.fade) { flashDestination = false }
        }
    }

    // MARK: Промо

    private var promo: some View {
        Button { router.push(.results(MockData.allHotQuery)) } label: {
            ZStack(alignment: .topLeading) {
                PromoBackground()
                    .frame(height: HTSize.promoBanner)
                    .padding(.top, HTSize.promoOverhang)
                VStack(alignment: .leading, spacing: HTSpace.s16) {
                    Text("Горящие туры\nуже ждут тебя")
                        .htStyle(HTTextStyle(20, 24, .semibold))
                        .foregroundStyle(HTColor.ink)
                        .fixedSize()
                    Image(systemName: "arrow.right").font(.system(size: HTIcon.large, weight: .semibold))
                        .foregroundStyle(HTColor.ink)
                }
                .padding(.leading, HTSpace.s20)
                .padding(.top, HTSize.promoOverhang + HTSpace.s28)
                HTObject3D(.wave)
                    .frame(width: HTSize.promo3D.width, height: HTSize.promo3D.height)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: HTSize.promoBanner + HTSize.promoOverhang, alignment: .top)
            // Фигура выходит за верх баннера на 12 pt (до карточек направлений остаётся 4 pt); снизу и справа обрезается по скруглению баннера.
            .clipShape(PromoClip())
            .contentShape(Rectangle())
        }
        .buttonStyle(HTPressStyle(scale: 0.98))
        .accessibilityLabel("Горящие туры уже ждут тебя")
        .accessibilityIdentifier("search.promo")
        .padding(.top, -HTSize.promoOverhang)
    }
}

/// Баннер r 24 и полоса над ним высотой `promoOverhang`, куда выходит 3D-фигура.
private struct PromoClip: Shape {
    func path(in rect: CGRect) -> Path {
        let top = HTSize.promoOverhang
        var p = Path(roundedRect: CGRect(x: rect.minX, y: rect.minY + top, width: rect.width, height: rect.height - top),
                     cornerRadius: HTRadius.banner, style: .continuous)
        p.addRect(CGRect(x: rect.minX + HTRadius.banner, y: rect.minY, width: rect.width - HTRadius.banner, height: top + HTRadius.banner))
        return p
    }
}

/// Фон промо: градиент мята → голубой → синий под 120° и лаймовый блик справа снизу.
private struct PromoBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(stops: [.init(color: Color(hex: 0xC9F5E4), location: 0),
                                   .init(color: Color(hex: 0x7FB8FF), location: 0.55),
                                   .init(color: HTColor.azure, location: 1)],
                           startPoint: .bottomLeading, endPoint: .topTrailing)
            RadialGradient(colors: [HTColor.lime.opacity(0.45), HTColor.lime.opacity(0)],
                           center: .bottomTrailing, startRadius: 0, endRadius: 160)
        }
    }
}

/// Поле-карточка поиска 50 pt: иконка, значение, справа подпись. Активное поле — лаймовая обводка.
struct SearchField<Icon: View>: View {
    let id: String
    let value: String?
    let placeholder: String
    var trailing: String? = nil
    let focused: Bool
    let action: () -> Void
    @ViewBuilder let icon: Icon

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: HTRadius.field, style: .continuous)
        Button(action: action) {
            HStack(spacing: 0) {
                icon.foregroundStyle(HTColor.ink).frame(width: 20)
                Text(value ?? placeholder)
                    .htStyle(.bodyStrong)
                    .foregroundStyle(value == nil ? HTColor.ink3 : HTColor.ink)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .padding(.leading, HTSpace.s16)
                Spacer(minLength: HTSpace.s8)
                if let trailing {
                    Text(trailing).htStyle(.bodyS).foregroundStyle(HTColor.ink2).contentTransition(.opacity)
                }
            }
            .padding(.leading, HTSpace.s16)
            .padding(.trailing, HTSpace.s20)
            .frame(height: HTSize.field)
            .background(HTColor.surface, in: shape)
            .overlay(shape.strokeBorder(focused ? HTColor.lime : HTColor.line,
                                        lineWidth: focused ? 2 : HTSize.hairline))
            .htShadow(.card)
            .contentShape(shape)
        }
        .buttonStyle(HTPressStyle(scale: 0.99))
        .animation(HTMotion.fade, value: focused)
        .animation(HTMotion.fade, value: value)
        .accessibilityIdentifier("search.field.\(id)")
    }
}

// MARK: - Sheets

/// Оформление sheet (spec-iter07 §5.5): белый, r 28, грабер.
extension View {
    func htSheet(height: CGFloat) -> some View {
        self
            .htScreenPadding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(HTColor.surface)
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(HTRadius.sheet)
    }
}

/// Даты (sheet поля «Даты»): первый день окна вылета, ночи, туристы; CTA с живым числом туров.
struct DatesPicker: View {
    @Environment(\.htReduceMotion) private var reduceMotion
    @Binding var query: SearchQuery
    let onShow: () -> Void

    static let days = [MockData.date(10, 1), MockData.date(10, 3), MockData.date(10, 4), MockData.date(10, 5), MockData.date(10, 7)]
    static let nights = [4, 7, 10]
    static let adults = 1...4

    /// «3 окт – 10 окт» — окно вылета запроса.
    static func windowTitle(_ q: SearchQuery) -> String? {
        guard let from = q.dateFrom, let to = q.dateTo else { return nil }
        return HTFormat.longRange(from, to)
    }

    /// «Вылет 3–10 окт · вернётесь до 18 окт».
    static func returnSummary(_ q: SearchQuery) -> String? {
        guard let from = q.dateFrom, let to = q.dateTo else { return nil }
        let window = "Вылет \(HTFormat.shortRange(from, to))"
        guard let nights = q.nightsRange,
              let back = Calendar.tashkent.date(byAdding: .day, value: nights.upperBound, to: to) else { return window }
        return "\(window) · вернётесь до \(HTFormat.dayMonth(back))"
    }

    static func noSeatsTitle(_ adults: Int) -> String { "Не хватает мест на \(HTFormat.adults(adults))" }

    private var count: Int { MockData.search(query).count }

    /// Подпись неактивной CTA: причина пустоты.
    private var emptyTitle: String {
        switch MockData.emptyReason(query) {
        case .budget: "Все туры дороже бюджета"
        case .seats: Self.noSeatsTitle(query.adults)
        case .dates, nil: "На эти даты туров нет"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Даты").htStyle(.title).foregroundStyle(HTColor.ink).padding(.top, HTSpace.s28)
            label("Вылет с")
            chips([nil] + Self.days.map(Optional.some), selected: .some(query.dateFrom),
                  title: { $0.map(HTFormat.weekdayDay) ?? "Любые" }) { query.dateFrom = $0 }
            label("Ночей")
            chips(Self.nights, selected: query.nights, title: { HTFormat.nightsRange(SearchQuery.nightsRange(around: $0)) }) {
                query.nights = $0
            }
            travelers.padding(.top, HTSpace.s16)
            if let summary = Self.returnSummary(query) {
                Text(summary).htStyle(.bodyS).foregroundStyle(HTColor.ink2).padding(.top, HTSpace.s12)
            }
            Spacer(minLength: HTSpace.s16)
            HTPrimaryButton(action: onShow) {
                HTButtonTitle(title: count > 0 ? "Показать \(HTFormat.tours(count))" : emptyTitle, arrow: count > 0)
                    .contentTransition(.numericText(value: Double(count)))
                    .htAnimation(HTMotion.price, value: count, reduceMotion: reduceMotion)
            }
            .disabled(count == 0)
            .accessibilityIdentifier("dates.show")
            .padding(.bottom, HTSpace.s24)
        }
        .animation(reduceMotion ? nil : HTMotion.select, value: query)
        .htSheet(height: HTSize.datesSheet)
    }

    private func label(_ text: String) -> some View {
        Text(text).htStyle(.footnote).foregroundStyle(HTColor.ink2).padding(.top, HTSpace.s16).padding(.bottom, HTSpace.s4)
    }

    private var travelers: some View {
        HStack {
            Text("Туристы").htStyle(.body).foregroundStyle(HTColor.ink)
            Spacer()
            stepButton("minus", enabled: query.adults > Self.adults.lowerBound) { query.adults -= 1 }
            Text(HTFormat.adults(query.adults)).htStyle(.bodyStrong).monospacedDigit().foregroundStyle(HTColor.ink)
                .frame(minWidth: 104)
                .contentTransition(.numericText(value: Double(query.adults)))
            stepButton("plus", enabled: query.adults < Self.adults.upperBound) { query.adults += 1 }
        }
        .padding(.horizontal, HTSpace.s12)
        .frame(height: 56)
        .background(HTColor.canvasBottom, in: RoundedRectangle(cornerRadius: HTRadius.field, style: .continuous))
        .sensoryFeedback(.selection, trigger: query.adults)
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: HTIcon.small, weight: .semibold))
                .foregroundStyle(enabled ? HTColor.ink : HTColor.ink3)
                .frame(width: 36, height: 36)
                .background(HTColor.surface, in: Circle())
                .overlay(Circle().strokeBorder(HTColor.line, lineWidth: HTSize.hairline))
                .frame(width: HTSize.hitArea, height: HTSize.hitArea)
                .contentShape(Circle())
        }
        .buttonStyle(HTPressStyle(scale: 0.94))
        .disabled(!enabled)
        .accessibilityIdentifier("travelers.\(icon)")
    }

    private func chips<T: Hashable>(_ items: [T], selected: T?, title: @escaping (T) -> String,
                                    onSelect: @escaping (T) -> Void) -> some View {
        // Лента во всю ширину sheet: следующий чип выглядывает из-за края — видно, что ленту можно листать.
        HTChipRail(items, selected: selected, accent: .lime, title: title, onSelect: onSelect)
            .padding(.horizontal, -HTSpace.screen)
    }
}

/// Бюджет (sheet поля «Бюджет»): сумма, слайдер, честная подсказка, «Готово».
struct BudgetPicker: View {
    @Environment(\.htReduceMotion) private var reduceMotion
    @Binding var query: SearchQuery
    let onDone: () -> Void

    private static let lowBudget = 4_000_000

    private var hint: String? {
        let found = MockData.search(query).count
        guard query.budget < Self.lowBudget || found == 0 else { return "Под этот бюджет \(HTFormat.tours(found))" }
        switch MockData.emptyReason(query) {
        case .budget(let nearest): return "Под этот бюджет туров нет. Ближайший — от \(HTFormat.uzs(nearest))"
        case .seats: return DatesPicker.noSeatsTitle(query.adults)
        case .dates: return "На эти даты туров нет — бюджет ни при чём, сдвиньте вылет"
        case nil: return "Под этот бюджет \(HTFormat.tours(found))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Бюджет").htStyle(.title).foregroundStyle(HTColor.ink).padding(.top, HTSpace.s28)
            Text("До \(HTFormat.uzs(query.budget))")
                .htStyle(.priceM).foregroundStyle(HTColor.ink)
                .contentTransition(.numericText(value: Double(query.budget)))
                .htAnimation(HTMotion.price, value: query.budget, reduceMotion: reduceMotion)
                .padding(.top, HTSpace.s16)
            HTBudgetSlider(value: $query.budget, range: MockData.budgetRange).padding(.top, HTSpace.s16)
            HStack {
                Text(HTFormat.millions(MockData.budgetRange.lowerBound))
                Spacer()
                Text(HTFormat.millions(MockData.budgetRange.upperBound))
            }
            .htStyle(.caption).foregroundStyle(HTColor.ink3)
            if let hint {
                Text(hint).htStyle(.bodyS).foregroundStyle(HTColor.ink2).padding(.top, HTSpace.s12)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: HTSpace.s16)
            HTPrimaryButton("Готово", action: onDone)
                .accessibilityIdentifier("budget.done")
                .padding(.bottom, HTSpace.s24)
        }
        .htSheet(height: HTSize.budgetSheet)
    }
}

/// Слайдер бюджета: трек `line`, заполнение `lime`, белая ручка с тенью. Деления — на целых миллионах.
struct HTBudgetSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    private static let step = 500_000

    var body: some View {
        GeometryReader { g in
            let knob = HTSize.sliderKnob
            let travel = g.size.width - knob
            let fraction = CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                Capsule().fill(HTColor.line).frame(height: HTSize.sliderTrack)
                Capsule().fill(HTColor.lime).frame(width: knob / 2 + travel * fraction, height: HTSize.sliderTrack)
                Circle()
                    .fill(HTColor.surface)
                    .overlay(Circle().strokeBorder(HTColor.line, lineWidth: HTSize.hairline))
                    .htShadow(.raised)
                    .frame(width: knob, height: knob)
                    .offset(x: travel * fraction)
            }
            .frame(height: HTSize.hitArea)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let f = min(max((drag.location.x - knob / 2) / travel, 0), 1)
                let raw = Double(range.lowerBound) + Double(f) * Double(range.upperBound - range.lowerBound)
                value = Int((raw / Double(Self.step)).rounded()) * Self.step
            })
        }
        .frame(height: HTSize.hitArea)
        .sensoryFeedback(.selection, trigger: value / 1_000_000)
        .accessibilityElement()
        .accessibilityLabel("Бюджет")
        .accessibilityValue(HTFormat.uzs(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + Self.step)
            case .decrement: value = max(range.lowerBound, value - Self.step)
            @unknown default: break
            }
        }
    }
}

/// Выбор направления (sheet поля «Куда»).
struct DestinationPicker: View {
    let selected: Destination?
    let onPick: (Destination?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Куда").htStyle(.title).foregroundStyle(HTColor.ink)
                .padding(.top, HTSpace.s28).padding(.bottom, HTSpace.s16)
            VStack(spacing: 0) {
                row(nil, title: "Любая страна")
                ForEach(MockData.destinations) { d in row(d, title: d.countryFirst) }
            }
            .htCard(radius: HTRadius.card, stroke: true, shadow: nil)
            Spacer()
        }
        .htSheet(height: 520)
    }

    private func row(_ d: Destination?, title: String) -> some View {
        Button { onPick(d) } label: {
            HStack {
                Text(title).htStyle(.body).foregroundStyle(HTColor.ink)
                Spacer()
                HTRadio(d == selected)
            }
            .padding(.horizontal, HTSpace.s16)
            .frame(height: 52)
            .overlay(alignment: .bottom) { HTHairline().padding(.leading, HTSpace.s16) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
