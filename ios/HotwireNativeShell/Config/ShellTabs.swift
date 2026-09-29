import HotwireNative
import UIKit

/// Maps contract tabs onto `HotwireTab` values. At most four tabs, matching
/// Android `ShellTabs.MAX_TABS`. itsjustmy ships with an empty `tabs` array,
/// so the scene uses one `Navigator` and no tab bar.
enum ShellTabs {
    static let maxTabs = 4

    static func from(_ config: NativeConfig) -> [HotwireTab] {
        config.tabs.prefix(maxTabs).map { tab in
            HotwireTab(
                id: tab.id,
                title: tab.title,
                image: UIImage(systemName: symbolName(for: tab.icon)),
                url: config.location(for: tab.path)
            )
        }
    }

    private static func symbolName(for icon: String) -> String {
        switch icon {
        case "posts":
            return "doc.text"
        case "search":
            return "magnifyingglass"
        case "profile":
            return "person"
        default:
            return "house"
        }
    }
}
