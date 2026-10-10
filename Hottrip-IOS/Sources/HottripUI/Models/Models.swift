import Foundation

public struct Destination: Identifiable, Hashable, Sendable {
    public let id: String
    public let city: String
    public let country: String
    public let airport: String
    /// Фото-слот направления (`dest-*`, spec-iter07 §6.1).
    public let imageName: String

    /// «Анталья, Турция» — сводка оплаты и брони.
    public var title: String { "\(city), \(country)" }
    /// «Турция, Анталья» — заголовок на фото тура и поле «Куда».
    public var countryFirst: String { "\(country), \(city)" }
}

/// Карточка «Популярные направления» (страна целиком).
public struct CountryHighlight: Identifiable, Hashable, Sendable {
    public let id: String
    public let country: String
    public let imageName: String
    public let destination: Destination
}

public struct TourOperator: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
}

public struct OperatorOffer: Identifiable, Hashable, Sendable {
    public var id: String { tourOperator.id }
    public let tourOperator: TourOperator
    public let price: Int
}

public enum MealPlan: String, Hashable, Sendable {
    case allInclusive, breakfast

    public var title: String {
        switch self {
        case .allInclusive: "Всё включено"
        case .breakfast: "Завтраки"
        }
    }
    public var short: String {
        switch self {
        case .allInclusive: "всё вкл."
        case .breakfast: "завтраки"
        }
    }
}

public struct IncludedItem: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case flight, hotel, transfer, insurance }
    public var id: String { kind.rawValue }
    public let kind: Kind
    public let title: String
    /// Пояснение в скобках: в строку с заголовком (перелёт) или второй строкой.
    public let note: String?
    /// Подробности, которые раскрываются по тапу.
    public let detail: String
}

public struct Flight: Hashable, Sendable {
    public let number: String
    public let airline: String
    public let departure: Date
    public let arrival: Date
}

public struct GalleryPhoto: Hashable, Sendable {
    public let imageName: String
    public let caption: String
}

public struct Tour: Identifiable, Hashable, Sendable {
    public let id: String
    public let destination: Destination
    public let hotelName: String
    public let hotelStars: Int
    public let area: String
    public let seaDistance: String
    public let about: String
    public let room: String
    public let departureDate: Date
    public let nights: Int
    public let meal: MealPlan
    public let rating: Double
    public let reviewsCount: Int
    public let seatsLeft: Int
    public let oldPrice: Int
    public let offers: [OperatorOffer]
    public let flight: Flight
    public let coverName: String
    public let thumbName: String
    public let gallery: [GalleryPhoto]
    /// Доли цены на двоих: перелёт и страховка пересчитываются на число туристов (`MockData.priced`).
    public let flightCost: Int
    public let transferCost: Int
    public let insuranceCost: Int
    /// Сколько взрослых летит. Моки заданы на двоих; `MockData.priced(_:adults:)` пересчитывает цены на выбор в поиске.
    public var adults = 2

    public var hotelTitle: String { "\(hotelName) \(hotelStars)★" }
    public var bestOffer: OperatorOffer { offers.min { $0.price < $1.price }! }
    public var price: Int { bestOffer.price }
    public var returnDate: Date { Calendar.tashkent.date(byAdding: .day, value: nights, to: departureDate)! }
    /// «Горящий» — вылет в ближайшие `MockData.hotWindowDays` дней от «сейчас» демо.
    public var isHot: Bool { departureDate >= MockData.hotWindowStart && departureDate < MockData.hotWindowEnd }

    public func discountPercent(for price: Int) -> Int {
        Int((Double(oldPrice - price) / Double(oldPrice) * 100).rounded())
    }
    public var discountPercent: Int { discountPercent(for: price) }

    public var included: [IncludedItem] {
        [
            IncludedItem(kind: .flight, title: "Авиаперелёт", note: "(Ташкент – \(destination.city.replacingOccurrences(of: "-", with: "\u{2011}")) – Ташкент)",
                         detail: "\(flight.airline), рейс \(flight.number), \(HTFormat.dayTime(flight.departure)). Багаж 23 кг и ручная кладь 8 кг"),
            IncludedItem(kind: .hotel, title: "Проживание \(HTFormat.nights(nights))",
                         note: "(отель \(hotelStars)★, \(meal.title.lowercased()))",
                         detail: "\(hotelName), номер \(room). До моря \(seaDistance)"),
            IncludedItem(kind: .transfer, title: "Трансфер", note: "(аэропорт – отель – аэропорт)",
                         detail: "Групповой автобус, гид встречает в зоне прилёта"),
            IncludedItem(kind: .insurance, title: "Страховка", note: nil,
                         detail: "Медицинская, покрытие 30\u{00A0}000\u{00A0}€ на каждого туриста"),
        ]
    }
}

public enum SortOrder: String, CaseIterable, Identifiable, Hashable, Sendable {
    case cheaper, discount, rating, earlier
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .cheaper: "Дешевле"
        case .discount: "Больше скидки"
        case .rating: "Рейтинг"
        case .earlier: "Раньше вылет"
        }
    }
}

public struct SearchQuery: Hashable, Sendable {
    public var destination: Destination?
    /// Первый день окна вылета; окно — `MockData.departureFlexDays` дней вперёд. `nil` — подборка без дат
    /// («Горящие предложения», промо-баннер): тогда даты задаёт окно горящих туров.
    public var dateFrom: Date?
    /// Центр диапазона ночей (±`MockData.nightsSpread`); `nil` — любая длительность.
    public var nights: Int?
    public var adults: Int
    public var budget: Int
    public var hotOnly: Bool

    /// Последний день окна вылета.
    public var dateTo: Date? {
        dateFrom.map { Calendar.tashkent.date(byAdding: .day, value: MockData.departureFlexDays, to: $0)! }
    }
    public var nightsRange: ClosedRange<Int>? { nights.map(Self.nightsRange(around:)) }

    /// 7 → 6...8 (±`MockData.nightsSpread`, не меньше одной ночи).
    public static func nightsRange(around n: Int) -> ClosedRange<Int> {
        max(1, n - MockData.nightsSpread)...(n + MockData.nightsSpread)
    }
}

public struct PaymentMethod: Identifiable, Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable { case payme, click, uzum, card, installment }
    public var id: String { kind.rawValue }
    public let kind: Kind
    public let name: String
    /// Вторая строка (только у рассрочки: «до 12 месяцев»).
    public let subtitle: String?
}

public struct Booking: Hashable, Sendable {
    public let number: String
    public let tour: Tour
    public let offer: OperatorOffer
    public let method: PaymentMethod
    /// Срок рассрочки, если оплачено в рассрочку.
    public let installmentMonths: Int?
    public let email: String
    public let paidAt: Date
}

public struct UserProfile: Hashable, Sendable {
    public let name: String
    public let initials: String
    public let phone: String
    public let email: String
    public let trips: Int
    public let activeTrips: Int
    public let bonuses: Int
}
