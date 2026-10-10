import SwiftUI

/// Каркас светлого экрана: фон `canvas`, закреплённый нижний бар поверх контента, подложка под строкой состояния.
public struct HTScreen<Content: View, Bar: View>: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htStatusKey) private var statusKey
    @Environment(\.htSafeArea) private var safe
    @Environment(\.htRenderMode) private var mode
    @State private var scrolled = false
    let content: Content
    let bar: Bar

    public init(@ViewBuilder content: () -> Content, @ViewBuilder bar: () -> Bar) {
        self.content = content(); self.bar = bar()
    }

    public var body: some View {
        let underLight = router.statusBarTones[statusKey] ?? false
        return ZStack(alignment: .bottom) {
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            bar
        }
        // Фон и под клавиатурой: экран с полем ввода сжимается над ней, а за парящей клавиатурой iOS 27
        // иначе видна белая подложка окна.
        .background(HTColor.canvas.ignoresSafeArea(.keyboard))
        // Подложка под строкой состояния: прокручиваемый контент не лезет под часы; когда контент уехал под неё —
        // волосяная линия. Над фото тура подложки нет — там строка светлая прямо поверх фото.
        .overlay(alignment: .top) {
            if mode == .interactive && !underLight {
                HTColor.canvasTop.frame(height: safe.top)
                    .overlay(alignment: .bottom) { if scrolled { HTHairline().transition(.opacity) } }
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(HTScrollEdgeKey.self) { if scrolled != $0.scrolled { scrolled = $0.scrolled } }
        .animation(HTMotion.fade, value: underLight)
        .animation(HTMotion.fade, value: scrolled)
    }
}

public extension HTScreen where Bar == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, bar: { EmptyView() })
    }
}

/// Шапка 44 pt: назад слева, по центру заголовок, справа действие.
public struct HTNavBar<Center: View, Trailing: View>: View {
    let chevron: Bool
    let center: Center
    let trailing: Trailing

    public init(chevron: Bool = false, @ViewBuilder center: () -> Center = { EmptyView() },
                @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.chevron = chevron; self.center = center(); self.trailing = trailing()
    }

    public var body: some View {
        ZStack {
            center.padding(.horizontal, HTSize.hitArea + HTSpace.s8)
            HStack(spacing: 0) {
                HTBackButton(chevron: chevron)
                Spacer(minLength: 0)
                trailing
            }
        }
        .htScreenPadding()
        .frame(height: HTSize.hitArea)
    }
}

/// Липкая CTA внизу экрана: над ней фейд 24 pt из `fade` в прозрачное, под ней — нижняя safe area.
public struct HTStickyBar<Content: View>: View {
    @Environment(\.htSafeArea) private var safe
    let fade: Color
    let bottom: CGFloat
    let content: Content

    /// - Parameter bottom: отступ низа содержимого от нижнего края экрана.
    public init(fade: Color = HTColor.canvasBottom, bottom: CGFloat, @ViewBuilder content: () -> Content) {
        self.fade = fade; self.bottom = bottom; self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [fade.opacity(0), fade], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
                .allowsHitTesting(false)
            content
                .htScreenPadding()
                .padding(.bottom, bottom)
                .frame(maxWidth: .infinity)
                .background(fade)
        }
    }
}
