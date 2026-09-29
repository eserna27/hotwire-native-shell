import HotwireNative
import UIKit
import os

/// Stimulus: `static component = "overflow-menu"`, event `connect`, data `{label}`.
///
/// Adds the trailing navigation-bar button (ellipsis). Tapping it replies to
/// `connect` with no data, which the web controller uses to click the same
/// element and open `menu`. The button is inserted at the trailing edge so a
/// `share` item on the same bar stays beside it.
final class OverflowMenuComponent: BridgeComponent {
    override class var name: String { "overflow-menu" }

    override func onReceive(message: Message) {
        guard message.event == "connect" else {
            logger.warning("Unknown event for message: \(message.event, privacy: .public)")
            return
        }
        guard let data: MessageData = message.data() else { return }
        showOverflowMenuItem(data)
    }

    private weak var overflowItem: UIBarButtonItem?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "OverflowMenuComponent")

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    private func showOverflowMenuItem(_ data: MessageData) {
        guard let viewController else {
            logger.warning("No view controller for the overflow menu")
            return
        }

        let item = UIBarButtonItem(
            title: data.label,
            image: UIImage(systemName: "ellipsis.circle"),
            primaryAction: UIAction { [weak self] _ in
                self?.reply(to: "connect")
            }
        )
        var items = viewController.navigationItem.rightBarButtonItems ?? []
        if let overflowItem {
            items.removeAll { $0 === overflowItem }
        }
        items.insert(item, at: 0)
        viewController.navigationItem.rightBarButtonItems = items
        overflowItem = item
    }

    private struct MessageData: Decodable {
        let label: String
    }
}
