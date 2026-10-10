import SwiftUI
import UIKit
import HottripUI

/// Оболочка на UIKit: SwiftUI-`App` не даёт управлять стилем строки состояния по экранам, а нам нужен
/// светлый текст над тёмной главной и фото тура и тёмный — над светлым фоном. Корень — `StatusBarHostingController`.
/// Сцена описана в Info.plist (UISceneConfigurations → SceneDelegate).
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let host = StatusBarHostingController(rootView: AnyView(EmptyView()))
        host.rootView = AnyView(
            HottripRootView(demo: DemoLaunch.current) { [weak host] light in host?.lightStatusBar = light }
        )
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        self.window = window
    }
}

/// Хост SwiftUI, который сам решает стиль строки состояния (дочерний UINavigationController не спрашиваем).
final class StatusBarHostingController: UIHostingController<AnyView> {
    var lightStatusBar = false {
        didSet {
            guard lightStatusBar != oldValue else { return }
            UIView.animate(withDuration: 0.2) { self.setNeedsStatusBarAppearanceUpdate() }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { lightStatusBar ? .lightContent : .darkContent }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
    override var childForStatusBarStyle: UIViewController? { nil }
}
