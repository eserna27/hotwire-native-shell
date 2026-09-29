import HotwireNative
import os
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var navigator: Navigator?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "SceneDelegate")

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let config = Shell.current
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        if config.tabs.isEmpty {
            let navigator = Navigator(configuration: .init(
                name: "main",
                startLocation: config.startLocation
            ))
            self.navigator = navigator
            window.rootViewController = navigator.rootViewController
            window.makeKeyAndVisible()
            navigator.start()
            return
        }

        if config.tabs.count > ShellTabs.maxTabs {
            logger.warning("Config declares \(config.tabs.count) tabs; showing the first \(ShellTabs.maxTabs).")
        }

        let tabBarController = HotwireTabBarController(lazyLoadTabs: true)
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        tabBarController.load(ShellTabs.from(config))
    }
}
