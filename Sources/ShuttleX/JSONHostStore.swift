import Foundation

/// Lädt Server aus einer eigenen JSON-Datei (~/.config/shuttlex/servers.json).
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
            groups.append(HostGroup(name: "Server", hosts: ungrouped.map(makeHost)))
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

    /// Legt eine Beispiel-Datei an, falls noch keine existiert.
    @discardableResult
    static func createSampleIfMissing(at url: URL) -> Bool {
        guard !FileManager.default.fileExists(atPath: url.path) else { return false }
        let sample = """
        {
          "groups": [
            {
              "name": "Beispiel",
              "hosts": [
                { "name": "Webserver", "user": "root", "host": "web1.example.com" },
                { "name": "Datenbank", "user": "admin", "host": "db.example.com", "port": 2222 },
                { "name": "Via Jumphost", "command": "ssh -J jump.example.com root@10.0.0.5" }
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
