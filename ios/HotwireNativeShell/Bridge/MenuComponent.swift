import HotwireNative
import UIKit
import WebKit
import os

/// Stimulus: `static component = "menu"`, event `display`.
///
/// Presents a native action sheet and replies with `{ "selectedIndex" }`.
/// The index is the item's position in the web `item` target list. Cancel
/// does not reply. Matches the Hotwire Native iOS 1.3.1 demo component.
final class MenuComponent: BridgeComponent {
    override class var name: String { "menu" }

    override func onReceive(message: Message) {
        guard message.event == "display" else {
            logger.warning("Unknown event for message: \(message.event, privacy: .public)")
            return
        }
        guard let data: MessageData = message.data() else { return }
        showAlertSheet(title: data.title, items: data.items, source: data.source)
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "MenuComponent")

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    private func showAlertSheet(title: String, items: [Item], source: Source) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for item in items {
            alert.addAction(UIAlertAction(title: item.title, style: .default) { [weak self] _ in
                self?.reply(
                    to: "display",
                    with: SelectionMessageData(selectedIndex: item.index)
                )
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController, let viewController {
            popover.sourceView = viewController.view
            let insetTop = (viewController as? Visitable)?.visitableView.webView?.scrollView.adjustedContentInset.top ?? 0
            popover.sourceRect = CGRect(
                x: source.x,
                y: source.y + Double(insetTop),
                width: source.width,
                height: source.height
            )
        }

        viewController?.present(alert, animated: true)
    }

    private struct Source: Decodable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    private struct MessageData: Decodable {
        let title: String
        let items: [Item]
        let source: Source
    }

    private struct Item: Decodable {
        let title: String
        let index: Int
    }

    private struct SelectionMessageData: Encodable {
        let selectedIndex: Int
    }
}
