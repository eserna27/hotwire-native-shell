import Foundation

/// Rails `GET /native/config` document.
///
/// Unknown keys are ignored so the server can add fields before the shell
/// ships a matching release. Missing bridge flags default to off.
struct NativeConfig: Decodable, Sendable {
    let name: String
    let baseUrl: String
    var startPath: String
    var tabs: [NativeTab]
    var bridges: BridgeFlags
    var push: PushConfig

    var startLocation: URL {
        location(for: startPath)
    }

    func location(for path: String) -> URL {
        let base = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalized = path.hasPrefix("/") ? path : "/" + path
        guard let url = URL(string: base + normalized) else {
            preconditionFailure("Invalid location \(baseUrl) \(path)")
        }
        return url
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case baseUrl = "base_url"
        case startPath = "start_path"
        case tabs
        case bridges
        case push
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let baseUrl = try container.decode(String.self, forKey: .baseUrl)
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "name and base_url are required"
            )
        }
        self.name = name
        self.baseUrl = baseUrl
        startPath = try container.decodeIfPresent(String.self, forKey: .startPath) ?? "/"
        tabs = try container.decodeIfPresent([NativeTab].self, forKey: .tabs) ?? []
        bridges = try container.decodeIfPresent(BridgeFlags.self, forKey: .bridges) ?? BridgeFlags()
        push = try container.decodeIfPresent(PushConfig.self, forKey: .push) ?? PushConfig()
    }
}

struct NativeTab: Decodable, Sendable {
    let id: String
    let title: String
    let path: String
    var icon: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case path
        case icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        path = try container.decode(String.self, forKey: .path)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "home"
    }
}

struct BridgeFlags: Decodable, Sendable {
    var notificationToken = false
    var share = false
    var haptic = false
    var camera = false
    var biometric = false
    var clipboard = false
    var fileDownload = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case notificationToken = "notification_token"
        case share
        case haptic
        case camera
        case biometric
        case clipboard
        case fileDownload = "file_download"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notificationToken = try container.decodeIfPresent(Bool.self, forKey: .notificationToken) ?? false
        share = try container.decodeIfPresent(Bool.self, forKey: .share) ?? false
        haptic = try container.decodeIfPresent(Bool.self, forKey: .haptic) ?? false
        camera = try container.decodeIfPresent(Bool.self, forKey: .camera) ?? false
        biometric = try container.decodeIfPresent(Bool.self, forKey: .biometric) ?? false
        clipboard = try container.decodeIfPresent(Bool.self, forKey: .clipboard) ?? false
        fileDownload = try container.decodeIfPresent(Bool.self, forKey: .fileDownload) ?? false
    }
}

struct PushConfig: Decodable, Sendable {
    var enabled = false
    var topics: [String] = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        topics = try container.decodeIfPresent([String].self, forKey: .topics) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case topics
    }
}

/// Config loaded in `AppDelegate` before the scene creates a `Navigator`.
enum Shell {
    private static var stored: NativeConfig?

    static var current: NativeConfig {
        guard let stored else {
            preconditionFailure("Shell.current read before AppDelegate loaded /native/config")
        }
        return stored
    }

    static func use(_ config: NativeConfig) {
        stored = config
    }
}
