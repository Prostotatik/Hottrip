import Foundation

/// Моки демо (design-concept-iter01 §4, таблица туров). Цены заданы в UZS за двоих (пересчёт на N — `priced`), вылет из Ташкента.
/// Все даты — от фиксированной `referenceDate`, поэтому снапшоты детерминированы.
public enum MockData {
    /// «Сейчас» демо: 30 сентября 2026, 09:41 (Ташкент).
    public static let referenceDate = date(9, 30, 9, 41)
    /// Конец текущей подборки: на главной 12:34:27.
    public static let selectionDeadline = referenceDate.addingTimeInterval(12 * 3600 + 34 * 60 + 27)
    /// Длина нового срока после обнуления таймера (I-02).
    public static let selectionRenewal: TimeInterval = 24 * 3600
    /// Срок закрепления цены на оплате.
    public static let priceLockDuration: TimeInterval = 15 * 60
    /// Когда в демо «последний раз обновились цены» в выдаче.
    public static let pricesUpdatedAt = referenceDate.addingTimeInterval(-60)
    public static let budgetRange = 3_000_000...40_000_000
    /// «Горящие» = вылет в ближайшие 7 дней.
    public static let hotWindowDays = 7
    /// Окно горящих: с завтрашнего дня `hotWindowDays` дней (1–7 окт) — его же печатает шапка подборок без дат.
    public static let hotWindowStart = Calendar.tashkent.date(byAdding: .day, value: 1,
                                                             to: Calendar.tashkent.startOfDay(for: referenceDate))!
    public static let hotWindowEnd = Calendar.tashkent.date(byAdding: .day, value: hotWindowDays, to: hotWindowStart)!
    /// Последний день окна горящих (подпись «1–7 окт» в шапке выдачи).
    public static var hotWindowLastDay: Date { Calendar.tashkent.date(byAdding: .day, value: -1, to: hotWindowEnd)! }
    /// Поле «Вылет» задаёт окно вылета: выбранный день и ещё столько дней вперёд (3 окт → 3–10 окт).
    public static let departureFlexDays = 7
    /// Число ночей в поиске — диапазон ±1 (7 → 6–8 ночей).
    public static let nightsSpread = 1
    /// Карта, которая проходит проверку Луна, но «банк отклоняет» — так в демо показывается отказ банка.
    public static let declinedCard = "8600 4930 1234 5678"
    public static let bookingNumber = "HT-2410-7731"

    static func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        Calendar.tashkent.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: Операторы

    public static let anex = TourOperator(id: "anex", name: "ANEX Tour")
    public static let coral = TourOperator(id: "coral", name: "Coral Travel")
    public static let pegas = TourOperator(id: "pegas", name: "Pegas Touristik")

    /// Наценки операторов относительно самого дешёвого для t1; для остальных туров масштабируются по цене.
    static let operatorMarkups: [(TourOperator, Int)] = [(anex, 0), (coral, 410_000), (pegas, 770_000)]

    static func offers(_ price: Int) -> [OperatorOffer] {
        operatorMarkups.map { op, markup in
            let scaled = Int((Double(markup) * Double(price) / 9_480_000 / 10_000).rounded()) * 10_000
            return OperatorOffer(tourOperator: op, price: price + scaled)
        }
    }

    // MARK: Направления

    public static let antalya = Destination(id: "antalya", city: "Анталья", country: "Турция", airport: "AYT", imageName: "dest-turkey")
    public static let sharm = Destination(id: "sharm", city: "Шарм-эш-Шейх", country: "Египет", airport: "SSH", imageName: "dest-egypt")
    public static let dubai = Destination(id: "dubai", city: "Дубай", country: "ОАЭ", airport: "DXB", imageName: "dest-uae")
    public static let istanbul = Destination(id: "istanbul", city: "Стамбул", country: "Турция", airport: "IST", imageName: "dest-turkey")
    public static let phuket = Destination(id: "phuket", city: "Пхукет", country: "Таиланд", airport: "HKT", imageName: "dest-thailand")
    public static let tbilisi = Destination(id: "tbilisi", city: "Тбилиси", country: "Грузия", airport: "TBS", imageName: "dest-georgia")
    public static let destinations = [antalya, sharm, dubai, istanbul, phuket, tbilisi]

