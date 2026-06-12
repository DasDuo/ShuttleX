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

    /// Der tatsächlich verwendete Modus — fällt auf „Neues Fenster" zurück,
    /// wenn die gewählte Terminal-App den Modus nicht unterstützt.
    var effectiveLaunchMode: LaunchMode {
        terminal.supportedModes.contains(launchMode) ? launchMode : .newWindow
    }

    private(set) var groups: [HostGroup] = []
    var lastError: String?

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
        reload()
    }

    func reload() {
        lastError = nil
        switch source {
        case .sshConfig:
            let hosts = SSHConfigParser.parse(at: Self.sshConfigURL)
            groups = hosts.isEmpty ? [] : [HostGroup(name: "SSH-Config", hosts: hosts)]
            if !FileManager.default.fileExists(atPath: Self.sshConfigURL.path) {
                lastError = "Keine ~/.ssh/config gefunden."
            }
        case .json:
            JSONHostStore.createSampleIfMissing(at: JSONHostStore.defaultURL)
            do {
                groups = try JSONHostStore.load(from: JSONHostStore.defaultURL)
            } catch {
                groups = []
                lastError = "JSON-Datei fehlerhaft: \(error.localizedDescription)"
            }
        }
    }

    func connect(_ host: SSHHost) {
        do {
            try TerminalLauncher.launch(host, in: terminal, mode: effectiveLaunchMode)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
