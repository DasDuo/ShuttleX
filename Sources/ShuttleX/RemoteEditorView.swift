import SwiftUI

/// Editor for the remote (read-only) source. You can't add/delete/reorder the
/// shared inventory, but per server you can set a local login user and a local
/// favorite — both stored on this Mac (keyed by host:port) so they're personal
/// and survive remote reloads. Mirrors the JSON editor for a consistent feel.
struct RemoteEditorView: View {
    let state: AppState
    @Environment(\.dismiss) private var dismiss

    private struct ServerItem: Identifiable {
        let id: String       // unique row id (group + index)
        let key: String      // override/favorite key (host:port)
        let name: String
        let host: String
    }

    private struct ServerSection: Identifiable {
        let id: String
        let items: [ServerItem]
    }

    @State private var overrides = RemoteUserOverrides.load()
    @State private var favorites = RemoteFavorites.load()
    @State private var sections: [ServerSection] = []
    @State private var editing: ServerItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 460, height: 560)
        .onAppear(perform: loadInventory)
        .sheet(item: $editing) { item in
            RemoteEntryForm(
                name: item.name,
                host: item.host,
                defaultUser: state.defaultUser,
                currentUser: overrides[item.key] ?? "",
                isFavorite: favorites.contains(item.key)
            ) { user, favorite in
                apply(item: item, user: user, favorite: favorite)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 18))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text("Remote servers").font(.headline)
                Text("User and favorite are stored locally — kept when the remote list reloads.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        if sections.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(.tertiary)
                Text("No remote servers loaded yet")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text("Open the remote source once so the list is cached, then come back.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(sections) { section in
                    Section(section.id) {
                        ForEach(section.items) { item in
                            row(item)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func row(_ item: ServerItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.system(size: 13, weight: .medium))
                Text(item.host).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if favorites.contains(item.key) {
                Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.yellow)
            }
            if let user = overrides[item.key], !user.isEmpty {
                Text(user).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Button("Edit") { editing = item }
                .buttonStyle(.borderless)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func loadInventory() {
        guard let data = RemoteHostStore.loadCache(),
              let file = try? JSONDecoder().decode(JSONHostStore.File.self, from: data) else {
            sections = []
            return
        }
        func items(_ entries: [JSONHostStore.Entry], group: String) -> [ServerItem] {
            entries.enumerated().compactMap { index, entry in
                // Raw-command entries have no host to key on; remote ignores them anyway.
                guard entry.command?.isEmpty ?? true else { return nil }
                let host = entry.host ?? entry.name
                return ServerItem(
                    id: "\(group)#\(index)",
                    key: RemoteUserOverrides.key(host: host, port: entry.port),
                    name: entry.name,
                    host: host
                )
            }
        }
        var result: [ServerSection] = []
        if let hosts = file.hosts, !hosts.isEmpty {
            result.append(ServerSection(id: "Servers", items: items(hosts, group: "Servers")))
        }
        for group in file.groups ?? [] {
            result.append(ServerSection(id: group.name, items: items(group.hosts, group: group.name)))
        }
        sections = result.filter { !$0.items.isEmpty }
    }

    private func apply(item: ServerItem, user: String?, favorite: Bool) {
        if let user, !user.isEmpty { overrides[item.key] = user } else { overrides[item.key] = nil }
        if favorite { favorites.insert(item.key) } else { favorites.remove(item.key) }
        RemoteUserOverrides.save(overrides)
        RemoteFavorites.save(favorites)
        state.reload()
    }
}

// MARK: - Per-server edit form (user + favorite)

private struct RemoteEntryForm: View {
    let name: String
    let host: String
    let defaultUser: String
    let onSave: (_ user: String?, _ favorite: Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var useDefaultUser: Bool
    @State private var user: String
    @State private var favorite: Bool

    init(name: String, host: String, defaultUser: String, currentUser: String, isFavorite: Bool,
         onSave: @escaping (_ user: String?, _ favorite: Bool) -> Void) {
        self.name = name
        self.host = host
        self.defaultUser = defaultUser
        self.onSave = onSave
        let trimmed = currentUser.trimmingCharacters(in: .whitespaces)
        _useDefaultUser = State(initialValue: trimmed.isEmpty)
        _user = State(initialValue: trimmed)
        _favorite = State(initialValue: isFavorite)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Server") {
                    LabeledContent("Name", value: name)
                    LabeledContent("Host", value: host)
                }
                Section("Connection") {
                    Toggle("Use default user", isOn: $useDefaultUser)
                    if useDefaultUser {
                        Text(defaultUser.isEmpty
                            ? "No default user set — connects without a user. Set one in Settings → Server source."
                            : "Uses the default user “\(defaultUser)”.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("User", text: $user)
                    }
                }
                Section {
                    Toggle("Favorite", isOn: $favorite)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!useDefaultUser && !HostValidation.isSafe(user))
            }
            .padding(16)
        }
        .frame(width: 420, height: 380)
    }

    private func save() {
        let resolved = useDefaultUser ? nil : user.trimmingCharacters(in: .whitespaces)
        onSave(resolved, favorite)
        dismiss()
    }
}
