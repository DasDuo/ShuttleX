import Foundation

/// Fetches a server inventory from a remote HTTPS URL and caches the last good
/// payload locally so the menu still works offline.
///
/// Security model: a remote source provides *inventory only* — the JSON is
/// decoded with `allowCommands: false`, so `command`/`remoteCommand` are never
/// honored from the network. The login user comes from the local default-user
/// setting (or a per-host local override later).
enum RemoteHostStore {
    enum FetchError: LocalizedError {
        case invalidURL
        case insecureURL
        case http(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "The remote URL is not valid."
            case .insecureURL: return "The remote URL must use https://."
            case .http(let code): return "The server returned HTTP \(code)."
            }
        }
    }

    /// Downloads the raw JSON. Rejects anything that isn't an `https` URL.
    static func fetch(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased() else {
            throw FetchError.invalidURL
        }
        guard scheme == "https" else { throw FetchError.insecureURL }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw FetchError.http(http.statusCode)
        }
        return data
    }

    // MARK: - Local cache

    private static var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShuttleX", isDirectory: true)
        return base.appendingPathComponent("remote-cache.json")
    }

    static func loadCache() -> Data? {
        try? Data(contentsOf: cacheURL)
    }

    static func saveCache(_ data: Data) {
        try? FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: cacheURL, options: .atomic)
    }
}

/// Per-server login users for the remote source, stored **locally** (keyed by
/// host:port) so they survive remote reloads — the remote inventory never
/// carries a user. Applied with higher priority than the global default.
enum RemoteUserOverrides {
    private static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShuttleX", isDirectory: true)
        return base.appendingPathComponent("remote-users.json")
    }

    /// Stable identity of a server from its connection target (case-insensitive
    /// host + port). Independent of the display name, so renames in the remote
    /// list keep the override.
    static func key(host: String, port: Int?) -> String {
        "\(host.lowercased()):\(port ?? 22)"
    }

    static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func save(_ overrides: [String: String]) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(overrides) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Per-person favorites for the remote source, stored **locally** (a set of
/// host:port keys) so each teammate keeps their own — the shared remote list
/// never carries favorites. Survives remote reloads.
enum RemoteFavorites {
    private static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShuttleX", isDirectory: true)
        return base.appendingPathComponent("remote-favorites.json")
    }

    static func load() -> Set<String> {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(list)
    }

    static func save(_ favorites: Set<String>) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(favorites.sorted()) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
