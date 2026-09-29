import HotwireNative
import os
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let config = NativeConfigStore.loadStartup()
        Shell.use(config)
        configureAppearance()
        configureHotwire(config)
        logger.info("Shell \(config.name, privacy: .public) push.enabled=\(config.push.enabled) topics=\(String(describing: config.push.topics), privacy: .public)")
        NativeConfigStore.refreshInBackground(config)
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "Shell")

    /// Matches the Hotwire Native iOS demo: opaque bars, so web content does not show through.
    private func configureAppearance() {
        UINavigationBar.appearance().scrollEdgeAppearance = .init()
        UITabBar.appearance().scrollEdgeAppearance = .init()
    }

    /// Path configuration and bridge components must be registered before the scene creates a `Navigator`.
    private func configureHotwire(_ config: NativeConfig) {
        guard let localPath = Bundle.main.url(forResource: "path-configuration", withExtension: "json") else {
            preconditionFailure("Missing bundled path-configuration.json")
        }
        Hotwire.loadPathConfiguration(from: [
            .file(localPath),
            .server(config.location(for: "/configurations/ios_v1.json"))
        ])

        Hotwire.config.applicationUserAgentPrefix = "\(config.name);"
        Hotwire.registerBridgeComponents(BridgeRegistrar.componentTypes(for: config.bridges))
        Hotwire.config.backButtonDisplayMode = .minimal
        Hotwire.config.showDoneButtonOnModals = true
        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif
    }
}