    /// «Популярные направления» на поиске: ровно три карточки, как в референсе.
    public static let highlights: [CountryHighlight] = [
        CountryHighlight(id: "turkey", country: "Турция", imageName: "dest-turkey", destination: antalya),
        CountryHighlight(id: "uae", country: "ОАЭ", imageName: "dest-uae", destination: dubai),
        CountryHighlight(id: "egypt", country: "Египет", imageName: "dest-egypt", destination: sharm),
    ]

    // MARK: Туры

    static func tour(_ id: String, _ destination: Destination, hotel: String, stars: Int, area: String, sea: String,
                     depart: Date, arrive: Date, flight: String, nights: Int, meal: MealPlan,
                     rating: Double, reviews: Int, seats: Int, price: Int, old: Int,
                     flightCost: Int, cover: String, standaloneCover: Bool = false, gallery: [GalleryPhoto]? = nil,
                     room: String = "Standard", about: String) -> Tour {
        let coverName = standaloneCover ? "tour-\(cover)" : "tour-\(cover)-cover"
        return Tour(id: id, destination: destination, hotelName: hotel, hotelStars: stars, area: area, seaDistance: sea,
             about: about, room: room, departureDate: depart, nights: nights, meal: meal,
             rating: rating, reviewsCount: reviews, seatsLeft: seats, oldPrice: old,
             offers: offers(price),
             flight: Flight(number: flight, airline: "Uzbekistan Airways", departure: depart, arrival: arrive),
             // Обложка 2:1, миниатюра 96 × 104 и кадр галереи ~1:1 — отдельные кропы одного кадра (asset-plan-iter07 §2).
             coverName: coverName, thumbName: "tour-\(cover)-thumb",
             gallery: gallery ?? [GalleryPhoto(imageName: "tour-\(cover)-gallery", caption: hotel)],
             flightCost: flightCost, transferCost: 280_000, insuranceCost: 320_000)
    }

    public static let t1 = tour("t1", antalya, hotel: "Lara Sands Resort", stars: 5, area: "Лара", sea: "300 м",
        depart: date(10, 3, 6, 40), arrive: date(10, 3, 10, 15), flight: "HY 3651", nights: 7, meal: .allInclusive,
        rating: 4.8, reviews: 124, seats: 3, price: 9_480_000, old: 13_950_000, flightCost: 3_900_000, cover: "t1",
        gallery: [
            GalleryPhoto(imageName: "tour-t1-1", caption: "Бухта и пирс отеля"),
            GalleryPhoto(imageName: "tour-t1-2", caption: "Пляж отеля"),
            GalleryPhoto(imageName: "tour-t1-3", caption: "Номер Standard Sea View"),
            GalleryPhoto(imageName: "tour-t1-4", caption: "Бассейн с видом на море"),
        ],
        room: "Standard Sea View",
        about: "Первая линия, собственный песчаный пляж, 3\u{00A0}бассейна и аквапарк. Wi-Fi на всей территории. Детский клуб с\u{00A0}4\u{00A0}лет.")

    public static let t2 = tour("t2", sharm, hotel: "Reef Garden Bay", stars: 4, area: "Наама-Бей", sea: "150 м",
        depart: date(10, 4, 5, 20), arrive: date(10, 4, 8, 50), flight: "HY 3721", nights: 8, meal: .allInclusive,
        rating: 4.6, reviews: 89, seats: 2, price: 8_120_000, old: 11_300_000, flightCost: 3_600_000, cover: "t2",
        about: "Собственный коралловый риф у пирса, два бассейна, анимация по вечерам.")

