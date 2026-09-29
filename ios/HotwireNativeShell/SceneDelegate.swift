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

        let resolution = config.resolveTabs(languageTag: Locale.preferredLanguages.first ?? "en")
        logTabs(resolution)

        if resolution.tabs.count < 2 {
            let start = resolution.tabs.first?.location ?? config.startLocation
            let navigator = Navigator(configuration: .init(
                name: "main",
                startLocation: start
            ))
            self.navigator = navigator
            window.rootViewController = navigator.rootViewController
            window.makeKeyAndVisible()
            navigator.start()
            return
        }

        let tabBarController = HotwireTabBarController(lazyLoadTabs: true)
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        tabBarController.load(ShellTabs.from(resolution.tabs))
    }

    private func logTabs(_ resolution: TabResolution) {
        if resolution.dropped > 0 {
            logger.warning("Ignored \(resolution.dropped) invalid tab entries in /native/config.")
        }
        if resolution.overflow > 0 {
            logger.warning("Config has more than \(NativeConfig.maxTabs) valid tabs; showing the first \(NativeConfig.maxTabs).")
        }
        if resolution.tabs.count < 2 {
            logger.info("Single navigator (\(resolution.tabs.count) valid tabs).")
        }
    }
}
