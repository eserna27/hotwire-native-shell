import Foundation
import HotwireNative
import os

/// Stimulus: `static component = "tabs"`, event `connect`.
///
/// The page sends one object per tab (`id`, `title`, `icon`, `path` or `url`,
/// and `active`). There is no `/native/config` flag. A payload without a
/// `tabs` array is ignored. Fewer than two usable tabs leaves the single
/// navigator. `disconnect` leaves the current bar in place.
final class TabsComponent: BridgeComponent {
    override class var name: String { "tabs" }

    override func onReceive(message: Message) {
        guard message.event == "connect" else {
            logger.warning("Unknown event for message: \(message.event, privacy: .public)")
            return
        }
        TabChrome.update(jsonData: message.jsonData)
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "TabsComponent")
}
