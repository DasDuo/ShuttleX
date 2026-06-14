import Foundation

/// Minimal parser for ~/.ssh/config: reads Host entries (without wildcards)
/// and supports Include directives.
enum SSHConfigParser {
    static func parse(at url: URL) -> [SSHHost] {
        parse(at: url, depth: 0)
    }

    private static func parse(at url: URL, depth: Int) -> [SSHHost] {
        guard depth < 8,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }

        var hosts: [SSHHost] = []
        var currentAliases: [String] = []
        var props: [String: String] = [:]

        func flush() {
            for alias in currentAliases where !isPattern(alias) {
                hosts.append(makeHost(alias: alias, props: props))
            }
            currentAliases = []
            props = [:]
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            guard let (key, value) = splitKeyValue(line) else { continue }

            switch key.lowercased() {
            case "host":
                flush()
                currentAliases = value.split(separator: " ").map(String.init)
            case "match":
                flush()
            case "include":
                for pattern in value.split(separator: " ").map(String.init) {
                    for included in resolveInclude(pattern, relativeTo: url) {
                        hosts.append(contentsOf: parse(at: included, depth: depth + 1))
                    }
                }
            default:
                if !currentAliases.isEmpty, props[key.lowercased()] == nil {
                    props[key.lowercased()] = value
                }
            }
        }
        flush()
        return hosts
    }

    private static func makeHost(alias: String, props: [String: String]) -> SSHHost {
        var detail: String?
        if let hostname = props["hostname"] {
            var text = hostname
            if let user = props["user"] { text = "\(user)@\(text)" }
            if let port = props["port"], port != "22" { text += ":\(port)" }
            detail = text
        } else if let user = props["user"] {
            detail = "\(user)@\(alias)"
        }
        return SSHHost(name: alias, detail: detail, command: "ssh \(Shell.quote(alias))")
    }

    private static func isPattern(_ alias: String) -> Bool {
        alias.contains("*") || alias.contains("?") || alias.hasPrefix("!")
    }

    private static func splitKeyValue(_ line: String) -> (String, String)? {
        let separators = CharacterSet(charactersIn: " \t=")
        guard let range = line.rangeOfCharacter(from: separators) else { return nil }
        let key = String(line[..<range.lowerBound])
        var value = String(line[range.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t="))
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }
        guard !key.isEmpty, !value.isEmpty else { return nil }
        return (key, value)
    }

    /// Resolves an Include path (relative to ~/.ssh, ~ is expanded, * as a glob).
    private static func resolveInclude(_ pattern: String, relativeTo configURL: URL) -> [URL] {
        var path = NSString(string: pattern).expandingTildeInPath
        if !path.hasPrefix("/") {
            path = configURL.deletingLastPathComponent().appendingPathComponent(path).path
        }
        guard path.contains("*") || path.contains("?") else {
            return FileManager.default.fileExists(atPath: path) ? [URL(fileURLWithPath: path)] : []
        }
        let directory = (path as NSString).deletingLastPathComponent
        let filePattern = (path as NSString).lastPathComponent
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        return entries
            .filter { fnmatch(filePattern, $0, 0) == 0 }
            .sorted()
            .map { URL(fileURLWithPath: directory).appendingPathComponent($0) }
    }
}
