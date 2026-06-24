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

    /// Cap how many rows the preview renders — a big import (e.g. 1000 servers)
    /// would otherwise build that many row views eagerly on every option change.
    private let previewLimit = 50

    private var totalServers: Int {
        (previewFile.groups ?? []).reduce(0) { $0 + $1.hosts.count }
    }

    /// Groups trimmed to the first `previewLimit` servers overall (group order kept).
    private var previewGroups: [(name: String, hosts: [JSONHostStore.Entry])] {
        var remaining = previewLimit
        var result: [(name: String, hosts: [JSONHostStore.Entry])] = []
        for group in previewFile.groups ?? [] where remaining > 0 {
            let shown = Array(group.hosts.prefix(remaining))
            result.append((group.name, shown))
            remaining -= shown.count
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                Section("Detected") {
                    LabeledContent("File", value: result.fileName)
                    LabeledContent("Servers", value: "\(result.rows.count)")
                    LabeledContent("Groups", value: "\(groupCount)")
                    if result.skipped > 0 {
                        Label("\(result.skipped) row(s) skipped — unsafe characters in server fields.",
                              systemImage: "exclamationmark.shield.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                    if !result.mapping.hasHeader {
                        Text("No header detected – columns read in fixed order: User, Server DNS, Server IP, Cluster, Stage.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Options") {
                    Picker("Connect via", selection: $target) {
                        ForEach(TableImporter.ConnectTarget.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Mode", selection: $mode) {
                        ForEach(TableImporter.ImportMode.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(mode == .merge
                        ? "Existing entries with the same name are updated, new ones added, the rest kept."
                        : "The JSON file is completely replaced by this import.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Preview") {
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
                Text("Import table")
                    .font(.headline)
                Text("Import servers from a CSV/Excel spreadsheet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    @ViewBuilder
    private var previewList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(previewGroups, id: \.name) { group in
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

            if totalServers > previewLimit {
                Text("Showing \(previewLimit) of \(totalServers) servers — all will be imported.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func connectionLabel(_ entry: JSONHostStore.Entry) -> String {
        let host = entry.host ?? ""
        if let user = entry.user { return "\(user)@\(host)" }
        return host
    }

    private var footer: some View {
        HStack {
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            if let importError {
                Label(importError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
            Spacer()
            Button("Import") { runImport() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func runImport() {
        let incoming = previewFile
        let url = state.jsonURL
        let fileToWrite: JSONHostStore.File
        switch mode {
        case .replace:
            fileToWrite = incoming
        case .merge:
            fileToWrite = JSONHostStore.merge(incoming, into: JSONHostStore.loadFile(from: url))
        }
        do {
            try JSONHostStore.write(fileToWrite, to: url)
            // Activate the JSON source after import so the result is visible.
            state.source = .json
            state.reload()
            dismiss()
        } catch {
            importError = "Write failed: \(error.localizedDescription)"
        }
    }
}
