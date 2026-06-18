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
                groups = try JSONHostStore.load(from: url)
            } catch {
                groups = []
                lastError = "Invalid JSON file: \(error.localizedDescription)"
            }
        }
    }

    /// Pins/unpins a host as a favorite (JSON source only). Writes the flag to the
    /// JSON entry without a backup snapshot and reloads.
    func toggleFavorite(_ host: SSHHost) {
        guard source == .json else { return }
        let file = JSONHostStore.togglingFavorite(in: JSONHostStore.loadFile(from: jsonURL), host: host)
        do {
            try JSONHostStore.write(file, to: jsonURL, snapshot: false)
            reload()
        } catch {
            lastError = "Could not update favorite: \(error.localizedDescription)"
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
