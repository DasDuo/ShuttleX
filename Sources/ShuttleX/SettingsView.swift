import KeyboardShortcuts
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @State private var parseResult: TableImporter.ParseResult?
    @State private var importError: String?
    @State private var showEditor = false

    var body: some View {
        @Bindable var state = state
        Form {
            Section("Terminal") {
                Picker("Terminal app", selection: $state.terminal) {
                    ForEach(TerminalApp.installed) { app in
                        Text(app.displayName).tag(app)
                    }
                }
                Picker("Open in", selection: Binding(
                    get: { state.effectiveLaunchMode },
                    set: { state.launchMode = $0 }
                )) {
                    ForEach(state.terminal.supportedModes) { mode in
                        Label(mode.label, systemImage: mode.systemImage).tag(mode)
                    }
                }
                if state.terminal.supportedModes == [.newWindow] {
                    Text("\(state.terminal.displayName) can only be launched in new windows from outside.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if state.terminal == .terminal, state.effectiveLaunchMode == .newTab {
                    Text("New tabs in Terminal.app require ShuttleX to be allowed under System Settings → Privacy & Security → Accessibility.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if state.terminal == .terminal || state.terminal == .iterm2 {
                    Text("On first connect, macOS asks once for permission to control \(state.terminal.displayName).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Server source") {
                Picker("Source", selection: $state.source) {
                    ForEach(HostSource.allCases) { source in
                        Text(source.label).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                switch state.source {
                case .sshConfig:
                    LabeledContent("File", value: "~/.ssh/config")
                    LabeledContent("Hosts found", value: "\(state.hostCount)")
                case .json:
                    LabeledContent("File") {
                        Text((state.jsonURL.path as NSString).abbreviatingWithTildeInPath)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Hosts found", value: "\(state.hostCount)")
                    TextField("Default user", text: $state.defaultUser, prompt: Text("none"))
                    Text("Used for servers that don't set their own user. You can override it per server in the editor.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Add / edit servers…") { showEditor = true }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    HStack {
                        Button("Choose…") { chooseJSONLocation() }
                        if state.usingCustomJSONPath {
                            Button("Reset to default") { state.setJSONPath(nil) }
                        }
                        Spacer()
                    }
                    HStack {
                        Button("Edit file") {
                            JSONHostStore.createSampleIfMissing(at: state.jsonURL)
                            NSWorkspace.shared.open(state.jsonURL)
                        }
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([state.jsonURL])
                        }
                        Spacer()
                        Button("Reload") {
                            state.reload()
                        }
                    }
                    Text("The last 3 versions are kept as backups next to the file (e.g. servers.backup-…json) on every change — whether edited manually or imported.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let error = state.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            Section("Table import") {
                Text("Generates the JSON from a spreadsheet with the columns User, Server DNS, Server IP, Cluster, and Stage. Grouped by “Stage · Cluster”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Import table …") { chooseFile() }
                    Spacer()
                    Text("CSV · TSV · XLSX")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let importError {
                    Label(importError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            Section("General") {
                KeyboardShortcuts.Recorder("Global hotkey", name: .toggleShuttleX)
                Text("Press this shortcut anywhere to open ShuttleX in the center of the screen; press it again to close. Click the field to record a combination, or clear it to disable.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        toggleLaunchAtLogin(enabled)
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                Toggle("Check for updates on launch", isOn: $state.checkForUpdates)
                Text("When on, ShuttleX checks the public GitHub Releases API (no account, no tracking) at most once a day and shows a hint in the menu. Off by default.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                LabeledContent("Version", value: AppInfo.displayVersion)
            }
        }
        .formStyle(.grouped)
        // Bounded height so the window fits smaller screens (e.g. 14") and the
        // form scrolls instead of growing to its full content height.
        .frame(width: 460, height: 600)
        .sheet(item: $parseResult) { result in
            ImportView(result: result, state: state)
        }
        .sheet(isPresented: $showEditor) {
            ServerEditorView(state: state)
        }
    }

    private func chooseJSONLocation() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.message = "Choose a servers JSON file"
        panel.prompt = "Use"
        if panel.runModal() == .OK, let url = panel.url {
            state.setJSONPath(url)
        }
    }

    private func chooseFile() {
        importError = nil
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        var types: [UTType] = [.commaSeparatedText, .tabSeparatedText, .plainText]
        if let xlsx = UTType(filenameExtension: "xlsx") { types.append(xlsx) }
        panel.allowedContentTypes = types
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            parseResult = try TableImporter.parse(url: url)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Could not change the login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
