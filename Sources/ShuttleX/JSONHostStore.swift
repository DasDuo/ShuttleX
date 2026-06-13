import Foundation

/// Loads servers from a dedicated JSON file (~/.config/shuttlex/servers.json).
enum JSONHostStore {
    struct File: Codable {
        var groups: [Group]?
        var hosts: [Entry]?
    }

    struct Group: Codable {
        var name: String
        var hosts: [Entry]
    }

    struct Entry: Codable {
        var name: String
        var host: String?
        var user: String?
        var port: Int?
        var command: String?
    }

    static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/shuttlex/servers.json")

    static func load(from url: URL) throws -> [HostGroup] {
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(File.self, from: data)

        var groups: [HostGroup] = []
        if let ungrouped = file.hosts, !ungrouped.isEmpty {
            groups.append(HostGroup(name: "Servers", hosts: ungrouped.map(makeHost)))
        }
        for group in file.groups ?? [] {
            groups.append(HostGroup(name: group.name, hosts: group.hosts.map(makeHost)))
        }
        return groups
    }

    private static func makeHost(_ entry: Entry) -> SSHHost {
        if let command = entry.command {
            return SSHHost(name: entry.name, detail: command, command: command)
        }
        let host = entry.host ?? entry.name
        var target = host
        if let user = entry.user { target = "\(user)@\(host)" }
        var command = "ssh \(target)"
        if let port = entry.port, port != 22 { command += " -p \(port)" }
        return SSHHost(name: entry.name, detail: target, command: command)
    }

    /// Writes the JSON file nicely formatted.
    static func write(_ file: File, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(file)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    /// Loads the raw file (for merging); if it's missing, returns an empty structure.
    static func loadFile(from url: URL) -> File {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            return File(groups: [], hosts: nil)
        }
        return file
    }

    /// Merges imported groups into an existing file: matching group and entry
    /// names are updated, new ones appended, everything else kept.
    static func merge(_ incoming: File, into existing: File) -> File {
        var groups = existing.groups ?? []
        for newGroup in incoming.groups ?? [] {
            if let index = groups.firstIndex(where: { $0.name == newGroup.name }) {
                var hosts = groups[index].hosts
                for entry in newGroup.hosts {
                    if let hostIndex = hosts.firstIndex(where: { $0.name == entry.name }) {
                        hosts[hostIndex] = entry
                    } else {
                        hosts.append(entry)
                    }
                }
                groups[index].hosts = hosts
            } else {
                groups.append(newGroup)
            }
        }
        return File(groups: groups, hosts: existing.hosts)
    }

    /// Creates a sample file if none exists yet.
    @discardableResult
    static func createSampleIfMissing(at url: URL) -> Bool {
        guard !FileManager.default.fileExists(atPath: url.path) else { return false }
        let sample = """
        {
          "groups": [
            {
              "name": "Example",
              "hosts": [
                { "name": "Web server", "user": "root", "host": "web1.example.com" },
                { "name": "Database", "user": "admin", "host": "db.example.com", "port": 2222 },
                { "name": "Via jump host", "command": "ssh -J jump.example.com root@10.0.0.5" }
              ]
            }
          ]
        }
        """
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try sample.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
