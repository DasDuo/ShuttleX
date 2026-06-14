import Foundation

/// Pure helpers that add/update/remove a host inside a JSON file structure.
/// Kept separate from the UI so they can be unit-tested.
enum ServerEditing {
    /// Inserts or updates `entry` in `group`. When `original` is given (editing an
    /// existing host), that host is removed first, so renames and group moves work.
    /// Groups that become empty are dropped; a missing target group is created.
    static func upsert(
        _ file: JSONHostStore.File,
        group rawGroup: String,
        entry: JSONHostStore.Entry,
        replacing original: (group: String, name: String)?
    ) -> JSONHostStore.File {
        var groups = file.groups ?? []

        if let original {
            if let index = groups.firstIndex(where: { $0.name == original.group }) {
                groups[index].hosts.removeAll { $0.name == original.name }
                if groups[index].hosts.isEmpty { groups.remove(at: index) }
            }
        }

        let trimmed = rawGroup.trimmingCharacters(in: .whitespaces)
        let group = trimmed.isEmpty ? "Servers" : trimmed

        if let index = groups.firstIndex(where: { $0.name == group }) {
            if let hostIndex = groups[index].hosts.firstIndex(where: { $0.name == entry.name }) {
                groups[index].hosts[hostIndex] = entry
            } else {
                groups[index].hosts.append(entry)
            }
        } else {
            groups.append(JSONHostStore.Group(name: group, hosts: [entry]))
        }

        var result = file
        result.groups = groups
        return result
    }

    static func delete(_ file: JSONHostStore.File, group: String, name: String) -> JSONHostStore.File {
        var groups = file.groups ?? []
        if let index = groups.firstIndex(where: { $0.name == group }) {
            groups[index].hosts.removeAll { $0.name == name }
            if groups[index].hosts.isEmpty { groups.remove(at: index) }
        }
        var result = file
        result.groups = groups
        return result
    }
}
