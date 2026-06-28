import Foundation

/// Pure helpers that add/update/remove/reorder a host inside a JSON file structure.
/// Entries are addressed by their (in-memory) `id`, so duplicate names stay distinct.
/// Kept separate from the UI so they can be unit-tested.
enum ServerEditing {
    /// Appends a new entry to `group` (creating the group if needed).
    static func add(_ file: JSONHostStore.File, group rawGroup: String, entry: JSONHostStore.Entry) -> JSONHostStore.File {
        var groups = file.groups ?? []
        let group = normalized(rawGroup)
        if let index = groups.firstIndex(where: { $0.name == group }) {
            groups[index].hosts.append(entry)
        } else {
            groups.append(JSONHostStore.Group(name: group, hosts: [entry]))
        }
        return withGroups(file, groups)
    }

    /// Replaces the entry identified by `id` in `group` with `entry`. When `newGroup`
    /// differs, the entry moves there. Groups left empty are dropped; a missing target
    /// group is created.
    static func update(
        _ file: JSONHostStore.File,
        group: String,
        id: UUID,
        to entry: JSONHostStore.Entry,
        newGroup rawNewGroup: String
    ) -> JSONHostStore.File {
        var groups = file.groups ?? []
        guard let groupIndex = groups.firstIndex(where: { $0.name == group }),
              let hostIndex = groups[groupIndex].hosts.firstIndex(where: { $0.id == id })
        else { return file }

        let newGroup = normalized(rawNewGroup)
        if newGroup == group {
            groups[groupIndex].hosts[hostIndex] = entry
            return withGroups(file, groups)
        }

        groups[groupIndex].hosts.remove(at: hostIndex)
        if groups[groupIndex].hosts.isEmpty { groups.remove(at: groupIndex) }
        if let targetIndex = groups.firstIndex(where: { $0.name == newGroup }) {
            groups[targetIndex].hosts.append(entry)
        } else {
            groups.append(JSONHostStore.Group(name: newGroup, hosts: [entry]))
        }
        return withGroups(file, groups)
    }

    /// Inserts a copy of the entry identified by `id` directly after it in the
    /// same group. The copy gets a fresh id (so it stays distinct) and its name
    /// suffixed with "-copy"; everything else is carried over.
    static func duplicate(_ file: JSONHostStore.File, group: String, id: UUID) -> JSONHostStore.File {
        var groups = file.groups ?? []
        guard let groupIndex = groups.firstIndex(where: { $0.name == group }),
              let hostIndex = groups[groupIndex].hosts.firstIndex(where: { $0.id == id })
        else { return file }
        var copy = groups[groupIndex].hosts[hostIndex]
        copy.id = UUID()
        copy.name += "-copy"
        groups[groupIndex].hosts.insert(copy, at: hostIndex + 1)
        return withGroups(file, groups)
    }

    static func delete(_ file: JSONHostStore.File, group: String, id: UUID) -> JSONHostStore.File {
        var groups = file.groups ?? []
        guard let groupIndex = groups.firstIndex(where: { $0.name == group }) else { return file }
        groups[groupIndex].hosts.removeAll { $0.id == id }
        if groups[groupIndex].hosts.isEmpty { groups.remove(at: groupIndex) }
        return withGroups(file, groups)
    }

    /// Reorders hosts within a group, following SwiftUI `.onMove` semantics.
    static func move(_ file: JSONHostStore.File, group: String, fromOffsets: IndexSet, toOffset: Int) -> JSONHostStore.File {
        var groups = file.groups ?? []
        guard let groupIndex = groups.firstIndex(where: { $0.name == group }) else { return file }
        groups[groupIndex].hosts.move(fromOffsets: fromOffsets, toOffset: toOffset)
        return withGroups(file, groups)
    }

    private static func normalized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Servers" : trimmed
    }

    private static func withGroups(_ file: JSONHostStore.File, _ groups: [JSONHostStore.Group]) -> JSONHostStore.File {
        var result = file
        result.groups = groups
        return result
    }
}
