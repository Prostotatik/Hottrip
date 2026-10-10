import SwiftUI

/// Корневой view приложения: NavigationStack (системный бар скрыт) + плавающий таб-бар.
public struct HottripRootView: View {
    @State private var router: AppRouter
    @Namespace private var zoom
    private let demo: DemoLaunch?
    private let onStatusBarChange: (Bool) -> Void

    /// - Parameters:
    ///   - demo: кадр демо-запуска (`DemoLaunch.current`), nil — обычный старт.
    ///   - onStatusBarChange: true — нужен светлый текст строки состояния (применяет UIHostingController приложения).
    public init(demo: DemoLaunch? = nil, onStatusBarChange: @escaping (Bool) -> Void = { _ in }) {
        self.demo = demo
        self.onStatusBarChange = onStatusBarChange
        _router = State(initialValue: demo?.makeRouter() ?? AppRouter())
    }

    public var body: some View {
        GeometryReader { proxy in
            NavigationStack(path: $router.path) {
                TabShell(selected: router.selectedTab)
                    .htHideSystemNavBar()
                    .navigationDestination(for: AppRoute.self) { route in
                        Group {
                            if let screen = demo?.screen(for: route) { screen } else { route.destination }
                        }
                        .environment(\.htStatusKey, AppRouter.statusKey(route: route))
                        // Каждый push-экран получает свою safe area от UINavigationController; отступы берём из
                        // `htSafeArea`, поэтому системную игнорируем (иначе сверху/снизу отступ двойной).
                        // Клавиатуру не игнорируем: экран с полем ввода поднимается над ней.
                        .ignoresSafeArea(.container)
                        .htHideSystemNavBar()
                        .htZoomDestination(route, in: zoom)
                    }
            }
            .environment(router)
            .environment(\.htSafeArea, proxy.safeAreaInsets)
            .environment(\.htZoomNamespace, zoom)
            .ignoresSafeArea()
        }
        .onChange(of: router.statusBarLight, initial: true) { _, light in onStatusBarChange(light) }
    }
}

/// Контейнер вкладок + таб-бар. Используется и приложением, и снапшотами.
public struct TabShell: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.htSafeArea) private var safe
    let selected: HTTab

    public init(selected: HTTab) { self.selected = selected }

    public var body: some View {
        var contentSafe = safe
        contentSafe.bottom = HTSize.tabBar + HTSize.tabBarBottom
        return ZStack(alignment: .bottom) {
            Group {
                switch selected {
                case .home, .search: HomeScreen()
                case .favorites:
                    if let demo = router.demoTabScreen { demo } else {
                        FavoritesScreen(tours: MockData.allTours.filter { router.favorites.contains($0.id) })
                    }
                case .profile: ProfileScreen(user: MockData.user)
                }
            }
            .environment(\.htSafeArea, contentSafe)
            .environment(\.htStatusKey, AppRouter.statusKey(tab: selected))
            HTTabBar(selected: selected, tone: selected == .home ? .dark : .light) { router.select($0) }
                .padding(.bottom, HTSize.tabBarBottom)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Зум-переход «карточка → тур» (P0-4, iOS 18+)

private struct ZoomNamespaceKey: EnvironmentKey { static let defaultValue: Namespace.ID? = nil }
extension EnvironmentValues {
    var htZoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

extension View {
    /// Источник зума: карточка тура в выдаче и в избранном (первое фото тура совпадает с обложкой).
    @ViewBuilder
    func htZoomSource(_ tour: Tour) -> some View {
        #if os(iOS)
        if #available(iOS 18, *) { modifier(ZoomSource(id: tour.id)) } else { self }
        #else
        self
        #endif
    }

    @ViewBuilder
    func htZoomDestination(_ route: AppRoute, in ns: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 18, *), case .tour(let tour) = route {
            navigationTransition(.zoom(sourceID: tour.id, in: ns))
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func htHideSystemNavBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

#if os(iOS)
@available(iOS 18, *)
private struct ZoomSource: ViewModifier {
    @Environment(\.htZoomNamespace) private var ns
    let id: String
    func body(content: Content) -> some View {
        if let ns { content.matchedTransitionSource(id: id, in: ns) } else { content }
    }
}

import UIKit
/// Возвращает свайп «назад» при скрытом системном navigation bar.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
#endif
