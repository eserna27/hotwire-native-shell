import Foundation
import os

/// Rails `GET /native/config` document.
///
/// Unknown keys are ignored so the server can add fields before the shell
/// ships a matching release. Missing bridge flags default to off. A bad `tabs`
/// entry is skipped; it does not reject the rest of the document.
struct NativeConfig: Decodable, Sendable {
    let name: String
    let baseUrl: String
    var startPath: String
    var tabs: [NativeTab]
    var bridges: BridgeFlags
    var push: PushConfig

    static let maxTabs = 5

    var startLocation: URL {
        location(for: startPath)
    }

    func location(for path: String) -> URL {
        Self.joinHttp(baseUrl: baseUrl, path: path) ?? URL(string: "about:blank")!
    }

    /// Tabs the shell will actually show. Fewer than two means one navigator
    /// and no tab bar; a single kept tab still supplies that navigator's start
    /// location. At most `maxTabs` are kept, in document order.
    func resolveTabs(languageTag: String) -> TabResolution {
        presentTabs(baseUrl: baseUrl, items: tabs.map { ($0, false) }, languageTag: languageTag).resolution
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
        tabs = Self.decodeTabs(from: container)
        bridges = try container.decodeIfPresent(BridgeFlags.self, forKey: .bridges) ?? BridgeFlags()
        push = try container.decodeIfPresent(PushConfig.self, forKey: .push) ?? PushConfig()
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "NativeConfig")

    private static func decodeTabs(from container: KeyedDecodingContainer<CodingKeys>) -> [NativeTab] {
        guard container.contains(.tabs) else { return [] }
        guard var array = try? container.nestedUnkeyedContainer(forKey: .tabs) else {
            logger.warning("Ignoring tabs because it is not an array.")
            return []
        }
        var tabs: [NativeTab] = []
        while !array.isAtEnd {
            if let tab = try? array.decode(NativeTab.self) {
                tabs.append(tab)
            } else if (try? array.decode(JSONValue.self)) != nil {
                tabs.append(NativeTab())
            } else {
                break
            }
        }
        return tabs
    }

    static func joinHttp(baseUrl: String, path: String) -> URL? {
        let relative = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if relative.isEmpty || relative.contains("://") { return nil }
        if relative.unicodeScalars.contains(where: { scalar in
            scalar.value < 32 || scalar.value == 92 || CharacterSet.whitespacesAndNewlines.contains(scalar)
        }) {
            return nil
        }
        let base = trimmingTrailingSlashes(baseUrl.trimmingCharacters(in: .whitespacesAndNewlines))
        guard httpURL(from: base) != nil else { return nil }
        let normalized = relative.hasPrefix("/") ? relative : "/" + relative
        return httpURL(from: base + normalized)
    }

    static func httpURL(from value: String) -> URL? {
        if value.isEmpty || value.unicodeScalars.contains(where: { $0.value < 32 }) { return nil }
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return url
    }

    private static func trimmingTrailingSlashes(_ value: String) -> String {
        var end = value.endIndex
        while end > value.startIndex && value[value.index(before: end)] == "/" {
            end = value.index(before: end)
        }
        return String(value[..<end])
    }
}

struct TabResolution: Sendable {
    var tabs: [ResolvedTab]
    var dropped: Int
    var overflow: Int
}

struct PresentedTabs: Sendable {
    var resolution: TabResolution
    var selectedIndex: Int
}

struct ResolvedTab: Sendable, Equatable {
    let id: String
    let title: String
    let location: URL
    let icon: String
    let sfSymbol: String
}

