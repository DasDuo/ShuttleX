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
            EntryForm(model: model, existingGroups: groups.map(\.name)) { result in
                file = ServerEditing.upsert(file, group: result.group, entry: result.entry, replacing: result.original)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups, id: \.name) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(group.hosts.enumerated()), id: \.offset) { _, entry in
                                row(group: group.name, entry: entry)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
            Button(role: .destructive) {
                file = ServerEditing.delete(file, group: group, name: entry.name)
                persist()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 7))
    }

    private func detail(_ entry: JSONHostStore.Entry) -> String {
        if let command = entry.command { return command }
        let host = entry.host ?? ""
        var target = entry.user.map { "\($0)@\(host)" } ?? host
        if let port = entry.port, port != 22 { target += ":\(port)" }
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
        var user = ""
        var host = ""
        var port = ""
        var command = ""
        var original: (group: String, name: String)?

        init(group: String = "") {
            self.group = group
        }

        init(from entry: JSONHostStore.Entry, group: String) {
            name = entry.name
            self.group = group
            user = entry.user ?? ""
            host = entry.host ?? ""
            port = entry.port.map(String.init) ?? ""
            command = entry.command ?? ""
            original = (group: group, name: entry.name)
        }
    }

    struct Result {
        let group: String
        let entry: JSONHostStore.Entry
        let original: (group: String, name: String)?
    }

    @State private var model: Model
    let existingGroups: [String]
    let onSave: (Result) -> Void
    @Environment(\.dismiss) private var dismiss

    init(model: Model, existingGroups: [String], onSave: @escaping (Result) -> Void) {
        _model = State(initialValue: model)
        self.existingGroups = existingGroups
        self.onSave = onSave
    }

    private var usesCommand: Bool {
        !model.command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var validationError: String? {
        if model.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Name is required." }
        if !usesCommand {
            let host = model.host.trimmingCharacters(in: .whitespaces)
            if host.isEmpty { return "Host or IP is required (or set a custom command)." }
            if !HostValidation.isSafe(host) { return "Host contains invalid characters." }
            if !HostValidation.isSafe(model.user) { return "User contains invalid characters." }
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
                    TextField("User", text: $model.user)
                        .disabled(usesCommand)
                    TextField("Host or IP", text: $model.host)
                        .disabled(usesCommand)
                    TextField("Port (optional)", text: $model.port)
                        .disabled(usesCommand)
                }
                Section("Advanced") {
                    TextField("Custom command (optional)", text: $model.command)
                    Text("If set, this runs verbatim and overrides user/host/port — e.g. for jump hosts or tunnels.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
        let command = model.command.trimmingCharacters(in: .whitespaces)
        let entry: JSONHostStore.Entry
        if !command.isEmpty {
            entry = JSONHostStore.Entry(name: name, host: nil, user: nil, port: nil, command: command)
        } else {
            let user = model.user.trimmingCharacters(in: .whitespaces)
            entry = JSONHostStore.Entry(
                name: name,
                host: model.host.trimmingCharacters(in: .whitespaces),
                user: user.isEmpty ? nil : user,
                port: model.port.isEmpty ? nil : Int(model.port),
                command: nil
            )
        }
        onSave(Result(group: model.group, entry: entry, original: model.original))
        dismiss()
    }
}
