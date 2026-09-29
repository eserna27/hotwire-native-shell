import HotwireNative
import os
import UIKit

/// Maps resolved contract tabs onto `HotwireTab` values. At most five, matching
/// Android `NativeConfig.MAX_TABS` and Material's bottom-bar limit. Fewer than
/// two valid tabs keeps a single `Navigator` and no tab bar.
///
/// `icon` is a shared catalog name. `sf_symbol` is an optional SF Symbol that
/// iOS uses when the system can draw it. An unknown symbol falls back to the
/// catalog, then to `house`. Android drawables are not read here.
enum ShellTabs {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "ShellTabs")

    static func from(_ tabs: [ResolvedTab]) -> [HotwireTab] {
        tabs.map { tab in
            HotwireTab(
                id: tab.id,
                title: tab.title,
                image: image(for: tab),
                url: tab.location
            )
        }
    }

    private static func image(for tab: ResolvedTab) -> UIImage? {
        if !tab.sfSymbol.isEmpty {
            if let image = UIImage(systemName: tab.sfSymbol) {
                return image
            }
            logger.warning("Unknown sf_symbol \(tab.sfSymbol, privacy: .public) for tab \(tab.id, privacy: .public); using the shared icon.")
        }
        return UIImage(systemName: symbolName(for: tab.icon)) ?? UIImage(systemName: "house")
    }

    private static func symbolName(for icon: String) -> String {
        switch icon {
        case "posts":
            return "doc.text"
        case "search":
            return "magnifyingglass"
        case "profile":
            return "person"
        case "info":
            return "info.circle"
        default:
            return "house"
        }
    }
}
