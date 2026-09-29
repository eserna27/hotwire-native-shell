import HotwireNative
import os

/// Registers bridge components.
///
/// `menu` and `overflow-menu` are always registered. They are the native
/// navigation chrome, not `/native/config` flags. The other names match
/// `@hotwired/hotwire-native-bridge` `static component` values and are
/// registered only when that flag is on. Flags this skeleton does not ship
/// stay off, so they never appear in the WebView user agent.
enum BridgeRegistrar {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "BridgeRegistrar")

    static func componentTypes(for flags: BridgeFlags) -> [BridgeComponent.Type] {
        var types: [BridgeComponent.Type] = [
            MenuComponent.self,
            OverflowMenuComponent.self
        ]
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
