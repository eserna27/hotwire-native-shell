import Foundation
import os

/// Startup uses the bundled flavor JSON, replaced by a cached remote document
/// after one successful fetch. A fresh `GET /native/config` runs in the
/// background and is applied on the next cold start, matching the Android shell
/// and Hotwire's path-configuration cache.
enum NativeConfigStore {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "blog.itsjustmy.app", category: "NativeConfig")
    private static let timeout: TimeInterval = 8
    private static let decoder = JSONDecoder()

    static func loadStartup() -> NativeConfig {
        let bundled = loadBundled()
        return loadCached() ?? bundled
    }

    static func refreshInBackground(_ startup: NativeConfig) {
        let endpoint = startup.location(for: "/native/config")
        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("hotwire-native-shell", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                logger.warning("Remote /native/config unavailable. Using the bundled or cached document. \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let http = response as? HTTPURLResponse else {
                logger.warning("Remote /native/config unavailable. Using the bundled or cached document.")
                return
            }
            guard (200 ... 299).contains(http.statusCode), let data else {
                logger.warning("GET \(endpoint.absoluteString, privacy: .public) returned HTTP \(http.statusCode). Leaving the cache unchanged.")
                return
            }
            do {
                _ = try decoder.decode(NativeConfig.self, from: data)
                try writeCache(data)
                logger.info("Cached remote /native/config. It applies on the next cold start.")
            } catch {
                logger.warning("Remote /native/config was not the expected JSON. Leaving the cache unchanged. \(error.localizedDescription, privacy: .public)")
            }
        }.resume()
    }

    private static func loadBundled() -> NativeConfig {
        guard let url = Bundle.main.url(forResource: "config", withExtension: "json", subdirectory: "native") else {
            preconditionFailure("Missing bundled native/config.json")
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(NativeConfig.self, from: data)
        } catch {
            preconditionFailure("Bundled native/config.json could not be read: \(error)")
        }
    }

    private static func loadCached() -> NativeConfig? {
        let url = cacheFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(NativeConfig.self, from: data)
        } catch {
            logger.warning("Ignoring unreadable cached /native/config. \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func writeCache(_ data: Data) throws {
        let url = cacheFileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private static func cacheFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("native-config", isDirectory: true)
            .appendingPathComponent("native-config.json")
    }
}
