import Foundation

public enum HTFormat {
    /// Разделитель тысяч и пробел перед «UZS» — неразрывный пробел.
    static let nbsp = "\u{00A0}"
    public static let minus = "\u{2212}"

    /// 9480000 -> "9 480 000"
    public static func number(_ value: Int) -> String {
        let digits = String(abs(value))
        var groups: [String] = []
        var end = digits.endIndex
        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.insert(String(digits[start..<end]), at: 0)
            end = start
        }
        return (value < 0 ? minus : "") + groups.joined(separator: nbsp)
    }

    /// 9480000 -> "9 480 000 UZS"
    public static func uzs(_ value: Int) -> String { number(value) + nbsp + "UZS" }

    /// 410000 -> "+410 000"
    public static func delta(_ value: Int) -> String { "+" + number(value) }

    /// 32 -> "−32%" (со знаком минус, как в референсе)
    public static func discount(_ percent: Int) -> String { "\(minus)\(percent)%" }

    /// 7000000 -> "7 млн"
    public static func millions(_ value: Int) -> String {
        let m = Double(value) / 1_000_000
        let text = m == m.rounded() ? String(Int(m)) : String(format: "%.1f", m).replacingOccurrences(of: ".", with: ",")
        return text + nbsp + "млн"
    }

    /// 4.8 -> "4,8"
    public static func rating(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = Calendar.tashkent.timeZone
        f.dateFormat = format
        return f
    }
    private static let months = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
    private static let weekdayFormatter = formatter("EEEEEE")
    private static let timeFormatter = formatter("HH:mm")

    /// "3 окт"
    public static func dayMonth(_ date: Date) -> String {
        let c = Calendar.tashkent.dateComponents([.day, .month], from: date)
        return "\(c.day!)\(nbsp)\(months[c.month! - 1])"
    }
    /// "Сб, 3 окт"
    public static func weekdayDay(_ date: Date) -> String {
        weekdayFormatter.string(from: date).capitalized + ", " + dayMonth(date)
    }
    /// "06:40"
    public static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    /// "3 окт, 06:40"
    public static func dayTime(_ date: Date) -> String { "\(dayMonth(date)), \(time(date))" }

    /// "3–10 окт" (один месяц) или "28 сен – 3 окт"
    public static func shortRange(_ from: Date, _ to: Date) -> String {
        let cal = Calendar.tashkent
        if cal.component(.month, from: from) == cal.component(.month, from: to) {
            return "\(cal.component(.day, from: from))–\(dayMonth(to))"
        }
        return "\(dayMonth(from)) – \(dayMonth(to))"
    }
    /// "3 окт – 10 окт" (поле «Даты» на поиске)
    public static func longRange(_ from: Date, _ to: Date) -> String { "\(dayMonth(from)) – \(dayMonth(to))" }

    /// 45267 -> "12:34:27"
    public static func hms(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }
    /// 899 -> "14:59"
    public static func ms(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }

    public static func nights(_ n: Int) -> String { "\(n) \(plural(n, "ночь", "ночи", "ночей"))" }
    public static func reviews(_ n: Int) -> String { "\(n) \(plural(n, "отзыв", "отзыва", "отзывов"))" }
    public static func seats(_ n: Int) -> String { "\(n) \(plural(n, "место", "места", "мест"))" }
    public static func tours(_ n: Int) -> String { "\(n) \(plural(n, "тур", "тура", "туров"))" }
    public static func adults(_ n: Int) -> String { "\(n) \(plural(n, "взрослый", "взрослых", "взрослых"))" }
    /// 6...8 -> "6–8 ночей"
    public static func nightsRange(_ r: ClosedRange<Int>) -> String {
        "\(r.lowerBound)–\(r.upperBound) \(plural(r.upperBound, "ночь", "ночи", "ночей"))"
    }
    /// Подпись цены: «за двоих», «за четверых».
    public static func forTravelers(_ n: Int) -> String {
        switch n {
        case 1: "за одного"
        case 2: "за двоих"
        case 3: "за троих"
        case 4: "за четверых"
        default: "за \(adults(n))"
        }
    }
    /// Шапка выдачи: «3–10 окт · 6–8 ночей · 2 взрослых»; у подборки без дат — окно горящих «1–7 окт · 2 взрослых».
    public static func querySummary(_ q: SearchQuery) -> String {
        // Без дат и без «горящих» окна нет — «Любые даты», а не окно горящих.
        let window = q.dateFrom.flatMap { from in q.dateTo.map { shortRange(from, $0) } }
            ?? (q.hotOnly ? shortRange(MockData.hotWindowStart, MockData.hotWindowLastDay) : "Любые даты")
        return ([window, q.nightsRange.map(nightsRange)].compactMap { $0 } + [adults(q.adults)])
            .joined(separator: " · ")
    }
    public static func seatsLeft(_ n: Int) -> String { "Осталось \(seats(n))" }

    public static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let m10 = n % 10, m100 = n % 100
        if m10 == 1 && m100 != 11 { return one }
        if (2...4).contains(m10) && !(12...14).contains(m100) { return few }
        return many
    }
}
