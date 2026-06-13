import SwiftUI

struct MenuView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings

    @State private var query = ""
    @State private var listContentHeight: CGFloat = 0
    @State private var expandedGroups: Set<String> = []
    @FocusState private var searchFocused: Bool

    private var filteredGroups: [HostGroup] {
        guard !query.isEmpty else { return state.groups }
        let needle = query.lowercased()
        return state.groups.compactMap { group in
            let hosts = group.hosts.filter {
                $0.name.lowercased().contains(needle)
                    || ($0.detail?.lowercased().contains(needle) ?? false)
                    || $0.command.lowercased().contains(needle)
            }
            return hosts.isEmpty ? nil : HostGroup(name: group.name, hosts: hosts)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()
            content
            if let error = state.lastError {
                errorBanner(error)
            }
            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear {
            state.reload()
            searchFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ShuttleShape()
                .fill(.white)
                .frame(width: 13, height: 13)
                .frame(width: 24, height: 24)
                .background(
                    LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 6)
                )
            Text("ShuttleX")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(state.source.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.6), in: Capsule())
            Button {
                state.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload")
            Button {
                dismissMenuWindow()
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search servers …", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit(connectToFirstMatch)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        if filteredGroups.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredGroups) { group in
                        GroupHeader(
                            name: group.name,
                            count: group.hosts.count,
                            expanded: isExpanded(group)
                        ) {
                            toggle(group)
                        }
                        if isExpanded(group) {
                            ForEach(group.hosts) { host in
                                HostRow(host: host) {
                                    connect(host)
                                }
                                .padding(.leading, 12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    listContentHeight = height
                }
            }
            // The MenuBarExtra window doesn't measure ScrollView content reliably,
            // so the measured content height is set explicitly (capped at 380).
            .frame(height: listContentHeight > 0 ? min(listContentHeight, 380) : nil)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(query.isEmpty ? "No servers found" : "No matches for “\(query)”")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            if query.isEmpty {
                Text(state.source == .sshConfig
                    ? "Add hosts to ~/.ssh/config."
                    : "Edit the JSON file in Settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        @Bindable var state = state
        return HStack {
            Picker(selection: $state.terminal) {
                ForEach(TerminalApp.installed) { app in
                    Text(app.displayName).tag(app)
                }
            } label: {
                Image(systemName: "apps.iphone")
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .font(.system(size: 12))
            .fixedSize()
            .help("Terminal app for new connections")
            if state.terminal.supportedModes.count > 1 {
                Picker(selection: Binding(
                    get: { state.effectiveLaunchMode },
                    set: { state.launchMode = $0 }
                )) {
                    ForEach(state.terminal.supportedModes) { mode in
                        Label(mode.label, systemImage: mode.systemImage).tag(mode)
                    }
                } label: {
                    Image(systemName: state.effectiveLaunchMode.systemImage)
                }
                .pickerStyle(.menu)
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .fixedSize()
                .help("Open in: \(state.effectiveLaunchMode.label)")
            }
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit ShuttleX")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func connect(_ host: SSHHost) {
        dismissMenuWindow()
        state.connect(host)
    }

    private func connectToFirstMatch() {
        if let first = filteredGroups.first?.hosts.first {
            connect(first)
        }
    }

    // MARK: - Expand/collapse groups

    /// Always expanded while searching and when there's only one group;
    /// collapsed by default otherwise.
    private func isExpanded(_ group: HostGroup) -> Bool {
        if !query.isEmpty { return true }
        if filteredGroups.count == 1 { return true }
        return expandedGroups.contains(group.name)
    }

    private func toggle(_ group: HostGroup) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if expandedGroups.contains(group.name) {
                expandedGroups.remove(group.name)
            } else {
                expandedGroups.insert(group.name)
            }
        }
    }

    private func dismissMenuWindow() {
        for window in NSApp.windows where window.className.contains("MenuBarExtra") {
            window.close()
        }
    }
}

// MARK: - Group header

private struct GroupHeader: View {
    let name: String
    let count: Int
    let expanded: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 12)
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary.opacity(0.6), in: Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(hovered ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(.clear))
        )
        .onHover { hovered = $0 }
    }
}

// MARK: - Row

private struct HostRow: View {
    let host: SSHHost
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 12))
                    .foregroundStyle(hovered ? .primary : .secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(host.name)
                        .font(.system(size: 13, weight: .medium))
                    if let detail = host.detail, detail != host.name {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if hovered {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(hovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .onHover { hovered = $0 }
    }
}
