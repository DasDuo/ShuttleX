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

    struct Entry: Codable, Identifiable {
        /// In-memory identity (not persisted) so duplicate-named entries stay distinct
        /// in the editor. Regenerated on load; never written to JSON.
        var id = UUID()
        var name: String
        var host: String?
        var user: String?
        var port: Int?
        /// A raw command run verbatim (overrides host/user/port) — e.g. jump hosts.
        var command: String?
        /// A command to run on the server, built on top of host/user/port (gets a TTY).
        var remoteCommand: String?
        /// User-pinned favorite (written only when true, so the JSON stays clean).
        var favorite: Bool?

        private enum CodingKeys: String, CodingKey {
            case name, host, user, port, command, remoteCommand, favorite
        }
    }

    static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/shuttlex/servers.json")

    static func load(from url: URL, defaultUser: String = "") throws -> [HostGroup] {
        try decode(Data(contentsOf: url), defaultUser: defaultUser)
    }

    /// Builds groups from raw JSON. `allowCommands: false` strips the `command`
    /// and `remoteCommand` fields — used for remote sources, which provide
    /// inventory only (groups/names/host/port) and never executable commands.
    static func decode(_ data: Data, defaultUser: String = "", allowCommands: Bool = true,
                       userOverrides: [String: String] = [:], favoriteKeys: Set<String> = []) throws -> [HostGroup] {
        let file = try JSONDecoder().decode(File.self, from: data)

        // Merge groups that share a name (e.g. from hand-edited JSON) so group
        // names stay unique — otherwise they'd collide as SwiftUI identities and
        // share expand/collapse state. First-seen order is preserved.
        var order: [String] = []
        var hostsByName: [String: [SSHHost]] = [:]
        func add(_ name: String, _ hosts: [SSHHost]) {
            if hostsByName[name] == nil { order.append(name) }
            hostsByName[name, default: []].append(contentsOf: hosts)
        }

        if let ungrouped = file.hosts, !ungrouped.isEmpty {
            add("Servers", ungrouped.map { makeHost($0, defaultUser: defaultUser, allowCommands: allowCommands, userOverrides: userOverrides, favoriteKeys: favoriteKeys) })
        }
        for group in file.groups ?? [] {
            add(group.name, group.hosts.map { makeHost($0, defaultUser: defaultUser, allowCommands: allowCommands, userOverrides: userOverrides, favoriteKeys: favoriteKeys) })
        }
        return order.map { HostGroup(name: $0, hosts: hostsByName[$0]!) }
    }

    /// Resolves the effective login user: a local `override` wins, then an
    /// entry's own user, then the global `defaultUser`; if none is set, none.
    private static func effectiveUser(_ entry: Entry, defaultUser: String, override: String?) -> String? {
        if let over = override?.trimmingCharacters(in: .whitespaces), !over.isEmpty { return over }
        if let own = entry.user?.trimmingCharacters(in: .whitespaces), !own.isEmpty { return own }
        let fallback = defaultUser.trimmingCharacters(in: .whitespaces)
        return fallback.isEmpty ? nil : fallback
    }

    private static func makeHost(_ entry: Entry, defaultUser: String = "", allowCommands: Bool = true,
                                 userOverrides: [String: String] = [:], favoriteKeys: Set<String> = []) -> SSHHost {
        // A raw command takes over completely — but never from a remote source.
        if allowCommands, let command = entry.command, !command.isEmpty {
            return SSHHost(name: entry.name, detail: command, command: command, favorite: entry.favorite ?? false)
        }

        let host = entry.host ?? entry.name
        let serverKey = RemoteUserOverrides.key(host: host, port: entry.port)
        let override = userOverrides[serverKey]
        // A favorite comes from the JSON entry (local source) or the local
        // per-person favorites set (remote source).
        let favorite = (entry.favorite ?? false) || favoriteKeys.contains(serverKey)
        let user = effectiveUser(entry, defaultUser: defaultUser, override: override)
        let target = user.map { "\($0)@\(host)" } ?? host
        let remote = allowCommands ? entry.remoteCommand.flatMap { $0.isEmpty ? nil : $0 } : nil

        // Build `ssh [-t] [-p port] user@host [remote-command]`. Everything is
        // shell-quoted so host/user/command values can't inject shell commands.
        var parts = ["ssh"]
        if remote != nil { parts.append("-t") } // TTY, so interactive tools (htop) work
        if let port = entry.port, port != 22 { parts.append("-p"); parts.append(String(port)) }
        parts.append(Shell.quote(target))
        if let remote { parts.append(Shell.quote(remote)) }

        let detail = remote.map { "\(target): \($0)" } ?? target
        return SSHHost(name: entry.name, detail: detail, command: parts.joined(separator: " "),
                       favorite: favorite, favoriteKey: serverKey)
    }

    /// Writes the JSON file nicely formatted. By default it snapshots the previous
    /// version first; pass `snapshot: false` for trivial changes (e.g. toggling a favorite).
    static func write(_ file: File, to url: URL, snapshot: Bool = true) throws {
        if snapshot { snapshotIfChanged(url) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(file)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    /// Returns a copy of `file` with the favorite flag flipped on the entry that
    /// produces `host` (matched by the built command + name). `true` is stored as
    /// `true`, un-favoriting clears the field so the JSON stays clean.
    static func togglingFavorite(in file: File, host: SSHHost, defaultUser: String = "") -> File {
        func flip(_ entries: [Entry]) -> [Entry] {
            entries.map { entry in
                guard makeHost(entry, defaultUser: defaultUser).id == host.id else { return entry }
                var copy = entry
                copy.favorite = (entry.favorite == true) ? nil : true
                return copy
            }
        }
        var result = file
        result.hosts = file.hosts.map(flip)
        result.groups = file.groups?.map { group in
            var copy = group
            copy.hosts = flip(group.hosts)
            return copy
        }
        return result
    }

    // MARK: - Backup history

    private static let backupStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Millisecond resolution so two snapshots in the same second (e.g. the
        // pre- and post-import archives) don't collide on one filename.
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Archives the current file next to it (e.g. `servers.backup-20260614-101530-123.json`)
    /// whenever its content differs from the newest existing backup, keeping `keep` versions.
    static func snapshotIfChanged(_ url: URL, keep: Int = 3) {
        guard let data = try? Data(contentsOf: url) else { return }
        let directory = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "bak" : url.pathExtension

        let existing = backups(in: directory, base: base, ext: ext)
        if let newest = existing.first, (try? Data(contentsOf: newest)) == data { return }

        let stamp = backupStampFormatter.string(from: Date())
        var destination = directory.appendingPathComponent("\(base).backup-\(stamp).\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("\(base).backup-\(stamp)-\(counter).\(ext)")
            counter += 1
        }
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            NSLog("ShuttleX: backup write failed at \(destination.path): \(error.localizedDescription)")
            return
        }

        for old in backups(in: directory, base: base, ext: ext).dropFirst(keep) {
            do {
                try FileManager.default.removeItem(at: old)
            } catch {
                NSLog("ShuttleX: backup prune failed for \(old.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// Backup files for `base.ext` in `directory`, newest first (by modification date).
    static func backups(in directory: URL, base: String, ext: String) -> [URL] {
        let prefix = "\(base).backup-"
        let suffix = ".\(ext)"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let urls = names
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(suffix) }
            .map { directory.appendingPathComponent($0) }
        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        return urls.sorted { a, b in
            let (da, db) = (modified(a), modified(b))
            return da != db ? da > db : a.lastPathComponent > b.lastPathComponent
        }
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
