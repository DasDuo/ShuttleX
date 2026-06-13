import SwiftUI

struct ImportView: View {
    let result: TableImporter.ParseResult
    let state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var target: TableImporter.ConnectTarget = .dns
    @State private var mode: TableImporter.ImportMode = .merge
    @State private var importError: String?

    private var previewFile: JSONHostStore.File {
        TableImporter.buildFile(rows: result.rows, target: target)
    }

    private var groupCount: Int { previewFile.groups?.count ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                Section("Erkannt") {
                    LabeledContent("Datei", value: result.fileName)
                    LabeledContent("Server", value: "\(result.rows.count)")
                    LabeledContent("Gruppen", value: "\(groupCount)")
                    if !result.mapping.hasHeader {
                        Text("Keine Kopfzeile erkannt – Spalten in fester Reihenfolge gelesen: User, Server DNS, Server IP, Cluster, Stage.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Optionen") {
                    Picker("Verbinden über", selection: $target) {
                        ForEach(TableImporter.ConnectTarget.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Modus", selection: $mode) {
                        ForEach(TableImporter.ImportMode.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(mode == .merge
                        ? "Bestehende Einträge mit gleichem Namen werden aktualisiert, neue ergänzt, der Rest bleibt erhalten."
                        : "Die JSON-Datei wird komplett durch diesen Import ersetzt.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Vorschau") {
                    previewList
                }
            }
            .formStyle(.grouped)

            Divider()
            footer
        }
        .frame(width: 480, height: 560)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 18))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tabelle importieren")
                    .font(.headline)
                Text("Server aus einer CSV/Excel-Tabelle übernehmen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private var previewList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(previewFile.groups ?? [], id: \.name) { group in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(group.hosts.enumerated()), id: \.offset) { _, entry in
                            HStack(spacing: 6) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                Text(entry.name).font(.system(size: 12, weight: .medium))
                                Text(connectionLabel(entry))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
        .frame(height: 180)
    }

    private func connectionLabel(_ entry: JSONHostStore.Entry) -> String {
        let host = entry.host ?? ""
        if let user = entry.user { return "\(user)@\(host)" }
        return host
    }

    private var footer: some View {
        HStack {
            Button("Abbrechen", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            if let importError {
                Label(importError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
            Spacer()
            Button("Importieren") { runImport() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func runImport() {
        let incoming = previewFile
        let url = JSONHostStore.defaultURL
        let fileToWrite: JSONHostStore.File
        switch mode {
        case .replace:
            fileToWrite = incoming
        case .merge:
            fileToWrite = JSONHostStore.merge(incoming, into: JSONHostStore.loadFile(from: url))
        }
        do {
            try JSONHostStore.write(fileToWrite, to: url)
            // Nach dem Import die JSON-Quelle aktivieren, damit das Ergebnis sichtbar ist.
            state.source = .json
            state.reload()
            dismiss()
        } catch {
            importError = "Schreiben fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
