import Foundation
import HotwireNative
import os

/// Stimulus: `static component = "notification-token"`.
///
/// Replies to `connect` and `get` with a placeholder token. This is not an
/// APNs device token. There is no push entitlement in this skeleton. See
/// docs/BRIDGES.md.
final class NotificationTokenComponent: BridgeComponent {
    override class var name: String { "notification-token" }

    override func onReceive(message: Message) {
        switch message.event {
        case "connect", "get":
            reply(to: message.event, with: TokenResponse(token: Self.placeholderToken, provider: "placeholder"))
        default:
            logger.warning("Unknown event for message: \(message.event, privacy: .public)")
        }
    }

    private struct TokenResponse: Encodable {
        let token: String
        let provider: String
    }

    private static let placeholderToken = "placeholder-not-a-device-token"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "NotificationToken")
}