    public static let t3 = tour("t3", dubai, hotel: "Marina Loft Hotel", stars: 4, area: "Дубай Марина", sea: "600 м",
        depart: date(10, 5, 8, 10), arrive: date(10, 5, 10, 25), flight: "HY 2011", nights: 5, meal: .breakfast,
        rating: 4.7, reviews: 211, seats: 4, price: 11_740_000, old: 15_200_000, flightCost: 3_300_000, cover: "t3",
        about: "Лофт-номера с видом на марину, бассейн на крыше, метро в 5 минутах.")

    public static let t4 = tour("t4", istanbul, hotel: "Galata Terrace", stars: 4, area: "Бейоглу", sea: "—",
        depart: date(10, 3, 7, 30), arrive: date(10, 3, 10, 40), flight: "HY 3701", nights: 4, meal: .breakfast,
        rating: 4.5, reviews: 156, seats: 5, price: 6_350_000, old: 8_400_000, flightCost: 3_100_000, cover: "t4",
        about: "Терраса с видом на Галатскую башню и Босфор, пешком до Истикляль.")

    public static let t5 = tour("t5", phuket, hotel: "Kata Palm Villas", stars: 4, area: "Ката", sea: "250 м",
        depart: date(10, 7, 0, 40), arrive: date(10, 7, 10, 5), flight: "HY 5531", nights: 10, meal: .breakfast,
        rating: 4.7, reviews: 64, seats: 2, price: 14_900_000, old: 19_800_000, flightCost: 6_200_000, cover: "t5",
        about: "Виллы в пальмовом саду, бассейн у каждого корпуса, пляж Ката в 3 минутах.")

    public static let t6 = tour("t6", tbilisi, hotel: "Old Town Rooms", stars: 3, area: "Старый город", sea: "—",
        depart: date(10, 4, 9, 0), arrive: date(10, 4, 10, 5), flight: "HY 2801", nights: 4, meal: .breakfast,
        rating: 4.4, reviews: 97, seats: 4, price: 4_980_000, old: 6_100_000, flightCost: 2_100_000, cover: "t6",
        about: "Дом с резными балконами в Сололаки, до серных бань 10 минут пешком.")

    static let antalyaFlight = (depart: date(10, 3, 6, 40), arrive: date(10, 3, 10, 15))

    public static let antalyaAlternatives: [Tour] = [
        tour("a1", antalya, hotel: "Belek Pine Club", stars: 5, area: "Белек", sea: "200 м",
             depart: antalyaFlight.depart, arrive: antalyaFlight.arrive, flight: "HY 3651", nights: 7, meal: .allInclusive,
             rating: 4.7, reviews: 188, seats: 4, price: 10_120_000, old: 14_300_000, flightCost: 3_900_000, cover: "antalya-alt-1", standaloneCover: true,
             about: "Сосновый парк у моря, гольф-поле рядом, пять ресторанов."),
        tour("a2", antalya, hotel: "Side Olive Garden", stars: 4, area: "Сиде", sea: "400 м",
             depart: antalyaFlight.depart, arrive: antalyaFlight.arrive, flight: "HY 3651", nights: 7, meal: .allInclusive,
             rating: 4.6, reviews: 212, seats: 2, price: 7_640_000, old: 10_200_000, flightCost: 3_900_000, cover: "antalya-alt-2", standaloneCover: true,
             about: "Оливковая роща, тихий семейный отель, свой участок пляжа."),
        tour("a3", antalya, hotel: "Kemer Hills", stars: 4, area: "Кемер", sea: "350 м",
             depart: date(10, 10, 6, 40), arrive: date(10, 10, 10, 15), flight: "HY 3651", nights: 7, meal: .allInclusive,
             rating: 4.5, reviews: 143, seats: 5, price: 7_990_000, old: 10_900_000, flightCost: 3_900_000, cover: "antalya-alt-3", standaloneCover: true,
             about: "Вид на горы Таврского хребта, галечный пляж, спа-центр."),
    ]

    public static let featuredTours = [t1, t2, t4, t3, t5, t6]
    /// Все туры демо. Kemer Hills вылетает 10 октября — вне окна «горящих», его видно только с выключенным фильтром.
    public static let allTours = featuredTours + antalyaAlternatives
    public static let defaultFavorites: Set<String> = ["t3", "t5", "t6"]

