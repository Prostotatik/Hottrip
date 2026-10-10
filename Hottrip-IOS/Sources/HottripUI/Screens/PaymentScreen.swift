import SwiftUI

/// Состояние оплаты: явные фазы вместо Bool isLoading.
public enum PayState: Equatable, Sendable {
    case idle
    case processing
    /// Деньги списаны: в CTA галочка, через `HTMotion.paidHold` — экран брони.
    case paid
    case failure

    var isBusy: Bool { self == .processing || self == .paid }
}

/// Оплата (spec-iter07 §4): сводка с фото, пять способов оплаты отдельными карточками, лайм-CTA
/// «Оплатить …» и «Ваши данные защищены». В оплате только `HTMotion.calm`, без отскоков (P0-7).
public struct PaymentScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htSafeArea) private var safe
    @Environment(\.htReduceMotion) private var reduceMotion
    @Environment(\.htRenderMode) private var mode
    @Namespace private var selectionSpace

    let tour: Tour
    let offer: OperatorOffer
    let initialLockElapsed: TimeInterval

    @State private var method: PaymentMethod
    @State private var months = MockData.installmentMonths
    @State private var cardNumber: String
    @State private var expiry: String
    @State private var payState: PayState
    @State private var lockStartedAt: Date?
    @State private var payTask: Task<Void, Never>?
    /// Верх клавиатуры в окне (от keyboardWillShow до keyboardDidHide); nil — клавиатуры нет.
    /// CTA возвращается, когда клавиатура ушла целиком.
    @State private var keyboardTop: CGFloat?
    /// Низ области прокрутки в окне: насколько клавиатура её перекрывает, считаем сами — парящая
    /// клавиатура iOS 27 не сжимает safe area, и поле «Срок» иначе остаётся под ней.
    @State private var scrollBottom: CGFloat = 0
    /// Бронь, которая уже проявляется поверх оплаты (P1-11): один кроссфейд вместо push.
    @State private var issued: Booking?
    @FocusState private var focusedField: CardField?

    public init(tour: Tour, offer: OperatorOffer, method: PaymentMethod.Kind = .payme, cardNumber: String = "",
                expiry: String = "", payState: PayState = .idle, lockElapsed: TimeInterval = 1) {
        self.tour = tour; self.offer = offer
        self.initialLockElapsed = lockElapsed
        _method = State(initialValue: MockData.paymentMethods.first { $0.kind == method } ?? MockData.paymentMethods[0])
        _cardNumber = State(initialValue: cardNumber)
        _expiry = State(initialValue: expiry)
        _payState = State(initialValue: payState)
    }

    private var amount: Int { offer.price }
    private var monthly: Int { MockData.installmentMonthly(amount, months: months) }
    private var cardSystem: CardSystem? { CardSystem(number: cardNumber) }
    private var cardDigits: String { cardNumber.filter(\.isNumber) }
    /// Опечатку в номере ловим в поле, до нажатия «Оплатить» (16 цифр, не прошли проверку Луна).
    private var cardInvalid: Bool { cardDigits.count == 16 && !CardSystem.passesLuhn(cardDigits) }
    private var cardComplete: Bool { cardDigits.count == 16 && !cardInvalid && expiry.count == 5 }
    private var canPay: Bool { method.kind != .card || cardComplete }
    private var expands: Bool { method.kind == .card || method.kind == .installment }

    private var keyboardUp: Bool { keyboardTop != nil }
    private var keyboardOverlap: CGFloat { keyboardTop.map { max(0, scrollBottom - $0) } ?? 0 }

    private enum Anchor: Hashable { case expanded, cardFields, method(PaymentMethod.Kind) }
    /// Измеренная высота нижнего блока целиком (фейд, баннер отказа, CTA, подпись, safe area).
    /// Пока бар скрыт (клавиатура), держим последнее значение, чтобы раскладка не прыгала.
    @State private var payBarHeight: CGFloat = 0
    /// Запас сверх измеренной высоты бара. Бар уже включает фейд 24 pt и пустой слот баннера (+14 pt интервала),
    /// так что от низа последней карточки до CTA ≈ 43 pt.
    private static let barGap: CGFloat = 5
    /// До первого замера — фейд, слот баннера, CTA 54, подпись и отступы (без safe area).
    private static let barFallback: CGFloat = 125
    private var barClearance: CGFloat {
        (payBarHeight > 0 ? payBarHeight : Self.barFallback + safe.bottom) + Self.barGap
    }
    /// Прокрутка ушла за заголовок «Оплата» — показывается компактная шапка «‹ Оплата».
    @State private var compactHeader = false

    /// Куда докручен экран: ввод карты — оба поля над клавиатурой; раскрыта карта или рассрочка —
    /// низ раскрытой карточки над CTA, чтобы оба были видны.
    private var scrollTarget: HTScrollTarget? {
        if keyboardUp && focusedField != nil { return HTScrollTarget(Anchor.cardFields, anchor: .bottom) }
        return expands ? HTScrollTarget(Anchor.expanded, anchor: .bottom) : nil
    }

    public var body: some View {
        HTScreen {
            HTScroll(scrollTo: scrollTarget) {
                VStack(alignment: .leading, spacing: 0) {
                    HTBackButton(chevron: true).disabled(payState.isBusy)
                    // Предупреждение замка — справа от заголовка: над CTA ему нет места, не закрыв пятый способ.
                    HStack(alignment: .center) {
                        Text("Оплата").htStyle(.h1).foregroundStyle(HTColor.ink).accessibilityAddTraits(.isHeader)
                        Spacer(minLength: HTSpace.s8)
                        priceLock
                    }
                    .padding(.top, HTSpace.s4)
                    PaymentSummary(tour: tour, offer: offer).padding(.top, HTSpace.s12)
                    Text("Способ оплаты").htStyle(.title).foregroundStyle(HTColor.ink).padding(.top, 26)
                    methods.padding(.top, HTSpace.s10)
                }
                .htScreenPadding()
                .padding(.top, safe.top - 12)
                .padding(.bottom, barClearance + keyboardOverlap)
            }
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { scrollBottom = $0 }
            .onPreferenceChange(HTScrollEdgeKey.self) { edge in
                let compact = edge.offset > Self.compactAfter
                if compact != compactHeader { withAnimation(HTMotion.fade) { compactHeader = compact } }
            }
        } bar: {
            // Пока открыта клавиатура, CTA убрана: иначе она поднимается над клавиатурой и закрывает поле.
            if focusedField == nil && !keyboardUp { payBar.transition(.opacity) }
        }
        .overlay(alignment: .top) {
            if compactHeader && mode == .interactive { compactBar.transition(.opacity) }
        }
        .overlay {
            if let issued {
                SuccessScreen(booking: issued, animateMark: true)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .htKeyboardDone { focusedField = nil }
        .htKeyboardVisibility { top in
            if let top { keyboardTop = top } else { withAnimation(HTMotion.calm) { keyboardTop = nil } }
        }
        .onAppear {
            if lockStartedAt == nil { lockStartedAt = DemoClock.now().addingTimeInterval(-initialLockElapsed) }
        }
        .onDisappear { payTask?.cancel() }
        .sensoryFeedback(.success, trigger: payState) { _, new in new == .paid }
        .sensoryFeedback(.error, trigger: payState) { _, new in new == .failure }
        .sensoryFeedback(.error, trigger: cardInvalid) { _, new in new }
    }

    // MARK: Способы оплаты

    private var methods: some View {
        VStack(spacing: HTSpace.s8) {
            ForEach(MockData.paymentMethods) { m in methodCard(m) }
        }
        .sensoryFeedback(.selection, trigger: method)
        .onChange(of: method) { clearFailure() }
        .disabled(payState.isBusy)
        .opacity(payState.isBusy ? 0.5 : 1)
    }

    private func methodCard(_ m: PaymentMethod) -> some View {
        let isOn = m == method
        let shape = RoundedRectangle(cornerRadius: HTRadius.card, style: .continuous)
        return VStack(spacing: 0) {
            Button {
                withAnimation(HTMotion.calm) { method = m }
            } label: {
                HStack(spacing: HTSpace.s20) {
                    HTBrandTile(kind: m.kind)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name).htStyle(.body).foregroundStyle(HTColor.ink)
                        if let subtitle = m.subtitle {
                            Text(subtitle).htStyle(.footnote).foregroundStyle(HTColor.ink2)
                        }
                    }
                    Spacer(minLength: 0)
                    HTRadio(isOn)
                }
                .padding(.leading, HTSpace.s16)
                .padding(.trailing, 18)
                .frame(height: HTSize.paymentRow)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityIdentifier("payment.method.\(m.kind.rawValue)")
            if isOn && m.kind == .card {
                cardForm.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
            if isOn && m.kind == .installment {
                installmentPlan.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(HTColor.surface, in: shape)
        .overlay(shape.strokeBorder(HTColor.line, lineWidth: HTSize.hairline))
        .overlay {
            if isOn {
                shape.strokeBorder(HTColor.lime, lineWidth: HTSize.strongStroke)
                    .htMatchedGeometry(id: "paymentSelection", in: selectionSpace, enabled: !reduceMotion)
            }
        }
        .htShadow(isOn ? .raised : .card)
        .htScrollAnchor(isOn ? Anchor.expanded : Anchor.method(m.kind), bottom: barClearance - 20)
    }

    private var cardForm: some View {
        VStack(alignment: .leading, spacing: HTSpace.s12) {
            HTInputField(.number, focus: $focusedField, label: "Номер карты", text: $cardNumber, placeholder: "8600 0000 0000 0000",
                         style: HTTextStyle(17, 22, .medium, monoDigits: true), digitsOnly: true,
                         error: cardInvalid ? "Проверьте номер карты" : nil) {
                if let cardSystem {
                    Text(cardSystem.title).htStyle(.caption).foregroundStyle(HTColor.ink2).transition(.opacity)
                }
            }
            .onChange(of: cardNumber) { _, new in
                let formatted = CardSystem.format(new)
                if formatted != new { cardNumber = formatted }
                clearFailure()
                // Номер введён целиком и верен — сразу к сроку (на цифровой клавиатуре нет «Далее»).
                if cardDigits.count == 16 && !cardInvalid && focusedField == .number { focusedField = .expiry }
            }
            .animation(reduceMotion ? nil : HTMotion.fade, value: cardSystem)
            .animation(HTMotion.fade, value: cardInvalid)
            HTInputField(.expiry, focus: $focusedField, label: "Срок", text: $expiry, placeholder: "ММ/ГГ",
                         style: HTTextStyle(17, 22, .medium, monoDigits: true), digitsOnly: true, error: nil) {
                EmptyView()
            }
            .frame(width: HTSize.expiryField)
            .htScrollAnchor(Anchor.cardFields, bottom: HTSize.keyboardClearance + keyboardOverlap)
            .onChange(of: expiry) { _, new in
                let formatted = CardSystem.formatExpiry(new)
                if formatted != new { expiry = formatted }
                // Срок введён — клавиатура уходит, возвращается CTA.
                if formatted.count == 5 && focusedField == .expiry { focusedField = nil }
            }
        }
        .padding(.horizontal, HTSpace.s16)
        .padding(.bottom, HTSpace.s16)
    }

    /// Рассрочка без процентов: срок 3 / 6 / 12 месяцев и платёж в месяц (≈, если не делится ровно).
    private var installmentPlan: some View {
        VStack(alignment: .leading, spacing: HTSpace.s8) {
            HStack(spacing: HTSpace.s8) {
                ForEach(MockData.installmentTerms, id: \.self) { term in
                    HTChip("\(term) мес", isOn: term == months, accent: .lime) {
                        withAnimation(HTMotion.calm) { months = term }
                    }
                }
            }
            Text("\(MockData.installmentIsExact(amount, months: months) ? "" : "≈\u{00A0}")\(HTFormat.uzs(monthly))/мес · без переплаты, итого\u{00A0}\(HTFormat.uzs(amount))")
                .htStyle(.footnote).foregroundStyle(HTColor.ink2)
                .contentTransition(.numericText(value: Double(monthly)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HTSpace.s16)
        .padding(.bottom, HTSpace.s14)
        .sensoryFeedback(.selection, trigger: months)
    }

    // MARK: CTA

    private var payBar: some View {
        HTStickyBar(bottom: safe.bottom + 3) {
            VStack(spacing: 14) {
                VStack(spacing: HTSpace.s8) {
                    if payState == .failure {
                        HStack(alignment: .top, spacing: HTSpace.s8) {
                            Image(systemName: "exclamationmark.circle").font(.system(size: HTIcon.inline, weight: .medium))
                            Text("Банк отклонил платёж, деньги не списаны. Попробуйте другую карту или способ оплаты")
                                .htStyle(.bodyS).fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(HTColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HTSpace.s12)
                        .background(HTColor.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: HTRadius.tile, style: .continuous))
                        .transition(.opacity)
                    }
                }
                HTPrimaryButton(haptic: true, action: pay) { payLabel }
                    .disabled(!canPay)
                    .allowsHitTesting(!payState.isBusy)
                    .accessibilityIdentifier("payment.pay")
                HStack(spacing: HTSpace.s6) {
                    Image(systemName: "lock.fill").font(.system(size: HTIcon.micro, weight: .medium))
                    Text("Ваши данные защищены").htStyle(.footnote)
                }
                .foregroundStyle(HTColor.ink3)
            }
        }
        .animation(HTMotion.calm, value: payState)
        .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { payBarHeight = $0 }
    }

    // MARK: Компактная шапка

    /// Сдвиг, после которого крупный заголовок ушёл под строку состояния.
    private static let compactAfter: CGFloat = 44

    /// Липкая шапка «‹ Оплата» при прокрутке (как scroll-edge effect): полупрозрачный материал с тоном `canvasTop`,
    /// снизу мягкий фейд 12 pt — контент уходит под неё без жёсткого среза, «назад» всегда под рукой.
    private var compactBar: some View {
        let barHeight = safe.top + HTSize.hitArea
        let fade: CGFloat = 12
        return HTNavBar(chevron: true, center: {
            Text("Оплата").htStyle(.headline).foregroundStyle(HTColor.ink)
                .accessibilityAddTraits(.isHeader)
        })
        .disabled(payState.isBusy)
        .padding(.top, safe.top)
        .padding(.bottom, fade)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                HTColor.canvasTop.opacity(0.85)
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                         .init(color: .black, location: barHeight / (barHeight + fade)),
                                         .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private var payLabel: some View {
        // Все фазы — одним push снизу: тексты idle и processing не накладываются; размер кнопки не меняется.
        let transition: AnyTransition = reduceMotion ? .opacity : .push(from: .bottom)
        switch payState {
        case .processing:
            HStack(spacing: HTSpace.s10) {
                ProgressView().tint(HTColor.onLime)
                Text("Оплачиваем…")
            }
            .transition(transition)
        case .paid:
            HStack(spacing: HTSpace.s8) {
                Image(systemName: "checkmark").font(.system(size: 18, weight: .bold))
                Text("Оплачено")
            }
            .transition(transition)
        case .idle, .failure:
            Text(ctaTitle)
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85)
                .contentTransition(.numericText(value: Double(method.kind == .installment ? monthly : amount)))
                .padding(.horizontal, HTSpace.s20)
                .transition(transition)
        }
    }

    private var ctaTitle: String {
        switch (payState, method.kind) {
        case (.failure, _): "Попробовать снова"
        case (_, .installment): "Оплатить \(HTFormat.uzs(monthly))/мес"
        default: "Оплатить \(HTFormat.uzs(amount))"
        }
    }

    // MARK: Замок цены

    /// Предупреждение появляется только в последние 3 минуты замка (spec-iter07 §4.3): «Цена закреплена 2:59».
    private var priceLock: some View {
        HTClock { now in
            let lock = PriceLock.at(now, startedAt: lockStartedAt ?? now.addingTimeInterval(-initialLockElapsed))
            if lock.phase != .active {
                HStack(spacing: HTSpace.s6) {
                    Image(systemName: "clock").font(.system(size: HTIcon.micro, weight: .semibold))
                    if lock.phase == .rechecking {
                        Text("Проверяем цену…")
                    } else {
                        Text("Цена закреплена ")
                            + Text(HTFormat.ms(lock.remaining).dropFirst(lock.remaining < 600 ? 1 : 0)).monospacedDigit()
                    }
                }
                .htStyle(.footnote)
                .foregroundStyle(HTColor.danger)
                .padding(.horizontal, HTSpace.s12)
                .frame(height: 30)
                .background(HTColor.danger.opacity(0.1), in: Capsule())
                .transition(.opacity)
            }
        }
    }

    // MARK: Оплата

    /// Повторная оплата невозможна: после успеха экран оплаты заменяется в стеке бронью.
    /// Отказ банка приходит после проверки. Задача отменяется при уходе с экрана.
    private func pay() {
        guard canPay, !payState.isBusy else { return }
        payTask = Task { @MainActor in
            payState = .processing
            try? await Task.sleep(for: .seconds(HTMotion.payDuration))
            guard !Task.isCancelled else { payState = .idle; return }
            if isDeclined { payState = .failure; return }
            // Пользователь мог уйти свайпом в последние доли секунды: заменяем стек, только если сверху всё ещё оплата.
            guard case .payment = router.path.last else { payState = .idle; return }
            payState = .paid
            try? await Task.sleep(for: .seconds(HTMotion.paidHold))
            let booking = MockData.booking(tour, offer, method, months: months, paidAt: DemoClock.now())
            htWithAnimation(HTMotion.calm, reduceMotion: reduceMotion) { issued = booking }
            try? await Task.sleep(for: .seconds(0.35))
            guard case .payment = router.path.last else { return }
            // Бронь уже на экране поверх оплаты: подменяем маршрут без анимации — склейки не видно.
            var swap = Transaction()
            swap.disablesAnimations = true
            withTransaction(swap) { router.replaceTop(with: .success(booking)) }
        }
    }

    /// Баннер отказа банка снимается, как только пользователь правит номер или меняет способ оплаты.
    private func clearFailure() {
        if payState == .failure { withAnimation(HTMotion.calm) { payState = .idle } }
    }

    private var isDeclined: Bool {
        method.kind == .card && cardDigits == MockData.declinedCard.filter(\.isNumber)
    }
}

/// Сводка тура (оплата, бронь): фото 96 × 104, «Анталья, Турция», ночи и питание, оператор, цена справа.
struct PaymentSummary: View {
    let tour: Tour
    let offer: OperatorOffer
    /// Своя карточка (оплата) или часть карточки брони.
    var carded = true

    var body: some View {
        HStack(alignment: .top, spacing: HTSpace.s16) {
            HTThumb(name: tour.thumbName)
            VStack(alignment: .leading, spacing: 0) {
                Text(tour.destination.title).htStyle(.headline).foregroundStyle(HTColor.ink).lineLimit(1)
                Text("\(HTFormat.nights(tour.nights)) · \(tour.meal.title)").htStyle(.footnote).foregroundStyle(HTColor.ink2)
                    .padding(.top, HTSpace.s6)
                Text(offer.tourOperator.name).font(.system(size: 12, weight: .medium)).foregroundStyle(HTColor.ink3)
                    .padding(.top, HTSpace.s6)
                Spacer(minLength: 0)
                Text(HTFormat.uzs(offer.price)).htStyle(.priceM).foregroundStyle(HTColor.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.top, HTSpace.s4)
        }
        .padding(HTSpace.s12)
        .padding(.trailing, HTSpace.s4)
        .frame(height: HTSize.summaryHeight)
        .htCard(radius: HTRadius.summary, shadow: carded ? .card : nil)
    }
}

/// Платёжная система по BIN-префиксу. Текстовая метка в поле номера, без логотипов.
enum CardSystem: String {
    case uzcard = "UZCARD"
    case humo = "HUMO"

    init?(number: String) {
        let digits = number.filter(\.isNumber)
        guard digits.count >= 4 else { return nil }
        switch digits.prefix(4) {
        case "8600", "5614": self = .uzcard
        case "9860": self = .humo
        default: return nil
        }
    }

    var title: String { self == .uzcard ? "Uzcard" : "Humo" }

    static func format(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(16))
        return stride(from: 0, to: digits.count, by: 4).map { i -> String in
            let start = digits.index(digits.startIndex, offsetBy: i)
            let end = digits.index(start, offsetBy: min(4, digits.count - i))
            return String(digits[start..<end])
        }.joined(separator: " ")
    }

    static func formatExpiry(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(4))
        return digits.count > 2 ? "\(digits.prefix(2))/\(digits.dropFirst(2))" : digits
    }

    static func passesLuhn(_ number: String) -> Bool {
        let digits = number.compactMap(\.wholeNumberValue)
        guard digits.count == 16 else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { acc, pair in
            let (i, d) = pair
            let v = i % 2 == 1 ? (d * 2 > 9 ? d * 2 - 9 : d * 2) : d
            return acc + v
        }
        return sum % 10 == 0
    }
}

/// Поля формы карты.
enum CardField: Hashable { case number, expiry }

/// Поле ввода: высота 50, r 14, фон `canvasBottom`, обводка `line`, в фокусе `ink`, при ошибке `danger`.
/// В снапшоте TextField заменяется текстом (ImageRenderer не рисует редактируемые поля).
struct HTInputField<Accessory: View>: View {
    @Environment(\.htRenderMode) private var mode
    /// Фокус общий на форму карты: экран переводит его номер → срок → клавиатура закрыта.
    var focus: FocusState<CardField?>.Binding
    let field: CardField
    let label: String
    @Binding var text: String
    let placeholder: String
    let style: HTTextStyle
    let digitsOnly: Bool
    /// Текст ошибки под полем; обводка при этом `danger`.
    let error: String?
    let accessory: Accessory

    init(_ field: CardField, focus: FocusState<CardField?>.Binding, label: String, text: Binding<String>,
         placeholder: String, style: HTTextStyle, digitsOnly: Bool, error: String?, @ViewBuilder accessory: () -> Accessory) {
        self.field = field; self.focus = focus
        self.label = label; self._text = text; self.placeholder = placeholder; self.style = style
        self.digitsOnly = digitsOnly; self.error = error; self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HTSpace.s6) {
            Text(label).htStyle(.footnote).foregroundStyle(HTColor.ink2)
            HStack {
                input
                Spacer(minLength: 0)
                accessory
            }
            .padding(.horizontal, HTSpace.s12)
            .frame(height: HTSize.inputField)
            // Фокус по тапу в любое место поля, а не только в строку текста.
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = field }
            .background(HTColor.canvasBottom, in: RoundedRectangle(cornerRadius: HTRadius.tile, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HTRadius.tile, style: .continuous)
                .strokeBorder(borderColor, lineWidth: error == nil ? HTSize.hairline : HTSize.strongStroke))
            if let error {
                Text(error).htStyle(.footnote).foregroundStyle(HTColor.danger).transition(.opacity)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return HTColor.danger }
        return focus.wrappedValue == field ? HTColor.ink : HTColor.line
    }

    @ViewBuilder private var input: some View {
        if mode == .snapshot {
            Text(text.isEmpty ? placeholder : text)
                .htStyle(style)
                .foregroundStyle(text.isEmpty ? HTColor.ink3 : HTColor.ink)
        } else {
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(HTColor.ink3))
                .htStyle(style)
                .foregroundStyle(HTColor.ink)
                .focused(focus, equals: field)
                .htNumberPad(digitsOnly)
                .accessibilityLabel(label)
                .accessibilityIdentifier("field.\(label)")
        }
    }
}

extension View {
    /// Кнопка «Готово» над клавиатурой.
    @ViewBuilder
    func htKeyboardDone(_ action: @escaping () -> Void) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово", action: action).fontWeight(.semibold).foregroundStyle(HTColor.ink)
            }
        }
        #else
        self
        #endif
    }

    /// Появление клавиатуры (keyboardWillShow → верх её конечной рамки в окне) и полный уход (keyboardDidHide → nil).
    @ViewBuilder
    func htKeyboardVisibility(_ action: @escaping (CGFloat?) -> Void) -> some View {
        #if os(iOS)
        onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            action(frame?.minY ?? 0)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in action(nil) }
        #else
        self
        #endif
    }

    @ViewBuilder
    func htNumberPad(_ enabled: Bool) -> some View {
        #if os(iOS)
        if enabled { keyboardType(.numberPad) } else { self }
        #else
        self
        #endif
    }
}
