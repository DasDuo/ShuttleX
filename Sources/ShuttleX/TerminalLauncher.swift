import AppKit
import Foundation

enum LaunchError: LocalizedError {
    case notInstalled(String)
    case scriptFailed(String)
    case warpFailed

    var errorDescription: String? {
        switch self {
        case .notInstalled(let name):
            return "\(name) is not installed."
        case .scriptFailed(let message):
            return "AppleScript error: \(message)"
        case .warpFailed:
            return "Could not create the Warp launch configuration."
        }
    }
}

enum TerminalLauncher {
    static func launch(_ host: SSHHost, in terminal: TerminalApp, mode: LaunchMode) throws {
        guard let appURL = terminal.appURL else {
            throw LaunchError.notInstalled(terminal.displayName)
        }
        let mode = terminal.supportedModes.contains(mode) ? mode : .newWindow

        switch terminal {
        case .terminal:
            try runAppleScript(terminalScript(host.command, mode: mode))
        case .iterm2:
            try runAppleScript(itermScript(host.command, mode: mode))
        case .warp:
            try launchWarp(host)
        case .ghostty:
            openApp(at: appURL, arguments: ["-e", "/bin/sh", "-lc", host.command])
        case .alacritty:
            openApp(at: appURL, arguments: ["-e", "/bin/sh", "-lc", host.command])
        case .kitty:
            openApp(at: appURL, arguments: ["/bin/sh", "-lc", host.command])
        case .wezterm:
            openApp(at: appURL, arguments: ["start", "--", "/bin/sh", "-lc", host.command])
        }
    }

    // MARK: - Scripts

    /// Terminal.app: windows via `do script`, tabs only via a Cmd+T keystroke
    /// (System Events, requires the Accessibility permission).
    private static func terminalScript(_ command: String, mode: LaunchMode) -> String {
        let escaped = appleScriptEscaped(command)
        switch mode {
        case .newTab:
            return """
            tell application "Terminal"
                activate
                if (count of windows) is 0 then
                    do script "\(escaped)"
                else
                    tell application "System Events" to keystroke "t" using command down
                    delay 0.3
                    do script "\(escaped)" in selected tab of front window
                end if
            end tell
            """
        default:
            return """
            tell application "Terminal"
                activate
                do script "\(escaped)"
            end tell
            """
        }
    }

    private static func itermScript(_ command: String, mode: LaunchMode) -> String {
        let escaped = appleScriptEscaped(command)
        let newWindowBody = """
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(escaped)"
                end tell
        """
        switch mode {
        case .newWindow:
            return """
            tell application "iTerm"
                activate
            \(newWindowBody)
            end tell
            """
        case .newTab:
            return """
            tell application "iTerm"
                activate
                if (count of windows) is 0 then
            \(newWindowBody)
                else
                    tell current window
                        set newTab to (create tab with default profile)
                        tell current session of newTab
                            write text "\(escaped)"
                        end tell
                    end tell
                end if
            end tell
            """
        case .splitRight, .splitDown:
            let direction = mode == .splitRight ? "vertically" : "horizontally"
            return """
            tell application "iTerm"
                activate
                if (count of windows) is 0 then
            \(newWindowBody)
                else
                    tell current session of current window
                        set newSession to (split \(direction) with default profile)
                    end tell
                    tell newSession
                        write text "\(escaped)"
                    end tell
                end if
            end tell
            """
        }
    }

    // MARK: - AppleScript (Terminal.app, iTerm2)

    private static func runAppleScript(_ source: String) throws {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw LaunchError.scriptFailed("Could not create the script.")
        }
        script.executeAndReturnError(&errorInfo)
        if let errorInfo, let message = errorInfo[NSAppleScript.errorMessage] as? String {
            throw LaunchError.scriptFailed(message)
        }
    }

    private static func appleScriptEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - CLI arguments (Ghostty, Alacritty, kitty, WezTerm)

    private static func openApp(at url: URL, arguments: [String]) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("ShuttleX: failed to launch terminal: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Warp (launch configuration + URL scheme)

    private static func launchWarp(_ host: SSHHost) throws {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShuttleX")
        let configURL = directory.appendingPathComponent("launch.yaml")
        let yaml = """
        ---
        name: ShuttleX
        windows:
          - tabs:
              - title: "\(yamlEscaped(host.name))"
                layout:
                  commands:
                    - exec: "\(yamlEscaped(host.command))"
        """
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try yaml.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            throw LaunchError.warpFailed
        }
        guard let encodedPath = configURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "warp://launch/\(encodedPath)") else {
            throw LaunchError.warpFailed
        }
        NSWorkspace.shared.open(url)
    }

    private static func yamlEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
