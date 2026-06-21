import AppKit
import Foundation
import Observation

@Observable
final class AppState {
    static let sshConfigURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".ssh/config")

    var source: HostSource {
        didSet {
            UserDefaults.standard.set(source.rawValue, forKey: "hostSource")
            reload()
        }
    }

    var terminal: TerminalApp {
        didSet {
            UserDefaults.standard.set(terminal.rawValue, forKey: "terminalApp")
        }
    }

    var launchMode: LaunchMode {
        didSet {
            UserDefaults.standard.set(launchMode.rawValue, forKey: "launchMode")
        }
    }

    /// A default SSH user applied to servers that don't specify their own
    /// (JSON / remote source). Empty = no default. Per-server users override it.
    var defaultUser: String {
        didSet {
            UserDefaults.standard.set(defaultUser, forKey: "defaultUser")
            reload()
        }
    }

    /// HTTPS URL of a remote server inventory (used by the `.remoteJSON` source).
    var remoteURL: String {
        didSet {
            UserDefaults.standard.set(remoteURL, forKey: "remoteURL")
            if source == .remoteJSON { reload() }
        }
    }

    /// When the remote inventory was last fetched successfully.
    var remoteLastUpdated: Date?

    /// The mode actually used — falls back to "new window" when the selected
    /// terminal app doesn't support the chosen mode.
    var effectiveLaunchMode: LaunchMode {
        terminal.supportedModes.contains(launchMode) ? launchMode : .newWindow
    }

    /// Path to the JSON file — a user-defined location or the default.
    var jsonURL: URL {
        if let custom = UserDefaults.standard.string(forKey: "jsonPath"), !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath)
        }
        return JSONHostStore.defaultURL
    }

    var usingCustomJSONPath: Bool {
        !(UserDefaults.standard.string(forKey: "jsonPath") ?? "").isEmpty
    }

    /// Sets a custom JSON path (or `nil` to fall back to the default) and reloads.
    func setJSONPath(_ url: URL?) {
        UserDefaults.standard.set(url?.path, forKey: "jsonPath")
        if source == .json { reload() }
    }

    private(set) var groups: [HostGroup] = []
    var lastError: String?

    /// Opt-in (default off): check GitHub for a newer release on launch.
    var checkForUpdates: Bool {
        didSet {
            UserDefaults.standard.set(checkForUpdates, forKey: "checkForUpdates")
            if checkForUpdates {
                maybeCheckForUpdates(force: true)
            } else {
                updateAvailable = nil
            }
        }
    }

    /// The newer version available on GitHub (e.g. "1.7.0"), or nil.
    var updateAvailable: String?

    var hostCount: Int {
        groups.reduce(0) { $0 + $1.hosts.count }
    }

    init() {
        let defaults = UserDefaults.standard
        source = defaults.string(forKey: "hostSource").flatMap(HostSource.init) ?? .sshConfig
        if let stored = defaults.string(forKey: "terminalApp").flatMap(TerminalApp.init),
           stored.isInstalled {
            terminal = stored
        } else {
            terminal = .terminal
        }
        launchMode = defaults.string(forKey: "launchMode").flatMap(LaunchMode.init) ?? .newWindow
        defaultUser = defaults.string(forKey: "defaultUser") ?? ""
        remoteURL = defaults.string(forKey: "remoteURL") ?? ""
        checkForUpdates = defaults.bool(forKey: "checkForUpdates") // default false
        reload()
        maybeCheckForUpdates()
    }

    /// Checks GitHub for a newer release when enabled, throttled to once per 24 h
    /// (unless `force`). Fails silently on network/API errors.
    func maybeCheckForUpdates(force: Bool = false) {
        guard checkForUpdates else { updateAvailable = nil; return }
        let last = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        if !force, Date().timeIntervalSince1970 - last < 24 * 3600 { return }
        UpdateCheck.fetchLatestVersion { [weak self] latest in
            guard let self, self.checkForUpdates, let latest else { return }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            self.updateAvailable = UpdateCheck.isNewer(latest, than: current) ? latest : nil
        }
    }

    func reload() {
        lastError = nil
        switch source {
        case .sshConfig:
            let url = Self.sshConfigURL
            if !FileManager.default.fileExists(atPath: url.path) {
                groups = []
                lastError = "No ~/.ssh/config found."
            } else {
                do {
                    let hosts = try SSHConfigParser.parse(at: url)
                    groups = hosts.isEmpty ? [] : [HostGroup(name: "SSH config", hosts: hosts)]
                } catch {
                    groups = []
                    lastError = "Could not read ~/.ssh/config — check file permissions. (\(error.localizedDescription))"
                }
            }
        case .json:
            let url = jsonURL
            let existedBefore = FileManager.default.fileExists(atPath: url.path)
            JSONHostStore.createSampleIfMissing(at: url)
            // Archive the current version (captures manual edits made outside the app).
            if existedBefore { JSONHostStore.snapshotIfChanged(url) }
            do {
                groups = try JSONHostStore.load(from: url, defaultUser: defaultUser)
            } catch {
                groups = []
                lastError = "Invalid JSON file: \(error.localizedDescription)"
            }
        case .remoteJSON:
            reloadRemote()
        }
    }

    /// Loads the remote inventory: shows the local cache immediately (so the
    /// menu works offline), then fetches a fresh copy in the background. The
    /// JSON is decoded with `allowCommands: false` — a remote source provides
    /// inventory only and can never inject commands.
    private func reloadRemote() {
        let urlString = remoteURL.trimmingCharacters(in: .whitespaces)
        guard !urlString.isEmpty else {
            groups = []
            remoteLastUpdated = nil
            lastError = "No remote URL set — add an https:// URL in Settings."
            return
        }

        let overrides = RemoteUserOverrides.load()
        let favoriteKeys = RemoteFavorites.load()

        // Show cached data right away, if any.
        if let cached = RemoteHostStore.loadCache(),
           let cachedGroups = try? JSONHostStore.decode(cached, defaultUser: defaultUser, allowCommands: false, userOverrides: overrides, favoriteKeys: favoriteKeys) {
            groups = cachedGroups
        }

        let defaultUser = self.defaultUser
        Task {
            let result: Result<[HostGroup], Error>
            do {
                let data = try await RemoteHostStore.fetch(from: urlString)
                let fresh = try JSONHostStore.decode(data, defaultUser: defaultUser, allowCommands: false, userOverrides: overrides, favoriteKeys: favoriteKeys)
                RemoteHostStore.saveCache(data)
                result = .success(fresh)
            } catch {
                result = .failure(error)
            }
            await MainActor.run { [weak self] in
                guard let self, self.source == .remoteJSON else { return }
                switch result {
                case .success(let fresh):
                    self.groups = fresh
                    self.remoteLastUpdated = Date()
                    self.lastError = nil
                case .failure(let error):
                    self.lastError = self.groups.isEmpty
                        ? "Couldn't load from the URL: \(error.localizedDescription)"
                        : "Showing cached servers — couldn't refresh: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Pins/unpins a host as a favorite. For the JSON source the flag is written
    /// into the JSON file; for the remote source it's stored locally (per person,
    /// keyed by host:port) so it survives reloads and isn't shared.
    func toggleFavorite(_ host: SSHHost) {
        switch source {
        case .sshConfig:
            return
        case .json:
            let file = JSONHostStore.togglingFavorite(in: JSONHostStore.loadFile(from: jsonURL), host: host, defaultUser: defaultUser)
            do {
                try JSONHostStore.write(file, to: jsonURL, snapshot: false)
                reload()
            } catch {
                lastError = "Could not update favorite: \(error.localizedDescription)"
            }
        case .remoteJSON:
            guard let key = host.favoriteKey else { return }
            var favorites = RemoteFavorites.load()
            if favorites.contains(key) { favorites.remove(key) } else { favorites.insert(key) }
            RemoteFavorites.save(favorites)
            reload()
        }
    }

    func connect(_ host: SSHHost) {
        lastError = nil
        let name = terminal.displayName
        do {
            // CLI terminals launch asynchronously; surface a late failure too.
            try TerminalLauncher.launch(host, in: terminal, mode: effectiveLaunchMode) { [weak self] message in
                DispatchQueue.main.async {
                    self?.lastError = "Could not launch \(name): \(message)"
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
