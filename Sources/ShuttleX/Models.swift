import AppKit
import Foundation

/// Ein einzelner SSH-Eintrag, egal aus welcher Quelle er stammt.
struct SSHHost: Identifiable, Hashable {
    let name: String
    let detail: String?
    let command: String

    var id: String { name + "|" + command }
}

struct HostGroup: Identifiable {
    let name: String
    let hosts: [SSHHost]

    var id: String { name }
}

enum HostSource: String, CaseIterable, Identifiable {
    case sshConfig
    case json

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sshConfig: return "~/.ssh/config"
        case .json: return "JSON-Datei"
        }
    }
}

enum LaunchMode: String, CaseIterable, Identifiable {
    case newWindow
    case newTab
    case splitRight
    case splitDown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newWindow: return "Neues Fenster"
        case .newTab: return "Neuer Tab"
        case .splitRight: return "Split rechts"
        case .splitDown: return "Split unten"
        }
    }

    var systemImage: String {
        switch self {
        case .newWindow: return "macwindow.badge.plus"
        case .newTab: return "rectangle.badge.plus"
        case .splitRight: return "rectangle.split.2x1"
        case .splitDown: return "rectangle.split.1x2"
        }
    }
}

enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal = "com.apple.Terminal"
    case iterm2 = "com.googlecode.iterm2"
    case ghostty = "com.mitchellh.ghostty"
    case warp = "dev.warp.Warp-Stable"
    case alacritty = "org.alacritty"
    case kitty = "net.kovidgoyal.kitty"
    case wezterm = "com.github.wez.wezterm"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal: return "Terminal"
        case .iterm2: return "iTerm2"
        case .ghostty: return "Ghostty"
        case .warp: return "Warp"
        case .alacritty: return "Alacritty"
        case .kitty: return "kitty"
        case .wezterm: return "WezTerm"
        }
    }

    /// Welche Öffnen-Modi die jeweilige App unterstützt. Die CLI-basierten
    /// Terminals lassen sich von außen nur mit neuen Fenstern starten.
    var supportedModes: [LaunchMode] {
        switch self {
        case .iterm2: return LaunchMode.allCases
        case .terminal: return [.newWindow, .newTab]
        case .ghostty, .warp, .alacritty, .kitty, .wezterm: return [.newWindow]
        }
    }

    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue)
    }

    var isInstalled: Bool { appURL != nil }

    static var installed: [TerminalApp] {
        allCases.filter(\.isInstalled)
    }
}
