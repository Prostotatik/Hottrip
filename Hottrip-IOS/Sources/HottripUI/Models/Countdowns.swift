import Foundation

/// Таймер подборки (I-02): честный ноль и новый срок. Чистая функция времени — одинакова в приложении и снапшоте.
public enum SelectionPhase: Equatable, Sendable {
    case running(remaining: Int)
    case lastMinute(remaining: Int)
    case expired
    case renewed(remaining: Int, date: Date)

    public static func at(_ now: Date, deadline: Date = MockData.selectionDeadline) -> SelectionPhase {
        let left = deadline.timeIntervalSince(now)
        if left > 60 { return .running(remaining: Int(left.rounded(.up))) }
        if left > 0 { return .lastMinute(remaining: Int(left.rounded(.up))) }
        if left > -HTMotionTiming.renewDelay { return .expired }
        let next = deadline.addingTimeInterval(MockData.selectionRenewal)
        return .renewed(remaining: max(0, Int(next.timeIntervalSince(now).rounded(.up))), date: next)
    }

    public var remaining: Int {
        switch self {
        case .running(let r), .lastMinute(let r), .renewed(let r, _): r
        case .expired: 0
        }
    }

    public var caption: String {
        switch self {
        case .running, .lastMinute: "Успей забронировать"
        case .expired: "Подборка обновляется"
        case .renewed(_, let date): "Новая подборка · \(HTFormat.dayMonth(date))"
        }
    }

    public var isLastMinute: Bool { if case .lastMinute = self { true } else { false } }
    public var isExpired: Bool { self == .expired }
}

/// Замок цены на оплате: 15:00 → 0, затем 0,8 с «Проверяем цену…» и новый срок.
public struct PriceLock: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case active, soon, rechecking }

    public let phase: Phase
    public let remaining: Int
    /// Цена уже один раз перепроверена и закреплена заново.
    public let renewed: Bool
    /// Меньше трёх минут — справа от заголовка «Оплата» появляется чип «Цена закреплена»; раньше его нет.
    public static let warning = 180

    public static func at(_ now: Date, startedAt: Date, duration: TimeInterval = MockData.priceLockDuration) -> PriceLock {
        let cycle = duration + HTMotionTiming.recheck
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        let index = floor(elapsed / cycle)
        let t = elapsed - index * cycle
        if t >= duration { return PriceLock(phase: .rechecking, remaining: 0, renewed: index > 0) }
        let remaining = Int((duration - t).rounded(.down))
        return PriceLock(phase: remaining < PriceLock.warning ? .soon : .active, remaining: remaining, renewed: index > 0)
    }
}

/// Длительности, которые участвуют в логике моделей (а не только в анимации).
enum HTMotionTiming {
    static let recheck: TimeInterval = 0.8
    static let renewDelay: TimeInterval = 2
}
