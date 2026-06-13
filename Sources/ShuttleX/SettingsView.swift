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
                Picker("Terminal-App", selection: $state.terminal) {
                    ForEach(TerminalApp.installed) { app in
                        Text(app.displayName).tag(app)
                    }
                }
                Picker("Öffnen in", selection: Binding(
                    get: { state.effectiveLaunchMode },
                    set: { state.launchMode = $0 }
                )) {
                    ForEach(state.terminal.supportedModes) { mode in
                        Label(mode.label, systemImage: mode.systemImage).tag(mode)
                    }
                }
                if state.terminal.supportedModes == [.newWindow] {
                    Text("\(state.terminal.displayName) lässt sich von außen nur mit neuen Fenstern starten.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if state.terminal == .terminal, state.effectiveLaunchMode == .newTab {
                    Text("Für neue Tabs in Terminal.app braucht ShuttleX die Berechtigung unter Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if state.terminal == .terminal || state.terminal == .iterm2 {
                    Text("Beim ersten Verbinden fragt macOS einmalig nach der Berechtigung, \(state.terminal.displayName) zu steuern.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Server-Quelle") {
                Picker("Quelle", selection: $state.source) {
                    ForEach(HostSource.allCases) { source in
                        Text(source.label).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                switch state.source {
                case .sshConfig:
                    LabeledContent("Datei", value: "~/.ssh/config")
                    LabeledContent("Gefundene Hosts", value: "\(state.hostCount)")
                case .json:
                    LabeledContent("Datei", value: "~/.config/shuttlex/servers.json")
                    LabeledContent("Gefundene Hosts", value: "\(state.hostCount)")
                    HStack {
                        Button("Datei bearbeiten") {
                            JSONHostStore.createSampleIfMissing(at: JSONHostStore.defaultURL)
                            NSWorkspace.shared.open(JSONHostStore.defaultURL)
                        }
                        Button("Im Finder zeigen") {
                            NSWorkspace.shared.activateFileViewerSelecting([JSONHostStore.defaultURL])
                        }
                        Spacer()
                        Button("Neu laden") {
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

            Section("Tabellen-Import") {
                Text("Erzeugt das JSON aus einer Tabelle mit den Spalten User, Server DNS, Server IP, Cluster und Stage. Gruppiert wird nach „Stage · Cluster“.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Tabelle importieren …") { chooseFile() }
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

            Section("Allgemein") {
                Toggle("Beim Anmelden starten", isOn: $launchAtLogin)
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
            loginItemError = "Konnte Login-Objekt nicht ändern: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
