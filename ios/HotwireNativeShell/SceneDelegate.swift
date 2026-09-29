import HotwireNative
import os
import UIKit

/// Cold start uses `tabs` from `/native/config`. A `tabs` bridge `connect`
/// replaces that list. The same resolved list only changes the selection, so
/// every page can send the markup without rebuilding the navigators.
enum TabChrome {
    static var bridge: PresentedTabs?
    static weak var scene: SceneDelegate?

    static func presented(config: NativeConfig, languageTag: String) -> PresentedTabs {
        if let bridge { return bridge }
        return PresentedTabs(resolution: config.resolveTabs(languageTag: languageTag), selectedIndex: 0)
    }

    static func update(jsonData: String) {
        let config = Shell.current
        let language = Locale.preferredLanguages.first ?? "en"
        guard let next = parsePresentedTabs(jsonData: jsonData, baseUrl: config.baseUrl, languageTag: language) else {
            logger.warning("Ignoring tabs connect that has no tabs array.")
            return
        }
        log(next)
        let current = presented(config: config, languageTag: language)
        bridge = next
        guard let scene else { return }
        if next.resolution.tabs == current.resolution.tabs {
            scene.selectTabIfNeeded(next.selectedIndex)
            return
        }
        DispatchQueue.main.async {
            self.scene?.apply(next)
        }
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "TabChrome")

    private static func log(_ presented: PresentedTabs) {
        let resolution = presented.resolution
        if resolution.dropped > 0 {
            logger.warning("Ignored \(resolution.dropped) invalid tabs bridge entries.")
        }
        if resolution.overflow > 0 {
            logger.warning("Tabs bridge has more than \(NativeConfig.maxTabs) valid tabs; showing the first \(NativeConfig.maxTabs).")
        }
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var navigator: Navigator?
    private var tabBarController: HotwireTabBarController?
    private var showing: PresentedTabs?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "SceneDelegate")

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        TabChrome.scene = self
        let config = Shell.current
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        let presented = TabChrome.presented(config: config, languageTag: Locale.preferredLanguages.first ?? "en")
        apply(presented)
    }

    func apply(_ presented: PresentedTabs) {
        guard let window else { return }
        logTabs(presented.resolution)
        showing = presented
        if presented.resolution.tabs.count < 2 {
            installSingle(presented, window: window)
            return
        }
        installTabs(presented, window: window)
    }

    func selectTabIfNeeded(_ index: Int) {
        guard let controller = tabBarController else { return }
        let count = showing?.resolution.tabs.count ?? 0
        guard count >= 2 else { return }
        let safe = min(max(index, 0), count - 1)
        if var shown = showing {
            shown.selectedIndex = safe
            showing = shown
        }
        if #available(iOS 18.0, *) {
            guard controller.tabs.indices.contains(safe) else { return }
            let tab = controller.tabs[safe]
            if controller.selectedTab?.identifier == tab.identifier && controller.selectedIndex == safe {
                return
            }
            controller.selectedTab = tab
            if controller.selectedIndex != safe {
                controller.selectedIndex = safe
            }
            return
        }
        guard controller.selectedIndex != safe else { return }
        controller.selectedIndex = safe
    }

    private func installSingle(_ presented: PresentedTabs, window: UIWindow) {
        tabBarController = nil
        let config = Shell.current
        let start = presented.resolution.tabs.first?.location ?? config.startLocation
        let navigator = Navigator(configuration: .init(
            name: "main",
            startLocation: start
        ))
        self.navigator = navigator
        window.rootViewController = navigator.rootViewController
        window.makeKeyAndVisible()
        navigator.start()
    }

    private func installTabs(_ presented: PresentedTabs, window: UIWindow) {
        navigator = nil
        let hotwireTabs = ShellTabs.from(presented.resolution.tabs)
        if let controller = tabBarController {
            if #available(iOS 18.0, *) {
                controller.selectedTab = nil
            }
            controller.load(hotwireTabs)
            selectTabIfNeeded(presented.selectedIndex)
            return
        }
        let controller = HotwireTabBarController(lazyLoadTabs: true)
        tabBarController = controller
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.load(hotwireTabs)
        selectTabIfNeeded(presented.selectedIndex)
    }

    private func logTabs(_ resolution: TabResolution) {
        if resolution.dropped > 0 {
            logger.warning("Ignored \(resolution.dropped) invalid tab entries.")
        }
        if resolution.overflow > 0 {
            logger.warning("Tab list has more than \(NativeConfig.maxTabs) valid tabs; showing the first \(NativeConfig.maxTabs).")
        }
        if resolution.tabs.count < 2 {
            logger.info("Single navigator (\(resolution.tabs.count) valid tabs).")
        }
    }
}
