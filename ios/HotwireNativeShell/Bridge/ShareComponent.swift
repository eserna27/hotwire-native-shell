import HotwireNative
import UIKit
import os

/// Stimulus: `static component = "share"`, event `connect`, data `{url}`.
/// Adds a navigation-bar action that opens the system share sheet. The sheet
/// shares `url`, or the page URL from the bridge message when `url` is omitted.
/// The item is appended beside `overflow-menu`, which stays the trailing button.
final class ShareComponent: BridgeComponent {
    override class var name: String { "share" }

    override func onReceive(message: Message) {
        switch message.event {
        case "connect":
            addButton(message)
        case "disconnect":
            removeButton()
        default:
            logger.warning("Unknown event for message: \(message.event, privacy: .public)")
        }
    }

    private weak var shareItem: UIBarButtonItem?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "ShareComponent")

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    private func addButton(_ message: Message) {
        guard let viewController else {
            logger.warning("No view controller for the share action")
            return
        }
        let data: MessageData? = message.data()
        let url = data?.url ?? message.metadata?.url
        guard let url, !url.isEmpty else {
            logger.warning("Share connect missing url")
            return
        }

        let item = UIBarButtonItem(title: "Share", primaryAction: UIAction { [weak self] _ in
            self?.share(url)
        })
        item.image = UIImage(systemName: "square.and.arrow.up")
        item.accessibilityLabel = "Share"
        var items = viewController.navigationItem.rightBarButtonItems ?? []
        if let shareItem {
            items.removeAll { $0 === shareItem }
        }
        items.append(item)
        viewController.navigationItem.rightBarButtonItems = items
        shareItem = item
    }

    private func removeButton() {
        guard let viewController else { return }
        var items = viewController.navigationItem.rightBarButtonItems ?? []
        items.removeAll { $0 === shareItem }
        viewController.navigationItem.rightBarButtonItems = items.isEmpty ? nil : items
        shareItem = nil
    }

    private func share(_ url: String) {
        guard let viewController else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.barButtonItem = shareItem ?? viewController.navigationItem.rightBarButtonItem
        }
        viewController.present(activity, animated: true)
    }

    private struct MessageData: Decodable {
        let url: String?
    }
}