    // MARK: Поиск

    public static let defaultQuery = SearchQuery(destination: antalya, dateFrom: date(10, 3), nights: 7, adults: 2,
                                                 budget: 15_000_000, hotOnly: true)
    /// Подборка без дат: все горящие туры (окно `hotWindowStart…hotWindowEnd`), любой бюджет.
    public static func selectionQuery(_ destination: Destination? = nil, adults: Int = 2) -> SearchQuery {
        SearchQuery(destination: destination, dateFrom: nil, nights: nil, adults: adults,
                    budget: budgetRange.upperBound, hotOnly: true)
    }
    public static let allHotQuery = selectionQuery()

    /// Туры запроса с ценами на выбранное число туристов.
    public static func search(_ q: SearchQuery, sort: SortOrder = .cheaper) -> [Tour] {
        candidates(q).filter { $0.price <= q.budget }.sorted(by: sort)
    }

    /// Цена «от» для карточки направления/строки избранного — самый дешёвый тур той же подборки, что откроется по тапу.
    public static func fromPrice(_ q: SearchQuery) -> Int? { candidates(q).map(\.price).min() }

    static func candidates(_ q: SearchQuery) -> [Tour] {
        allTours.filter { matches(q, $0) }.map { priced($0, adults: q.adults) }
    }

    static func matches(_ q: SearchQuery, _ tour: Tour) -> Bool {
        var inWindow = true
        if let from = q.dateFrom, let to = q.dateTo {
            let cal = Calendar.tashkent
            let day = cal.startOfDay(for: tour.departureDate)
            inWindow = day >= cal.startOfDay(for: from) && day <= cal.startOfDay(for: to)
        }
        return (q.destination == nil || tour.destination == q.destination)
            && inWindow
            && (q.nightsRange?.contains(tour.nights) ?? true)
            && (!q.hotOnly || tour.isHot)
            // Тур продаётся, только если мест хватает на всех туристов запроса.
            && tour.seatsLeft >= q.adults
    }

    /// Почему запрос пуст — чтобы подсказки на поиске, в sheet дат и в выдаче винили настоящую причину.
    public enum EmptyReason: Equatable {
        /// Туры есть, но все дороже бюджета; ближайшая цена.
        case budget(nearest: Int)
        /// На даты туры есть, но ни в одном не хватает мест на всех туристов.
        case seats
        /// Под даты / ночи / направление туров нет вообще.
        case dates
    }

    /// `nil`, если запрос что-то находит.
    public static func emptyReason(_ q: SearchQuery) -> EmptyReason? {
        guard search(q).isEmpty else { return nil }
        if let nearest = nearestAbove(q) { return .budget(nearest: nearest.price) }
        var anySeats = q
        anySeats.adults = 1
        return allTours.contains { matches(anySeats, $0) } ? .seats : .dates
    }

    // MARK: Цена на N туристов

    /// Доля номера на N взрослых относительно двухместного: одному — одноместное размещение (75 % цены номера),
    /// третьему — доп. кровать (+40 %), четверо — два номера.
    static let roomShare: [Int: Double] = [1: 0.75, 2: 1, 3: 1.4, 4: 2]

    /// Цена тура на `adults` взрослых из цены на двоих: перелёт и страховка — за каждого, трансфер — на группу,
    /// отель — по размещению. Округление до 10 000; остаток округления уходит в отель, раскладка сходится.
    static func price(_ priceForTwo: Int, adults: Int, flight: Int, transfer: Int, insurance: Int) -> Int {
        let hotel = Double(priceForTwo - flight - transfer - insurance)
        let raw = Double((flight + insurance) * adults / 2 + transfer) + hotel * (roomShare[adults] ?? Double(adults) / 2)
        return Int((raw / 10_000).rounded()) * 10_000
    }

