import SwiftUI

/// Карточка тура (spec-iter07 §3): фото-галерея 404 pt, на ней бейдж, точки, название, мета, рейтинг и цена;
/// белый шит с «Входит в стоимость» и сравнением туроператоров; липкая CTA «Забронировать».
/// Цена в шапке и CTA читаются из одного `selected`.
public struct TourDetailScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htSafeArea) private var safe
    @Environment(\.htReduceMotion) private var reduceMotion
    @Environment(\.htRenderMode) private var mode
    @Namespace private var selectionSpace
    @Namespace private var dotSpace

    let tour: Tour
    @State private var selected: OperatorOffer
    @State private var photoIndex = 0
    @State private var toastVisible: Bool
    @State private var openIncluded: IncludedItem.Kind?
    @State private var comparing: Bool
    /// Цена в шапке видна на экране; иначе смена оператора подтверждается плашкой над CTA (P0-6).
    @State private var priceOnScreen = true
    @State private var operatorNote: OperatorOffer?

    public init(tour: Tour, operatorID: String? = nil, toastVisible: Bool = false,
                openIncluded: IncludedItem.Kind? = nil, comparing: Bool = false) {
        self.tour = tour
        _selected = State(initialValue: tour.offers.first { $0.id == operatorID } ?? tour.bestOffer)
        _toastVisible = State(initialValue: toastVisible)
        _openIncluded = State(initialValue: openIncluded)
        _comparing = State(initialValue: comparing)
    }

    private var price: Int { selected.price }
    /// Цена на фото: 23 bold, как в референсе — строка «от … UZS · старая · −32%» помещается в 362 pt.
    private static let heroPrice = HTTextStyle(23, 28, .bold, tracking: -0.4)
    private var isBest: Bool { selected == tour.bestOffer }

    public var body: some View {
        HTScreen {
            HTScroll {
                hero
                sheet
            }
        } bar: {
            VStack(spacing: 0) {
                if toastVisible {
                    HTFavoriteToast {
                        router.toggleFavorite(tour)
                        withAnimation(HTMotion.fade) { toastVisible = false }
                    }
                    .transition(HTFavoriteToast.transition(reduceMotion: reduceMotion))
                }
                if let operatorNote {
                    OperatorNote(offer: operatorNote)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("tour.operatorNote")
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
                HTStickyBar(fade: HTColor.surface, bottom: safe.bottom - HTSpace.s16) {
                    HTPrimaryButton("Забронировать", haptic: true) { router.push(.payment(tour, selected)) }
                        .accessibilityIdentifier("tour.book")
                }
            }
        }
        .htToastAutoHide($toastVisible, mode: mode, reduceMotion: reduceMotion)
        .task(id: operatorNote) {
            guard operatorNote != nil else { return }
            try? await Task.sleep(for: .seconds(HTMotion.operatorNoteDuration))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? HTMotion.fade : HTMotion.toast) { operatorNote = nil }
        }
        .sheet(isPresented: $comparing) {
            OperatorCompare(tour: tour, selected: selected) { offer in
                select(offer)
                comparing = false
            }
        }
    }

    // MARK: Фото

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            galleryPages
                .frame(height: HTSize.gallery)
                .frame(maxWidth: .infinity)
                .clipped()
                .htStretchOnPull(height: HTSize.gallery)
            // Скрим: сверху под строкой состояния и кнопками, снизу под текстом и ценой.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.3), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                Spacer(minLength: 0)
                LinearGradient(colors: [Color(hex: 0x06122E).opacity(0), Color(hex: 0x06122E).opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: HTSize.gallery - 200)
            }
            .frame(height: HTSize.gallery)
            .allowsHitTesting(false)
            topButtons.padding(.top, safe.top - 12)
            heroText.padding(.top, 196)
        }
        .frame(height: HTSize.gallery)
        .htStatusBarZone()
    }

    @ViewBuilder private var galleryPages: some View {
        #if os(iOS)
        if mode == .interactive {
            TabView(selection: $photoIndex) {
                ForEach(Array(tour.gallery.enumerated()), id: \.offset) { i, photo in
                    // Параллакс: фото отстаёт от края страницы на четверть сдвига (P0-5).
                    let parallax: CGFloat = reduceMotion ? 0 : 0.25
                    HTImage(photo.imageName)
                        .visualEffect { content, proxy in
                            content.offset(x: -proxy.frame(in: .global).minX * parallax)
                        }
                        .clipped()
                        .tag(i)
                        .accessibilityLabel(photo.caption)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else {
            HTImage(tour.gallery[photoIndex].imageName)
        }
        #else
        HTImage(tour.gallery[photoIndex].imageName)
        #endif
    }

    private var topButtons: some View {
        HStack(spacing: HTSpace.s6) {
            HTBackButton(color: .white, size: HTIcon.tab)
                .shadow(color: .black.opacity(0.25), radius: 3)
            Spacer()
            HTHeartButton(isFavorite: router.isFavorite(tour), action: toggleFavorite)
                .accessibilityIdentifier("tour.favorite")
            ShareLink(item: "Hottrip: \(tour.destination.countryFirst), \(tour.hotelTitle) — \(HTFormat.uzs(price))") {
                HTGlassSquare { Image(systemName: "square.and.arrow.up") }
            }
            .buttonStyle(HTPressStyle(scale: 0.94))
            .accessibilityLabel("Поделиться")
        }
        .htScreenPadding()
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                HStack { HTHotBadge(); Spacer() }
                dots
            }
            Text(tour.destination.countryFirst)
                .htStyle(.h2Photo).foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, HTSpace.s10)
            Text("\(HTFormat.nights(tour.nights))  •  Вылет из Ташкента")
                .htStyle(.callout).foregroundStyle(HTColor.onPhoto2)
                .padding(.top, HTSpace.s4)
            HStack(spacing: HTSpace.s6) {
                Image(systemName: "star.fill").font(.system(size: HTIcon.inline, weight: .medium))
                Text(HTFormat.rating(tour.rating)).font(.system(size: 16, weight: .semibold))
                Text("(\(HTFormat.reviews(tour.reviewsCount)))").htStyle(.callout).foregroundStyle(HTColor.onPhoto2)
            }
            .foregroundStyle(.white)
            .padding(.top, HTSpace.s8)
            priceRow.padding(.top, HTSpace.s16)
        }
        .htScreenPadding()
        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
    }

    /// «от 9 480 000 UZS» лаймом, зачёркнутая старая и чип скидки. Не влезает в строку — старая цена над чипом.
    private var priceRow: some View {
        let main = HStack(alignment: .firstTextBaseline, spacing: 0) {
            if isBest {
                Text("от ").font(.system(size: 17, weight: .semibold)).transition(.opacity)
            }
            HTPriceText(price, style: Self.heroPrice, color: HTColor.lime)
        }
        .foregroundStyle(HTColor.lime)
        .animation(reduceMotion ? HTMotion.crossfade : HTMotion.price, value: price)
        let old = HTOldPrice(tour.oldPrice, color: .white.opacity(0.7), size: 11)
        let chip = HTDiscountChip(tour.discountPercent(for: price)).animation(reduceMotion ? HTMotion.crossfade : HTMotion.fade, value: price)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: HTSpace.s6) {
                main
                Spacer(minLength: 0)
                old
                chip.alignmentGuide(.firstTextBaseline) { $0[.bottom] - 8 }
            }
            HStack(alignment: .bottom, spacing: HTSpace.s8) {
                main
                Spacer(minLength: HTSpace.s4)
                VStack(alignment: .trailing, spacing: HTSpace.s4) { old; chip }
            }
        }
        .onGeometryChange(for: Bool.self) { $0.frame(in: .global).maxY > safe.top } action: { priceOnScreen = $0 }
    }

    private var dots: some View {
        HStack(spacing: HTSpace.s8) {
            ForEach(tour.gallery.indices, id: \.self) { i in
                if i == photoIndex {
                    Capsule().fill(.white)
                        .frame(width: HTSize.galleryDotActive, height: HTSize.galleryDot)
                        .htMatchedGeometry(id: "dot", in: dotSpace, enabled: !reduceMotion)
                } else {
                    Circle().fill(.white.opacity(0.45)).frame(width: HTSize.galleryDot, height: HTSize.galleryDot)
                }
            }
        }
        .htAnimation(HTMotion.dot, value: photoIndex, reduceMotion: reduceMotion)
        .opacity(tour.gallery.count > 1 ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Фото \(photoIndex + 1) из \(tour.gallery.count)")
    }

    private func toggleFavorite() {
        router.toggleFavorite(tour)
        withAnimation(reduceMotion ? HTMotion.fade : HTMotion.toast) { toastVisible = router.isFavorite(tour) }
    }

    // MARK: Шит

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Входит в стоимость").htStyle(.h3).foregroundStyle(HTColor.ink).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: HTSpace.s8) {
                ForEach(tour.included) { includedRow($0) }
            }
            .padding(.top, HTSpace.s14)
            HTHairline().padding(.top, HTSpace.s16)
            HTSectionHeader("Туроператоры", action: "Сравнить цены") { comparing = true }
                .padding(.top, HTSpace.s16)
            operators.padding(.top, HTSpace.s10)
            Text("Об отеле").htStyle(.h3).foregroundStyle(HTColor.ink).padding(.top, HTSpace.s28)
            Text("\(tour.hotelTitle) · \(tour.area)").htStyle(.bodySMedium).foregroundStyle(HTColor.ink)
                .padding(.top, HTSpace.s8)
            Text(tour.about).htStyle(.bodyS).foregroundStyle(HTColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, HTSpace.s4)
        }
        .htScreenPadding()
        .padding(.top, HTSpace.s24)
        .padding(.bottom, HTSize.stickyClearance + safe.bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: HTRadius.sheet, topTrailingRadius: HTRadius.sheet, style: .continuous)
                .fill(HTColor.surface)
                .shadow(color: HTColor.ink.opacity(0.08), radius: 10, y: -4)
        )
        .padding(.top, -HTSize.sheetOverlap)
    }

    private func flightLine(_ title: String, _ note: String, size: CGFloat) -> Text {
        Text(title).font(.system(size: size, weight: .semibold)).foregroundColor(HTColor.ink)
            + Text(" " + note).font(.system(size: size - 1)).foregroundColor(HTColor.ink2)
    }

    /// Пункт «Входит в стоимость»: тап раскрывает подробности, открыт один пункт (P1-9).
    private func includedRow(_ item: IncludedItem) -> some View {
        let isOpen = openIncluded == item.kind
        return Button {
            htWithAnimation(HTMotion.expand, reduceMotion: reduceMotion) { openIncluded = isOpen ? nil : item.kind }
        } label: {
            HStack(alignment: .top, spacing: HTSpace.s16) {
                Image(systemName: item.kind.icon)
                    .font(.system(size: HTIcon.base, weight: .medium))
                    .foregroundStyle(HTColor.ink)
                    .frame(width: 28, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    if item.kind == .flight, let note = item.note {
                        // Маршрут в одну строку, как на референсе; длинный город (Шарм-эш-Шейх) переносится, а не режется.
                        ViewThatFits(in: .horizontal) {
                            flightLine(item.title, note, size: 15).fixedSize()
                            flightLine(item.title, note, size: 13).fixedSize()
                            flightLine(item.title, note, size: 15).lineLimit(2)
                        }
                    } else {
                        Text(item.title)
                            .font(.system(size: 15, weight: item.note == nil ? .regular : .semibold))
                            .foregroundStyle(item.note == nil ? HTColor.ink2 : HTColor.ink)
                        if let note = item.note {
                            Text(note).htStyle(.footnote).foregroundStyle(HTColor.ink2)
                        }
                    }
                    if isOpen {
                        Text(item.detail).htStyle(.footnote).foregroundStyle(HTColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, HTSpace.s4)
                            // Текст проявляется, когда строки ниже уже уехали (иначе ≈0,1 с наезжает на «Трансфер»),
                            // и уходит сразу, до схлопывания.
                            .transition(.asymmetric(insertion: .opacity.animation(HTMotion.fade.delay(0.18)),
                                                    removal: .opacity.animation(HTMotion.crossfade)))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: HTIcon.micro, weight: .semibold))
                    .foregroundStyle(HTColor.ink3)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .frame(height: 22)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tour.included.\(item.kind.rawValue)")
    }

    private var operators: some View {
        VStack(spacing: 0) {
            ForEach(Array(tour.offers.enumerated()), id: \.element.id) { i, offer in
                if i > 0 { HTHairline().padding(.horizontal, HTSpace.s12) }
                operatorRow(offer)
            }
        }
        .htCard(radius: HTRadius.card, stroke: true, shadow: nil)
        .sensoryFeedback(.selection, trigger: selected)
    }

    /// Строка оператора: высота не зависит от выбора (чип «Самая низкая цена» всегда у самой дешёвой),
    /// поэтому при тапе список не сдвигается; плашка выбора переезжает `matchedGeometryEffect`.
    private func operatorRow(_ offer: OperatorOffer) -> some View {
        let isOn = offer == selected
        let best = offer == tour.bestOffer
        return Button { select(offer) } label: {
            HStack(spacing: HTSpace.s12) {
                HTOperatorLogo(tourOperator: offer.tourOperator)
                Text(offer.tourOperator.name).htStyle(.bodySMedium).foregroundStyle(HTColor.ink)
                    .lineLimit(1).minimumScaleFactor(0.85)
                    .frame(width: 118, alignment: .leading)
                VStack(alignment: .leading, spacing: HTSpace.s4) {
                    Text(HTFormat.uzs(offer.price)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(HTColor.ink)
                        .fixedSize()
                    if best { BestPriceChip() }
                }
                Spacer(minLength: 0)
                HTRadio(isOn)
            }
            .padding(.leading, HTSpace.s12)
            .padding(.trailing, HTSpace.s14)
            .frame(height: best ? HTSize.operatorRowBest : HTSize.operatorRow)
            .background {
                if isOn {
                    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                    shape.fill(HTColor.limeSoft)
                        .overlay(shape.strokeBorder(HTColor.limeStroke, lineWidth: HTSize.strongStroke))
                        .htMatchedGeometry(id: "operatorSelection", in: selectionSpace, enabled: !reduceMotion)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("tour.operator.\(offer.tourOperator.id)")
    }

    private func select(_ offer: OperatorOffer) {
        guard offer != selected else { return }
        htWithAnimation(HTMotion.select, reduceMotion: reduceMotion) { selected = offer }
        if !priceOnScreen {
            withAnimation(reduceMotion ? HTMotion.fade : HTMotion.toast) { operatorNote = offer }
        }
    }
}

/// Плашка над CTA «Coral Travel · 9 890 000 UZS», пока цена в шапке вне экрана.
private struct OperatorNote: View {
    let offer: OperatorOffer
    var body: some View {
        HStack(spacing: HTSpace.s8) {
            HTOperatorLogo(tourOperator: offer.tourOperator).scaleEffect(0.8).frame(width: 30, height: 30)
            Text(offer.tourOperator.name).htStyle(.bodySMedium).foregroundStyle(HTColor.ink)
            Spacer(minLength: HTSpace.s8)
            Text(HTFormat.uzs(offer.price)).font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(HTColor.ink)
                .contentTransition(.numericText(value: Double(offer.price)))
        }
        .padding(.horizontal, HTSpace.s12)
        .frame(height: 48)
        .htCard(radius: HTRadius.field, stroke: true, shadow: .raised)
        .htScreenPadding()
        .padding(.bottom, HTSpace.s4)
    }
}

/// Sheet «Сравнить цены»: все операторы тура, разница с самой низкой ценой; тап выбирает оператора.
struct OperatorCompare: View {
    let tour: Tour
    let selected: OperatorOffer
    let onPick: (OperatorOffer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Сравнение цен").htStyle(.title).foregroundStyle(HTColor.ink).padding(.top, HTSpace.s28)
            Text("Один и тот же тур: перелёт, \(tour.hotelTitle), трансфер и страховка \(HTFormat.forTravelers(tour.adults)). Разница — наценка туроператора.")
                .htStyle(.bodyS).foregroundStyle(HTColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, HTSpace.s8)
            VStack(spacing: HTSpace.s8) {
                ForEach(tour.offers) { offer in
                    let delta = offer.price - tour.bestOffer.price
                    Button { onPick(offer) } label: {
                        HStack(spacing: HTSpace.s12) {
                            HTOperatorLogo(tourOperator: offer.tourOperator)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.tourOperator.name).htStyle(.body).foregroundStyle(HTColor.ink)
                                    .lineLimit(1).minimumScaleFactor(0.85)
                                if delta == 0 {
                                    BestPriceChip()
                                } else {
                                    Text("\(HTFormat.delta(delta)) UZS").htStyle(.footnote).foregroundStyle(HTColor.ink3)
                                }
                            }
                            Spacer()
                            Text(HTFormat.uzs(offer.price)).font(.system(size: 15, weight: .bold)).monospacedDigit()
                                .foregroundStyle(HTColor.ink)
                                .fixedSize()
                            HTRadio(offer == selected)
                        }
                        .padding(.horizontal, HTSpace.s14)
                        .frame(height: 64)
                        .htCard(radius: HTRadius.card, stroke: true, shadow: nil)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HTPressStyle(scale: 0.98))
                }
            }
            .padding(.top, HTSpace.s16)
            Spacer()
        }
        .htSheet(height: HTSize.compareSheet)
    }
}

extension IncludedItem.Kind {
    var icon: String {
        switch self {
        case .flight: "airplane"
        case .hotel: "bed.double"
        case .transfer: "car"
        case .insurance: "checkmark.shield"
        }
    }
}

/// Чип «Самая низкая цена» — один вид в списке операторов и в sheet сравнения.
private struct BestPriceChip: View {
    var body: some View {
        Text("Самая низкая цена")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(HTColor.onLime)
            .padding(.horizontal, HTSpace.s6)
            .frame(height: 18)
            .background(HTColor.lime.opacity(0.6), in: Capsule())
            .fixedSize()
    }
}
