import AppKit
import Foundation

enum LaunchError: LocalizedError {
    case notInstalled(String)
    case scriptFailed(String)
    case permissionDenied(String)
    case warpFailed

    var errorDescription: String? {
        switch self {
        case .notInstalled(let name):
            return "\(name) is not installed."
        case .scriptFailed(let message):
            return "AppleScript error: \(message)"
        case .permissionDenied(let app):
            return "ShuttleX isn't allowed to control \(app). Allow it under System Settings → Privacy & Security → Automation (and Accessibility for Terminal tabs), then try again."
        case .warpFailed:
            return "Could not create the Warp launch configuration."
        }
    }
}

enum TerminalLauncher {
    /// Resolves the mode to actually use: a new window when the terminal isn't
    /// running yet (tab/split only make sense with an existing window), otherwise
    /// the requested mode if the terminal supports it.
    static func effectiveMode(requested: LaunchMode, supported: [LaunchMode], isRunning: Bool) -> LaunchMode {
        guard isRunning else { return .newWindow }
        return supported.contains(requested) ? requested : .newWindow
    }

    static func launch(_ host: SSHHost, in terminal: TerminalApp, mode requestedMode: LaunchMode,
                       onAsyncError: ((String) -> Void)? = nil) throws {
        guard let appURL = terminal.appURL else {
            throw LaunchError.notInstalled(terminal.displayName)
        }
        let isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == terminal.rawValue }
        let mode = effectiveMode(requested: requestedMode, supported: terminal.supportedModes, isRunning: isRunning)

        switch terminal {
        case .terminal:
            try runAppleScript(terminalScript(host.command, mode: mode, isRunning: isRunning), app: terminal.displayName)
        case .iterm2:
            try runAppleScript(itermScript(host.command, mode: mode, isRunning: isRunning), app: terminal.displayName)
        case .warp:
            try launchWarp(host)
        case .ghostty:
            openApp(at: appURL, arguments: ["-e", "/bin/sh", "-lc", host.command], onError: onAsyncError)
        case .alacritty:
            openApp(at: appURL, arguments: ["-e", "/bin/sh", "-lc", host.command], onError: onAsyncError)
        case .kitty:
            openApp(at: appURL, arguments: ["/bin/sh", "-lc", host.command], onError: onAsyncError)
        case .wezterm:
            openApp(at: appURL, arguments: ["start", "--", "/bin/sh", "-lc", host.command], onError: onAsyncError)
        }
    }

    // MARK: - Scripts

    /// Terminal.app: windows via `do script`, tabs only via a Cmd+T keystroke
    /// (System Events, requires the Accessibility permission).
    private static func terminalScript(_ command: String, mode: LaunchMode, isRunning: Bool) -> String {
        let escaped = appleScriptEscaped(command)
        // Fresh launch: reuse the window Terminal opens on startup instead of
        // adding a second one.
        if !isRunning {
            return """
            tell application id "com.apple.Terminal"
                activate
                repeat 30 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.05
                end repeat
                if (count of windows) is 0 then
                    do script "\(escaped)"
                else
                    do script "\(escaped)" in selected tab of front window
                end if
            end tell
            """
        }
        switch mode {
        case .newTab:
            return """
            tell application id "com.apple.Terminal"
                activate
                if (count of windows) is 0 then
                    do script "\(escaped)"
                else
                    set tabsBefore to count of tabs of front window
                    tell application "System Events" to keystroke "t" using command down
                    repeat 40 times
                        if (count of tabs of front window) > tabsBefore then exit repeat
                        delay 0.05
                    end repeat
                    do script "\(escaped)" in selected tab of front window
                end if
            end tell
            """
        default:
            return """
            tell application id "com.apple.Terminal"
                activate
                do script "\(escaped)"
            end tell
            """
        }
    }

    private static func itermScript(_ command: String, mode: LaunchMode, isRunning: Bool) -> String {
        let escaped = appleScriptEscaped(command)
        let newWindowBody = """
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(escaped)"
                end tell
        """
        // Fresh launch: iTerm may open a window on startup. Reuse it (or create
        // one if it doesn't) so we don't end up with two windows.
        if !isRunning {
            return """
            tell application id "com.googlecode.iterm2"
                activate
                repeat 30 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.05
                end repeat
                if (count of windows) is 0 then
            \(newWindowBody)
                else
                    tell current session of current window
                        write text "\(escaped)"
                    end tell
                end if
            end tell
            """
        }
        switch mode {
        case .newWindow:
            return """
            tell application id "com.googlecode.iterm2"
                activate
            \(newWindowBody)
            end tell
            """
        case .newTab:
            return """
            tell application id "com.googlecode.iterm2"
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
            tell application id "com.googlecode.iterm2"
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

    private static func runAppleScript(_ source: String, app: String) throws {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw LaunchError.scriptFailed("Could not create the script.")
        }
        script.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return }

        let number = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
        let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error."
        let lowered = message.lowercased()
        // -1743 = not authorized to send Apple events (Automation); the keystroke
        // path (Terminal tabs) fails with an "assistive access" / "not allowed" message.
        if number == -1743
            || lowered.contains("not authoriz")
            || lowered.contains("not allowed")
            || lowered.contains("assistive access") {
            throw LaunchError.permissionDenied(app)
        }
        throw LaunchError.scriptFailed(message)
    }

    static func appleScriptEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\") // must be first
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    // MARK: - CLI arguments (Ghostty, Alacritty, kitty, WezTerm)

    private static func openApp(at url: URL, arguments: [String], onError: ((String) -> Void)? = nil) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        // openApplication is async, so a failure here can't be thrown from launch();
        // report it back via onError so the UI can surface it.
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("ShuttleX: failed to launch terminal: \(error.localizedDescription)")
                onError?(error.localizedDescription)
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
            .replacingOccurrences(of: "\\", with: "\\\\") // must be first
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