func presentTabs(baseUrl: String, items: [(NativeTab, Bool)], languageTag: String) -> PresentedTabs {
    var seen = Set<String>()
    var valid: [(ResolvedTab, Bool)] = []
    var dropped = 0
    for (tab, active) in items {
        guard let resolved = tab.resolve(baseUrl: baseUrl, languageTag: languageTag),
              seen.insert(resolved.id).inserted else {
            dropped += 1
            continue
        }
        valid.append((resolved, active))
    }
    let overflow = max(0, valid.count - NativeConfig.maxTabs)
    let kept = Array(valid.prefix(NativeConfig.maxTabs))
    let selected = kept.firstIndex(where: { $0.1 }) ?? 0
    return PresentedTabs(
        resolution: TabResolution(
            tabs: kept.map { $0.0 },
            dropped: dropped,
            overflow: overflow
        ),
        selectedIndex: selected
    )
}

/// Parses a `tabs` bridge `connect` payload. Nil when `tabs` is missing or
/// the body is not an object, so a bad message leaves the current bar alone.
func parsePresentedTabs(jsonData: String, baseUrl: String, languageTag: String) -> PresentedTabs? {
    guard let data = jsonData.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rawTabs = root["tabs"] else {
        return nil
    }
    guard let array = rawTabs as? [Any] else { return nil }
    let items: [(NativeTab, Bool)] = array.map { entry in
        guard let object = entry as? [String: Any] else {
            return (NativeTab(), false)
        }
        var tab = NativeTab()
        tab.id = jsonString(object["id"])
        if let title = object["title"] as? String {
            tab.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var locales = jsonStringMap(object["title"])
        locales.merge(jsonStringMap(object["titles"])) { _, new in new }
        tab.titles = locales
        tab.path = jsonString(object["path"])
        tab.url = jsonString(object["url"])
        let icon = jsonString(object["icon"]).lowercased()
        tab.icon = icon.isEmpty ? "home" : icon
        tab.sfSymbol = jsonString(object["sf_symbol"])
        tab.androidIcon = jsonString(object["android_icon"])
        return (tab, jsonActive(object["active"]))
    }
    return presentTabs(baseUrl: baseUrl, items: items, languageTag: languageTag)
}

private func jsonString(_ value: Any?) -> String {
    guard let string = value as? String else { return "" }
    return string.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func jsonStringMap(_ value: Any?) -> [String: String] {
    guard let object = value as? [String: Any] else { return [:] }
    var map: [String: String] = [:]
    for (key, raw) in object {
        guard let string = raw as? String else { continue }
        let name = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        let label = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && !label.isEmpty {
            map[name] = label
        }
    }
    return map
}

private func jsonActive(_ value: Any?) -> Bool {
    if let string = value as? String {
        return string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
    }
    guard let flag = value as? Bool else { return false }
    if let number = flag as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
        return false
    }
    return flag
}

struct NativeTab: Decodable, Sendable {
    var id: String = ""
    var title: String = ""
    var titles: [String: String] = [:]
    var path: String = ""
    var url: String = ""
    var icon: String = "home"
    var sfSymbol: String = ""
    var androidIcon: String = ""

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case titles
        case path
        case url
        case icon
        case sfSymbol = "sf_symbol"
        case androidIcon = "android_icon"
    }

    init() {}

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "tab must be an object")
            )
        }
        id = (try? container.decode(String.self, forKey: .id))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let titleString = (try? container.decode(String.self, forKey: .title))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        title = titleString
        var locales: [String: String] = [:]
        if titleString.isEmpty {
            locales.merge(Self.localeMap(from: container, key: .title)) { _, new in new }
        }
        locales.merge(Self.localeMap(from: container, key: .titles)) { _, new in new }
        titles = locales
        path = (try? container.decode(String.self, forKey: .path))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        url = (try? container.decode(String.self, forKey: .url))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let decodedIcon = (try? container.decode(String.self, forKey: .icon))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        icon = decodedIcon.isEmpty ? "home" : decodedIcon
        sfSymbol = (try? container.decode(String.self, forKey: .sfSymbol))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        androidIcon = (try? container.decode(String.self, forKey: .androidIcon))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func resolve(baseUrl: String, languageTag: String) -> ResolvedTab? {
        let safeId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isSafeId(safeId) else { return nil }
        let label = displayTitle(languageTag: languageTag)
        guard !label.isEmpty else { return nil }
        guard let location = startLocation(baseUrl: baseUrl) else { return nil }
        let catalogIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let symbol = sfSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return ResolvedTab(
            id: safeId,
            title: label,
            location: location,
            icon: catalogIcon.isEmpty ? "home" : catalogIcon,
            sfSymbol: Self.isSfSymbol(symbol) ? symbol : ""
        )
    }

    private func displayTitle(languageTag: String) -> String {
        for candidate in Self.languageCandidates(languageTag) {
            if let label = titles[candidate], let cleaned = Self.cleanTitle(label), !cleaned.isEmpty {
                return cleaned
            }
        }
        if let cleaned = Self.cleanTitle(title), !cleaned.isEmpty {
            return cleaned
        }
        for fallback in ["en", "es"] {
            if let label = titles[fallback], let cleaned = Self.cleanTitle(label), !cleaned.isEmpty {
                return cleaned
            }
        }
        for label in titles.values {
            if let cleaned = Self.cleanTitle(label), !cleaned.isEmpty {
                return cleaned
            }
        }
        return ""
    }

    private func startLocation(baseUrl: String) -> URL? {
        let absolute = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !absolute.isEmpty, let url = NativeConfig.httpURL(from: absolute) {
            return url
        }
        return NativeConfig.joinHttp(baseUrl: baseUrl, path: path)
    }

    private static func localeMap(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> [String: String] {
        guard let nested = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: key) else {
            return [:]
        }
        var map: [String: String] = [:]
        for codingKey in nested.allKeys {
            guard let value = try? nested.decode(String.self, forKey: codingKey) else { continue }
            let name = codingKey.stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "_", with: "-")
            let label = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && !label.isEmpty {
                map[name] = label
            }
        }
        return map
    }

    private static func languageCandidates(_ languageTag: String) -> [String] {
        let tag = languageTag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        if tag.isEmpty { return [] }
        let base = tag.split(separator: "-").first.map(String.init) ?? tag
        if base == tag { return [tag] }
        return [tag, base]
    }

    private static func cleanTitle(_ raw: String) -> String? {
        let collapsed = raw.split { $0.isWhitespace }.joined(separator: " ")
        if collapsed.isEmpty { return nil }
        let capped = String(collapsed.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
        return capped.isEmpty ? nil : capped
    }

    private static func isSafeId(_ value: String) -> Bool {
        guard (1 ... 64).contains(value.count) else { return false }
        guard let first = value.first, isAsciiLetterOrDigit(first) else { return false }
        return value.allSatisfy { isAsciiLetterOrDigit($0) || $0 == "." || $0 == "_" || $0 == "-" }
    }

    private static func isSfSymbol(_ value: String) -> Bool {
        guard (1 ... 80).contains(value.count) else { return false }
        guard let first = value.first, isAsciiLetter(first) else { return false }
        return value.allSatisfy { isAsciiLetterOrDigit($0) || $0 == "." }
    }

    private static func isAsciiLetter(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else { return false }
        let value = scalar.value
        return (65 ... 90).contains(value) || (97 ... 122).contains(value)
    }

    private static func isAsciiLetterOrDigit(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else { return false }
        let value = scalar.value
        return (48 ... 57).contains(value) || (65 ... 90).contains(value) || (97 ... 122).contains(value)
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        nil
    }
}

/// Consumes one JSON value so a bad tab does not stall the array decoder.
private struct JSONValue: Decodable {
    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            for key in keyed.allKeys {
                _ = try keyed.decode(JSONValue.self, forKey: key)
            }
            return
        }
        if var array = try? decoder.unkeyedContainer() {
            while !array.isAtEnd {
                _ = try array.decode(JSONValue.self)
            }
            return
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { return }
        if (try? single.decode(Bool.self)) != nil { return }
        if (try? single.decode(Double.self)) != nil { return }
        if (try? single.decode(String.self)) != nil { return }
        throw DecodingError.dataCorruptedError(in: single, debugDescription: "unsupported JSON")
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
