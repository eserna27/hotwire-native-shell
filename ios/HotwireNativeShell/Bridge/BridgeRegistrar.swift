import HotwireNative
import os

/// Registers the bridge components whose contract flags are on.
///
/// Component names match `@hotwired/hotwire-native-bridge` `static component`
/// values (`notification-token`, `share`, `haptic`). Flags for components this
/// skeleton does not ship stay off and are not registered, so they never
/// appear in the WebView user agent.
enum BridgeRegistrar {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "BridgeRegistrar")

    static func componentTypes(for flags: BridgeFlags) -> [BridgeComponent.Type] {
        var types = [BridgeComponent.Type]()
        if flags.notificationToken {
            types.append(NotificationTokenComponent.self)
        }
        if flags.share {
            types.append(ShareComponent.self)
        }
        if flags.haptic {
            types.append(HapticComponent.self)
        }

        let waiting = unimplemented(flags)
        if !waiting.isEmpty {
            logger.warning("Bridge flags are on, but this shell has no component yet: \(waiting.joined(separator: ", "), privacy: .public)")
        }

        let names = types.map { $0.name }.joined(separator: ", ")
        logger.info("Registered bridge components: \(names, privacy: .public)")
        return types
    }

    private static func unimplemented(_ flags: BridgeFlags) -> [String] {
        var names = [String]()
        if flags.camera { names.append("camera") }
        if flags.biometric { names.append("biometric") }
        if flags.clipboard { names.append("clipboard") }
        if flags.fileDownload { names.append("file_download") }
        return names
    }
}
