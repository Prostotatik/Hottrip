import SwiftUI

/// Бронь подтверждена (spec-iter07 §5.2): лаймовый круг с галочкой, номер брони, карточка-сводка с рейсом,
/// отелем и оплатой, куда придёт ваучер; «Мои поездки» и «На главную». Без талона и штрихкода.
public struct SuccessScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htSafeArea) private var safe
    @Environment(\.htReduceMotion) private var reduceMotion

    let booking: Booking
    /// Галочка появляется пружиной 0,6 → 1 (экран проявляется поверх оплаты); иначе — сразу финал.
    let animateMark: Bool
    @State private var markShown = false

    public init(booking: Booking, animateMark: Bool = false) {
        self.booking = booking; self.animateMark = animateMark
    }

    private var tour: Tour { booking.tour }

    private var paidLine: String {
        if let months = booking.installmentMonths {
            let monthly = MockData.installmentMonthly(booking.offer.price, months: months)
            return "Рассрочка \(months) мес · \(HTFormat.uzs(monthly))/мес"
        }
        return "Оплачено \(HTFormat.uzs(booking.offer.price)) · \(booking.method.name)"
    }

    public var body: some View {
        let final = !animateMark || markShown || reduceMotion
        VStack(spacing: 0) {
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(HTColor.onLime)
                .frame(width: HTSize.successMark, height: HTSize.successMark)
                .background(HTColor.lime, in: Circle())
                .htShadow(.lime)
                .scaleEffect(final ? 1 : 0.6)
                .opacity(final ? 1 : 0)
            Text("Бронь подтверждена").htStyle(HTTextStyle(28, 32, .bold, tracking: -0.5)).foregroundStyle(HTColor.ink)
                .padding(.top, HTSpace.s20)
                .accessibilityAddTraits(.isHeader)
            Text("Номер \(booking.number)").htStyle(.bodyS).foregroundStyle(HTColor.ink2).padding(.top, HTSpace.s6)
            VStack(spacing: 0) {
                PaymentSummary(tour: tour, offer: booking.offer, carded: false)
                ForEach([("airplane", "Вылет \(HTFormat.dayTime(tour.flight.departure)) · \(tour.flight.number)"),
                         ("bed.double", "Отель \(tour.hotelTitle)"),
                         ("checkmark.seal", paidLine)], id: \.1) { icon, text in
                    HTHairline().padding(.horizontal, HTSpace.s16)
                    HStack(spacing: HTSpace.s12) {
                        Image(systemName: icon).font(.system(size: HTIcon.inline, weight: .medium)).frame(width: 22)
                        Text(text).htStyle(.bodyS).lineLimit(1).minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(HTColor.ink)
                    .padding(.horizontal, HTSpace.s16)
                    .frame(height: 48)
                }
            }
            .htCard(radius: HTRadius.summary)
            .padding(.top, HTSpace.s24)
            Text("Ваучер придёт на \(booking.email) и\u{00A0}в\u{00A0}Telegram в\u{00A0}течение 15\u{00A0}минут")
                .htStyle(.footnote).foregroundStyle(HTColor.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HTSpace.s20)
                .padding(.top, HTSpace.s16)
            Spacer(minLength: HTSpace.s16)
            HTPrimaryButton("Мои поездки") { router.goHome(); router.select(.profile) }
            HTTextButton("На главную") { router.goHome() }.padding(.top, HTSpace.s4)
        }
        .htScreenPadding()
        .padding(.top, safe.top + HTSpace.s32)
        .padding(.bottom, safe.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HTColor.canvas)
        .task {
            guard animateMark, !markShown else { return }
            withAnimation(HTMotion.mark.delay(0.1)) { markShown = true }
        }
    }
}
