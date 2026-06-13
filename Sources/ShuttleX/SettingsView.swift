import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @State private var parseResult: TableImporter.ParseResult?
    @State private var importError: String?

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
                    LabeledContent("File", value: "~/.config/shuttlex/servers.json")
                    LabeledContent("Hosts found", value: "\(state.hostCount)")
                    HStack {
                        Button("Edit file") {
                            JSONHostStore.createSampleIfMissing(at: JSONHostStore.defaultURL)
                            NSWorkspace.shared.open(JSONHostStore.defaultURL)
                        }
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([JSONHostStore.defaultURL])
                        }
                        Spacer()
                        Button("Reload") {
                            state.reload()
                        }
                    }
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
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        toggleLaunchAtLogin(enabled)
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .sheet(item: $parseResult) { result in
            ImportView(result: result, state: state)
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