    /// Тур с ценами (все операторы, «Было», доли раскладки) на выбранное число взрослых.
    public static func priced(_ t: Tour, adults: Int) -> Tour {
        guard adults != t.adults else { return t }
        precondition(t.adults == 2, "Пересчёт идёт от цены на двоих")
        func scale(_ p: Int) -> Int {
            price(p, adults: adults, flight: t.flightCost, transfer: t.transferCost, insurance: t.insuranceCost)
        }
        return Tour(id: t.id, destination: t.destination, hotelName: t.hotelName,
                    hotelStars: t.hotelStars, area: t.area, seaDistance: t.seaDistance, about: t.about, room: t.room,
                    departureDate: t.departureDate, nights: t.nights, meal: t.meal, rating: t.rating,
                    reviewsCount: t.reviewsCount, seatsLeft: t.seatsLeft, oldPrice: scale(t.oldPrice),
                    offers: t.offers.map { OperatorOffer(tourOperator: $0.tourOperator, price: scale($0.price)) },
                    flight: t.flight, coverName: t.coverName, thumbName: t.thumbName, gallery: t.gallery,
                    flightCost: t.flightCost * adults / 2, transferCost: t.transferCost,
                    insuranceCost: t.insuranceCost * adults / 2, adults: adults)
    }

    /// Самый дешёвый тур, не попадающий в бюджет, — чтобы подсказка под слайдером была честной.
    public static func nearestAbove(_ q: SearchQuery) -> Tour? {
        candidates(q).filter { $0.price > q.budget }.min { $0.price < $1.price }
    }

    // MARK: Оплата

    /// Сроки рассрочки без процентов; по умолчанию — самый длинный.
    public static let installmentTerms = [3, 6, 12]
    public static var installmentMonths: Int { installmentTerms.last! }

    /// Ежемесячный платёж: цена / месяцы, округлённая до 100 сумов.
    public static func installmentMonthly(_ price: Int, months: Int = installmentMonths) -> Int {
        Int((Double(price) / Double(months) / 100).rounded()) * 100
    }

    public static func installmentIsExact(_ price: Int, months: Int = installmentMonths) -> Bool {
        installmentMonthly(price, months: months) * months == price
    }

    public static let paymentMethods: [PaymentMethod] = [
        PaymentMethod(kind: .payme, name: "Payme", subtitle: nil),
        PaymentMethod(kind: .click, name: "Click", subtitle: nil),
        PaymentMethod(kind: .uzum, name: "Uzum", subtitle: nil),
        PaymentMethod(kind: .card, name: "Humo / Uzcard", subtitle: nil),
        PaymentMethod(kind: .installment, name: "В рассрочку", subtitle: "до \(installmentMonths) месяцев"),
    ]

    public static let user = UserProfile(name: "Азиз Каримов", initials: "АК", phone: "+998 90 123-45-67",
                                         email: "aziz.karimov@mail.uz", trips: 2, activeTrips: 1, bonuses: 120_000)

    public static func booking(_ tour: Tour, _ offer: OperatorOffer, _ method: PaymentMethod, months: Int? = nil,
                               paidAt: Date = referenceDate.addingTimeInterval(4 * 60)) -> Booking {
        Booking(number: bookingNumber, tour: tour, offer: offer, method: method,
                installmentMonths: method.kind == .installment ? months ?? installmentMonths : nil,
                email: user.email, paidAt: paidAt)
    }

    public static var sampleBooking: Booking { booking(t1, t1.bestOffer, paymentMethods[0]) }
}

extension Array where Element == Tour {
    func sorted(by order: SortOrder) -> [Tour] {
        switch order {
        case .cheaper: sorted { $0.price < $1.price }
        case .discount: sorted { $0.discountPercent > $1.discountPercent }
        case .rating: sorted { $0.rating > $1.rating }
        case .earlier: sorted { ($0.departureDate, $0.price) < ($1.departureDate, $1.price) }
        }
    }
}

public extension Calendar {
    static let tashkent: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tashkent")!
        c.locale = Locale(identifier: "ru_RU")
        return c
    }()
}
