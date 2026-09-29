import HotwireNative
import UIKit
import os

/// Stimulus: `static component = "haptic"`, event `vibrate`, data `{feedback}`.
/// `feedback` is `success` (default), `warning`, or `error`.
final class HapticComponent: BridgeComponent {
    override class var name: String { "haptic" }

    override func onReceive(message: Message) {
        guard message.event == "vibrate" else {
            logger.warning("Unknown event for message: \(message.event, privacy: .public)")
            return
        }
        let data: MessageData? = message.data()
        let feedback = data?.feedback ?? "success"
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        switch feedback {
        case "warning":
            generator.notificationOccurred(.warning)
        case "error":
            generator.notificationOccurred(.error)
        default:
            generator.notificationOccurred(.success)
        }
    }

    private struct MessageData: Decodable {
        let feedback: String?
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "HapticComponent")
}
