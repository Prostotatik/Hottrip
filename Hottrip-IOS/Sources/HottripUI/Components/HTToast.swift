import SwiftUI

/// Тост избранного: `ink`, r 18, поля экрана 20; «Отменить» (лайм) возвращает сердце.
/// Показывается над нижним баром с зазором 12 и сам скрывается через `HTMotion.toastDuration`.
public struct HTFavoriteToast: View {
    let onUndo: () -> Void

    public init(onUndo: @escaping () -> Void) { self.onUndo = onUndo }

    public var body: some View {
        HStack(spacing: HTSpace.s12) {
            Image(systemName: "bell").font(.system(size: HTIcon.inline, weight: .medium)).foregroundStyle(.white)
            Text("Следим за ценой. Сообщим, если станет дешевле")
                .htStyle(.footnote).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HTTextButton("Отменить", color: HTColor.lime, action: onUndo)
        }
        .padding(.horizontal, HTSpace.s16)
        .padding(.vertical, HTSpace.s4)
        .background(HTColor.ink, in: RoundedRectangle(cornerRadius: HTRadius.card, style: .continuous))
        .htShadow(.raised)
        .htScreenPadding()
        .padding(.bottom, HTSpace.s12)
    }

    @MainActor
    public static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
}

public extension View {
    /// Автоскрытие тоста: через `HTMotion.toastDuration` сбрасывает `isVisible` (только в приложении).
    /// `key` перезапускает отсчёт, пока тост уже виден (лайк второго тура в выдаче — снова полные 2,5 с).
    func htToastAutoHide(_ isVisible: Binding<Bool>, key: AnyHashable? = nil, mode: HTRenderMode,
                         reduceMotion: Bool) -> some View {
        task(id: ToastTimerID(visible: isVisible.wrappedValue, key: key)) {
            guard isVisible.wrappedValue, mode == .interactive else { return }
            try? await Task.sleep(for: .seconds(HTMotion.toastDuration))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? HTMotion.fade : HTMotion.toast) { isVisible.wrappedValue = false }
        }
    }
}

private struct ToastTimerID: Hashable {
    let visible: Bool
    let key: AnyHashable?
}
