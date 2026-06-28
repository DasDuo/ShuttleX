import SwiftUI

struct ServerEditorView: View {
    let state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var file = JSONHostStore.File(groups: [], hosts: nil)
    @State private var form: EntryForm.Model?
    @State private var errorText: String?

    private var groups: [JSONHostStore.Group] { file.groups ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            Divider()
            footer
        }
        .frame(width: 460, height: 560)
        .onAppear { file = JSONHostStore.loadFile(from: state.jsonURL) }
        .sheet(item: $form) { model in
            EntryForm(model: model, existingGroups: groups.map(\.name), defaultUser: state.defaultUser, tagsEnabled: state.tagsEnabled) { result in
                if let original = result.original {
                    file = ServerEditing.update(file, group: original.group, id: original.id,
                                                to: result.entry, newGroup: result.group)
                } else {
                    file = ServerEditing.add(file, group: result.group, entry: result.entry)
                }
                persist()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 18))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text("Manage servers").font(.headline)
                Text((state.jsonURL.path as NSString).abbreviatingWithTildeInPath)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        if groups.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(.tertiary)
                Text("No servers yet").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text("Add your first server below.").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(groups, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.hosts) { entry in
                            row(group: group.name, entry: entry)
                        }
                        .onMove { from, to in
                            file = ServerEditing.move(file, group: group.name, fromOffsets: from, toOffset: to)
                            persist()
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func row(group: String, entry: JSONHostStore.Entry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).font(.system(size: 13, weight: .medium))
                Text(detail(entry)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button("Edit") { form = EntryForm.Model(from: entry, group: group) }
                .buttonStyle(.borderless)
            Button {
                file = ServerEditing.duplicate(file, group: group, id: entry.id)
                persist()
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .buttonStyle(.borderless)
            .help("Duplicate")
            Button(role: .destructive) {
                file = ServerEditing.delete(file, group: group, id: entry.id)
                persist()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("Drag to reorder within the group")
        }
    }

    private func detail(_ entry: JSONHostStore.Entry) -> String {
        if let command = entry.command, !command.isEmpty { return command }
        let host = entry.host ?? ""
        var target = entry.user.map { "\($0)@\(host)" } ?? host
        if let port = entry.port, port != 22 { target += ":\(port)" }
        if let remote = entry.remoteCommand, !remote.isEmpty { target += " — \(remote)" }
        return target
    }

    private var footer: some View {
        HStack {
            Button {
                form = EntryForm.Model(group: groups.first?.name ?? "")
            } label: {
                Label("Add server", systemImage: "plus")
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func persist() {
        do {
            try JSONHostStore.write(file, to: state.jsonURL)
            state.source = .json
            state.reload()
            errorText = nil
        } catch {
            errorText = "Could not save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Add/edit form

struct EntryForm: View {
    struct Model: Identifiable {
        let id = UUID()
        var name = ""
        var group = ""
        var useDefaultUser = true
        var user = ""
        var host = ""
        var port = ""
        var remoteCommand = ""
        var command = ""
        var rawMode = false
        var favorite = false
        var tags = ""
        var original: (group: String, id: UUID)?

        init(group: String = "") {
            self.group = group
        }

        init(from entry: JSONHostStore.Entry, group: String) {
            name = entry.name
            self.group = group
            let ownUser = entry.user?.trimmingCharacters(in: .whitespaces) ?? ""
            useDefaultUser = ownUser.isEmpty
            user = ownUser
            tags = (entry.tags ?? []).joined(separator: ", ")
            host = entry.host ?? ""
            port = entry.port.map(String.init) ?? ""
            remoteCommand = entry.remoteCommand ?? ""
            command = entry.command ?? ""
            rawMode = !(entry.command ?? "").isEmpty
            favorite = entry.favorite ?? false
            original = (group: group, id: entry.id)
        }
    }

    struct Result {
        let group: String
        let entry: JSONHostStore.Entry
        let original: (group: String, id: UUID)?
    }

    @State private var model: Model
    let existingGroups: [String]
    let defaultUser: String
    let tagsEnabled: Bool
    let onSave: (Result) -> Void
    @Environment(\.dismiss) private var dismiss

    init(model: Model, existingGroups: [String], defaultUser: String = "", tagsEnabled: Bool = false, onSave: @escaping (Result) -> Void) {
        _model = State(initialValue: model)
        self.existingGroups = existingGroups
        self.defaultUser = defaultUser
        self.tagsEnabled = tagsEnabled
        self.onSave = onSave
    }

    private var validationError: String? {
        if model.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Name is required." }
        if model.rawMode {
            if model.command.trimmingCharacters(in: .whitespaces).isEmpty {
                return "Enter a command, or turn off raw command mode."
            }
        } else {
            let host = model.host.trimmingCharacters(in: .whitespaces)
            if host.isEmpty { return "Host or IP is required." }
            if !HostValidation.isSafe(host) { return "Host contains invalid characters." }
            if !model.useDefaultUser, !HostValidation.isSafe(model.user) { return "User contains invalid characters." }
            if !model.port.isEmpty, Int(model.port) == nil { return "Port must be a number." }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Server") {
                    TextField("Name", text: $model.name)
                    HStack {
                        TextField("Group", text: $model.group)
                        if !existingGroups.isEmpty {
                            Menu {
                                ForEach(existingGroups, id: \.self) { name in
                                    Button(name) { model.group = name }
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }
                    }
                    Toggle("Raw custom command", isOn: $model.rawMode)
                    Toggle("Favorite", isOn: $model.favorite)
                    if tagsEnabled {
                        TextField("Tags (comma-separated)", text: $model.tags, prompt: Text("prod, web, eu"))
                    }
                }
                if model.rawMode {
                    Section("Custom command") {
                        TextField("Command", text: $model.command)
                        Text("Runs verbatim and ignores user/host/port — e.g. a jump host or tunnel.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Connection") {
                        Toggle("Use default user", isOn: $model.useDefaultUser)
                        if model.useDefaultUser {
                            Text(defaultUser.isEmpty
                                ? "No default user set — connects without a user. Set one in Settings → Server source."
                                : "Uses the default user “\(defaultUser)” from Settings.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            TextField("User", text: $model.user)
                        }
                        TextField("Host or IP", text: $model.host)
                        TextField("Port (optional)", text: $model.port)
                        TextField("Remote command (optional)", text: $model.remoteCommand)
                        Text("Leave the remote command empty for an interactive shell. If set, it runs on the server with a TTY (e.g. htop).")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if let validationError {
                    Label(validationError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
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
                    .disabled(validationError != nil)
            }
            .padding(16)
        }
        .frame(width: 420, height: 460)
    }

    private func save() {
        guard validationError == nil else { return }
        let name = model.name.trimmingCharacters(in: .whitespaces)
        let favorite: Bool? = model.favorite ? true : nil
        // Always parsed (even if the tags feature is currently off) so existing
        // tags aren't wiped when editing a server with the feature disabled.
        let tagList = model.tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let tags: [String]? = tagList.isEmpty ? nil : tagList
        let entry: JSONHostStore.Entry
        if model.rawMode {
            entry = JSONHostStore.Entry(
                name: name, host: nil, user: nil, port: nil,
                command: model.command.trimmingCharacters(in: .whitespaces),
                remoteCommand: nil, favorite: favorite, tags: tags
            )
        } else {
            let user = model.useDefaultUser ? "" : model.user.trimmingCharacters(in: .whitespaces)
            let remote = model.remoteCommand.trimmingCharacters(in: .whitespaces)
            entry = JSONHostStore.Entry(
                name: name,
                host: model.host.trimmingCharacters(in: .whitespaces),
                user: user.isEmpty ? nil : user,
                port: model.port.isEmpty ? nil : Int(model.port),
                command: nil,
                remoteCommand: remote.isEmpty ? nil : remote,
                favorite: favorite, tags: tags
            )
        }
        onSave(Result(group: model.group, entry: entry, original: model.original))
        dismiss()
    }
}
