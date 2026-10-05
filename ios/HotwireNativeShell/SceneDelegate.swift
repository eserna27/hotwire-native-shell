import HotwireNative
import os
import UIKit
import WebKit

/// Cold start uses `tabs` from `/native/config`. The first `tabs` bridge
/// `connect` replaces that list, including a cached copy from an older install.
///
/// Login and logout replace the root controller, so the previous stacks are
/// released. The same list does not replace it again. A later page that sends
/// `tabs: []` stays on the sign-in navigator.
enum TabChrome {
    static var bridge: PresentedTabs?
    static weak var scene: SceneDelegate?
    private static var generation = 0

    static func presented(config: NativeConfig, languageTag: String) -> PresentedTabs {
        if let bridge { return bridge }
        return PresentedTabs(resolution: config.resolveTabs(languageTag: languageTag), selectedIndex: 0)
    }

    static func update(jsonData: String, sourceLocation: String, isModal: Bool, webView: WKWebView?) {
        let config = Shell.current
        let language = Locale.preferredLanguages.first ?? "en"
        guard let next = parsePresentedTabs(jsonData: jsonData, baseUrl: config.baseUrl, languageTag: language) else {
            logger.warning("Ignoring tabs connect that has no tabs array.")
            return
        }
        log(next)
        let current = presented(config: config, languageTag: language)
        switch TabChromePlan.decide(
            currentTabs: current.resolution.tabs,
            next: next,
            sourceLocation: sourceLocation,
            currentIndex: scene?.tabIndex(containing: webView),
            isModal: isModal
        ) {
        case .ignore:
            logger.info("Ignoring tabs connect from a modal.")
        case .keep:
            break
        case .route(let index, let url):
            scene?.routeToTab(index: index, url: url, from: scene?.tabIndex(containing: webView))
        case .replace(let presented):
            bridge = presented
            generation += 1
            let token = generation
            logger.info("Replacing tab chrome (\(presented.resolution.tabs.count) tabs).")
            DispatchQueue.main.async {
                guard self.generation == token else { return }
                self.scene?.apply(presented)
            }
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

    /// Index of the tab navigator that owns `webView`. A tab that is not
    /// selected can still send `connect` after a pop.
    func tabIndex(containing webView: WKWebView?) -> Int? {
        guard let webView, let controller = tabBarController, let showing, showing.resolution.tabs.count >= 2 else {
            return nil
        }
        let tabs = ShellTabs.from(showing.resolution.tabs)
        for (index, tab) in tabs.enumerated() {
            guard let navigator = controller.navigator(for: tab) else { continue }
            if navigator.session.webView === webView || navigator.modalSession.webView === webView {
                return index
            }
        }
        return nil
    }

    /// Shows `url` on the tab that owns it and pops that visit off the navigator
    /// that received it, when that navigator is a different tab.
    func routeToTab(index: Int, url: URL, from fromIndex: Int?) {
        guard let controller = tabBarController, let showing else { return }
        let tabs = ShellTabs.from(showing.resolution.tabs)
        guard tabs.indices.contains(index) else { return }
        let fromNavigator = fromIndex.flatMap { idx -> Navigator? in
            guard tabs.indices.contains(idx) else { return nil }
            return controller.navigator(for: tabs[idx])
        }
        selectTabIfNeeded(index)
        let destination = controller.navigator(for: tabs[index]) ?? controller.activeNavigator
        let top = (destination.rootViewController.topViewController as? Visitable)?.currentVisitableURL
            ?? (destination.rootViewController.topViewController as? Visitable)?.initialVisitableURL
        if !TabChromePlan.sameDocument(top, url) {
            destination.route(url)
        }
        if let fromNavigator, let fromIndex, fromIndex != index {
            popIfShowing(fromNavigator, url: url)
        }
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

    private func popIfShowing(_ navigator: Navigator, url: URL) {
        let stack = navigator.rootViewController.viewControllers
        guard stack.count > 1, let top = stack.last as? Visitable else { return }
        guard TabChromePlan.sameDocument(top.currentVisitableURL, url)
            || TabChromePlan.sameDocument(top.initialVisitableURL, url) else {
            return
        }
        navigator.pop(animated: false)
    }

    private func installSingle(_ presented: PresentedTabs, window: UIWindow) {
        tabBarController = nil
        let config = Shell.current
        let start = presented.singleRoot
            ?? presented.resolution.tabs.first?.location
            ?? config.startLocation
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
        // A new controller releases the previous navigators, including a
        // sign-in stack or the signed-in tabs after logout.
        tabBarController = nil
        let hotwireTabs = ShellTabs.from(presented.resolution.tabs)
        let controller = HotwireTabBarController(lazyLoadTabs: true)
        tabBarController = controller
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.load(hotwireTabs)
        selectTabIfNeeded(presented.selectedIndex ?? 0)
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
