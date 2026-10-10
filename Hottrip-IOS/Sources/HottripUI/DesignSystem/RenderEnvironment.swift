import SwiftUI

/// Режим рендера. В `.snapshot` компоненты избегают того, что ImageRenderer не рисует
/// (ScrollView, TextField, TabView, таймеры) и показывают финальный кадр анимаций.
public enum HTRenderMode: Sendable { case interactive, snapshot }

private struct RenderModeKey: EnvironmentKey { static let defaultValue: HTRenderMode = .interactive }
private struct SafeAreaKey: EnvironmentKey { static let defaultValue = EdgeInsets() }
private struct FullHeightKey: EnvironmentKey { static let defaultValue = false }
private struct NowKey: EnvironmentKey { static let defaultValue: Date? = nil }

public extension EnvironmentValues {
    var htRenderMode: HTRenderMode {
        get { self[RenderModeKey.self] }
        set { self[RenderModeKey.self] = newValue }
    }
    /// Безопасные отступы экрана. Экраны игнорируют системную safe area и применяют эти значения —
    /// так приложение и снапшот выглядят одинаково.
    var htSafeArea: EdgeInsets {
        get { self[SafeAreaKey.self] }
        set { self[SafeAreaKey.self] = newValue }
    }
    /// Снапшот «на всю высоту контента»: HTScroll отдаёт идеальную высоту вместо обрезки.
    var htSnapshotFullHeight: Bool {
        get { self[FullHeightKey.self] }
        set { self[FullHeightKey.self] = newValue }
    }
    /// Фиксированное «сейчас» (снапшоты). nil — живые часы демо.
    var htNow: Date? {
        get { self[NowKey.self] }
        set { self[NowKey.self] = newValue }
    }
    /// Движение запрещено: Reduce Motion или статичный снапшот (показываем финальный кадр).
    var htReduceMotion: Bool { accessibilityReduceMotion || htRenderMode == .snapshot }
}

public extension View {
    func htSnapshotEnvironment(safeArea: EdgeInsets = HTDevice.safeArea, fullHeight: Bool = false) -> some View {
        self
            .environment(\.htSnapshotFullHeight, fullHeight)
            .environment(\.htRenderMode, .snapshot)
            .environment(\.htSafeArea, safeArea)
            .environment(\.htNow, MockData.referenceDate)
            .environment(\.colorScheme, .light)
    }
}

/// Целевое устройство — iPhone 18 Pro, 402 × 874 pt (spec-iter07: safe area 62 / 34).
public enum HTDevice {
    public static let size = CGSize(width: 402, height: 874)
    public static let safeArea = EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)
    public static let cornerRadius: CGFloat = 62
}

/// Часы демо: «сейчас» = `start` (referenceDate) + реальное время с запуска.
public enum DemoClock {
    static let launch = Date()
    /// Демо-время в момент запуска; сдвигает только демо-запуск (`DemoLaunch`, кадры таймера).
    nonisolated(unsafe) static var start = MockData.referenceDate
    public static func now(real: Date = Date()) -> Date {
        start.addingTimeInterval(real.timeIntervalSince(launch))
    }
}

/// Отдаёт текущее время демо раз в `period` секунд; в снапшоте — фиксированное `htNow` без TimelineView.
public struct HTClock<Content: View>: View {
    @Environment(\.htNow) private var fixedNow
    let period: TimeInterval
    let content: (Date) -> Content

    public init(period: TimeInterval = 1, @ViewBuilder content: @escaping (Date) -> Content) {
        self.period = period; self.content = content
    }

    public var body: some View {
        if let fixedNow {
            content(fixedNow)
        } else {
            TimelineView(.periodic(from: .now, by: period)) { ctx in
                content(DemoClock.now(real: ctx.date))
            }
        }
    }
}
