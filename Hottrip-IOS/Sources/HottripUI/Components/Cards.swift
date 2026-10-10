import SwiftUI

/// Карточка направления 114 × 168 r 18 (spec-iter07 §2.2): фото на всю карточку, тонированный низ,
/// название и «от … UZS».
struct DestinationCard: View {
    let title: String
    let imageName: String
    /// Цена «от» той подборки, которую откроет направление; nil — не печатаем («от 0 UZS» был бы ложью).
    let fromPrice: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HTImage(imageName)
                .frame(width: HTSize.destinationCard.width, height: HTSize.destinationCard.height)
                .overlay {
                    LinearGradient(stops: [.init(color: HTColor.night700.opacity(0), location: 0.55),
                                           .init(color: HTColor.night900.opacity(0.78), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).htStyle(.calloutStrong).foregroundStyle(.white)
                        if let fromPrice {
                            Text("от \(HTFormat.uzs(fromPrice))")
                                .font(.system(size: 11, weight: .medium)).monospacedDigit()
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                    .padding(HTSpace.s10)
                }
                .clipShape(RoundedRectangle(cornerRadius: HTRadius.card, style: .continuous))
                .htShadow(.card)
        }
        .buttonStyle(HTPressStyle())
    }
}

/// Карточка тура в выдаче (spec-iter07 §5.1): фото 180 r 20 с чипом скидки и сердцем, название, мета,
/// «Осталось N мест», цена «от» и лайм-кнопка со стрелкой. Источник зум-перехода в тур.
struct ResultCard: View {
    @Environment(AppRouter.self) private var router
    let tour: Tour
    let onFavorite: (Bool) -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) { content }
            .buttonStyle(HTPressStyle(scale: 0.98))
            .accessibilityIdentifier("tourCard.\(tour.id)")
            .overlay(alignment: .topTrailing) {
                HTHeartButton(isFavorite: router.isFavorite(tour), size: HTSize.cardHeart) {
                    router.toggleFavorite(tour)
                    onFavorite(router.isFavorite(tour))
                }
                .padding(HTSpace.s12 - (HTSize.hitArea - HTSize.cardHeart) / 2)
                .accessibilityIdentifier("tourCard.favorite.\(tour.id)")
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HTImage(tour.coverName)
                .frame(height: HTSize.resultPhoto)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: HTRadius.summary, style: .continuous))
                .htZoomSource(tour)
                .overlay(alignment: .topLeading) { HTDiscountChip(tour.discountPercent).padding(HTSpace.s12) }
            VStack(alignment: .leading, spacing: 0) {
                Text(tour.hotelTitle).htStyle(.headline).foregroundStyle(HTColor.ink).lineLimit(1)
                Text("\(tour.area) · \(tour.meal.title) · ★ \(HTFormat.rating(tour.rating)) (\(tour.reviewsCount))")
                    .htStyle(.footnote).foregroundStyle(HTColor.ink2).lineLimit(1)
                    .padding(.top, HTSpace.s4)
                Text(HTFormat.seatsLeft(tour.seatsLeft))
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(HTColor.danger)
                    .padding(.top, HTSpace.s10)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("от \(HTFormat.uzs(tour.price))").htStyle(.priceS).foregroundStyle(HTColor.ink)
                            .lineLimit(1).minimumScaleFactor(0.85)
                        HStack(spacing: HTSpace.s4) {
                            HTOldPrice(tour.oldPrice)
                            Text("· \(HTFormat.forTravelers(tour.adults))").htStyle(.footnote).foregroundStyle(HTColor.ink3)
                        }
                        .lineLimit(1)
                    }
                    Spacer(minLength: HTSpace.s8)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HTColor.onLime)
                        .frame(width: HTSize.roundAction, height: HTSize.roundAction)
                        .background(HTColor.lime, in: Circle())
                }
                .padding(.top, HTSpace.s4)
            }
            .padding(HTSpace.s16)
        }
        .htCard(radius: HTRadius.summary)
    }
}

/// Строка избранного 112 pt (spec-iter07 §5.3): фото 96 × 96, название, мета, цена со скидкой, сердце.
struct FavoriteTourRow: View {
    @Environment(AppRouter.self) private var router
    let tour: Tour
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HTSpace.s14) {
                HTThumb(name: tour.thumbName, size: CGSize(width: HTSize.favoriteThumb, height: HTSize.favoriteThumb))
                    .htZoomSource(tour)
                VStack(alignment: .leading, spacing: HTSpace.s4) {
                    Text(tour.destination.countryFirst).htStyle(.headline).foregroundStyle(HTColor.ink).lineLimit(1)
                        .padding(.trailing, HTSpace.s28)
                    Text("\(tour.hotelName) · \(HTFormat.nights(tour.nights))")
                        .htStyle(.footnote).foregroundStyle(HTColor.ink2).lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: HTSpace.s8) {
                        Text(HTFormat.uzs(tour.price)).htStyle(HTTextStyle(17, 22, .bold, monoDigits: true))
                            .foregroundStyle(HTColor.ink).lineLimit(1)
                        HTDiscountChip(tour.discountPercent)
                    }
                }
                .padding(.vertical, HTSpace.s10)
                Spacer(minLength: 0)
            }
            .padding(HTSpace.s8)
            .frame(height: HTSize.favoriteRow)
            .htCard(radius: HTRadius.summary)
        }
        .buttonStyle(HTPressStyle(scale: 0.98))
        .overlay(alignment: .topTrailing) {
            Button { router.toggleFavorite(tour) } label: {
                Image(systemName: "heart.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(HTColor.ink)
                    .frame(width: HTSize.hitArea, height: HTSize.hitArea)
            }
            .buttonStyle(HTPressStyle(scale: 0.9))
            .accessibilityLabel("Убрать из избранного")
            .padding(HTSpace.s4)
        }
        .accessibilityIdentifier("tourCard.\(tour.id)")
    }
}
