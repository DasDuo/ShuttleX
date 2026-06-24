import Foundation

enum HostFiltering {
    /// Filters groups by a search query. A match on the group name keeps the
    /// whole group; otherwise only hosts matching by name, detail or command are kept.
    static func filter(_ groups: [HostGroup], query: String, includeTags: Bool = false) -> [HostGroup] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return groups }

        return groups.compactMap { group in
            if group.name.lowercased().contains(needle) {
                return group
            }
            let hosts = group.hosts.filter { host in
                host.name.lowercased().contains(needle)
                    || (host.detail?.lowercased().contains(needle) ?? false)
                    || host.command.lowercased().contains(needle)
                    || (includeTags && host.tags.contains { $0.lowercased().contains(needle) })
            }
            return hosts.isEmpty ? nil : HostGroup(name: group.name, hosts: hosts)
        }
    }
}
