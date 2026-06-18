import Foundation
import Testing
@testable import ShuttleX

private func makeTempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sxtest-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

// MARK: - Shell quoting

@Test func shellQuoteWrapsAndEscapes() {
    #expect(Shell.quote("web01") == "'web01'")
    #expect(Shell.quote("a'b") == "'a'\\''b'")
    // A semicolon stays inside the quotes, so it can't be interpreted by a shell.
    #expect(Shell.quote("1.2.3.4; rm -rf ~") == "'1.2.3.4; rm -rf ~'")
}

// MARK: - XLSX column math

@Test func xlsxColumnIndexFromCellRef() {
    #expect(TableImporter.columnIndex(fromCellRef: "A1") == 0)
    #expect(TableImporter.columnIndex(fromCellRef: "B2") == 1)
    #expect(TableImporter.columnIndex(fromCellRef: "Z9") == 25)
    #expect(TableImporter.columnIndex(fromCellRef: "AA1") == 26)
    #expect(TableImporter.columnIndex(fromCellRef: "AB1") == 27)
    #expect(TableImporter.columnIndex(fromCellRef: "BA10") == 52)
}

// MARK: - CSV / TSV parsing

@Test func parsesCRLFAndGroupsByStageCluster() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let csv = dir.appendingPathComponent("s.csv")
    try "User,Server DNS,Server IP,Cluster,Stage\r\nroot,web01,10.0.0.1,web,Prod\r\nroot,db01,10.0.0.2,db,Prod\r\n"
        .write(to: csv, atomically: true, encoding: .utf8)

    let result = try TableImporter.parse(url: csv)
    #expect(result.rows.count == 2)

    let file = TableImporter.buildFile(rows: result.rows, target: .ip)
    #expect(file.groups?.count == 2)
    #expect(file.groups?.contains { $0.name == "Prod · web" } == true)
    #expect(file.groups?.contains { $0.name == "Prod · db" } == true)
}

@Test func detectsSemicolonDelimiter() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let csv = dir.appendingPathComponent("s.csv")
    try "User;Server DNS;Server IP;Cluster;Stage\r\nroot;web01;10.0.0.1;web;Prod\r\n"
        .write(to: csv, atomically: true, encoding: .utf8)

    let result = try TableImporter.parse(url: csv)
    #expect(result.rows.count == 1)
    #expect(result.rows.first?.dns == "web01")
}

@Test func keepsQuotedFieldWithEmbeddedComma() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let csv = dir.appendingPathComponent("s.csv")
    // The quoted cluster value contains a comma that must not split the row.
    try "User,Server DNS,Server IP,Cluster,Stage\r\nroot,web01,10.0.0.1,\"web,edge\",Prod\r\n"
        .write(to: csv, atomically: true, encoding: .utf8)

    let result = try TableImporter.parse(url: csv)
    #expect(result.rows.count == 1)
    #expect(result.rows.first?.cluster == "web,edge")
}

@Test func usesPositionalColumnsWithoutHeader() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let csv = dir.appendingPathComponent("s.csv")
    try "svc,host01,10.0.0.9,clusterA,Staging\n".write(to: csv, atomically: true, encoding: .utf8)

    let result = try TableImporter.parse(url: csv)
    #expect(result.mapping.hasHeader == false)
    #expect(result.rows.count == 1)
    #expect(result.rows.first?.user == "svc")
    #expect(result.rows.first?.ip == "10.0.0.9")
}

// MARK: - Security: import validation + shell quoting

@Test func skipsRowsWithUnsafeCharacters() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let csv = dir.appendingPathComponent("evil.csv")
    try "User,Server DNS,Server IP,Cluster,Stage\r\nroot,box,1.2.3.4; rm -rf ~,web,Prod\r\ndeploy,web01,10.0.0.1,web,Prod\r\n"
        .write(to: csv, atomically: true, encoding: .utf8)

    let result = try TableImporter.parse(url: csv)
    #expect(result.rows.count == 1)
    #expect(result.skipped == 1)
    #expect(result.rows.first?.dns == "web01")
}

@Test func buildsShellQuotedSSHCommand() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("servers.json")
    let file = JSONHostStore.File(
        groups: [.init(name: "g", hosts: [
            .init(name: "x", host: "1.2.3.4; touch /tmp/x", user: "root", port: nil, command: nil),
        ])],
        hosts: nil
    )
    try JSONHostStore.write(file, to: url)
    let groups = try JSONHostStore.load(from: url)
    #expect(groups.first?.hosts.first?.command == "ssh 'root@1.2.3.4; touch /tmp/x'")
}

@Test func jsonBuildsRemoteCommandWithTTY() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("servers.json")
    let file = JSONHostStore.File(
        groups: [.init(name: "g", hosts: [
            .init(name: "htop", host: "web01", user: "deploy", port: nil, command: nil, remoteCommand: "htop"),
            .init(name: "tail", host: "h", user: "u", port: 2222, command: nil, remoteCommand: "tail -f /var/log/x"),
            .init(name: "shell", host: "web01", user: "deploy", port: nil, command: nil, remoteCommand: nil),
        ])],
        hosts: nil
    )
    try JSONHostStore.write(file, to: url)
    let hosts = try JSONHostStore.load(from: url).first!.hosts
    #expect(hosts[0].command == "ssh -t 'deploy@web01' 'htop'")
    #expect(hosts[1].command == "ssh -t -p 2222 'u@h' 'tail -f /var/log/x'")
    #expect(hosts[2].command == "ssh 'deploy@web01'") // no remote command → plain connect
}

@Test func favoritesPersistAndToggle() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("servers.json")
    let file = JSONHostStore.File(
        groups: [.init(name: "g", hosts: [
            .init(name: "a", host: "a", user: nil, port: nil, command: nil, remoteCommand: nil, favorite: true),
            .init(name: "b", host: "b", user: nil, port: nil, command: nil),
        ])],
        hosts: nil
    )
    try JSONHostStore.write(file, to: url)

    // favorite flag survives a write/load round trip; the clean JSON only stores `true`.
    let hosts = try JSONHostStore.load(from: url).first!.hosts
    #expect(hosts.first { $0.name == "a" }?.favorite == true)
    #expect(hosts.first { $0.name == "b" }?.favorite == false)
    let raw = try String(contentsOf: url, encoding: .utf8)
    #expect(raw.contains("\"favorite\""))
    #expect(!raw.contains("false"))

    // Toggling flips a off and b on (matched by built command + name).
    var toggled = JSONHostStore.togglingFavorite(in: JSONHostStore.loadFile(from: url), host: hosts.first { $0.name == "a" }!)
    toggled = JSONHostStore.togglingFavorite(in: toggled, host: hosts.first { $0.name == "b" }!)
    try JSONHostStore.write(toggled, to: url, snapshot: false)
    let after = try JSONHostStore.load(from: url).first!.hosts
    #expect(after.first { $0.name == "a" }?.favorite == false)
    #expect(after.first { $0.name == "b" }?.favorite == true)
}

// MARK: - Search filtering

@Test func searchMatchesGroupNameOrHost() {
    let groups = [
        HostGroup(name: "Prod · web", hosts: [
            SSHHost(name: "alpha", detail: "root@10.0.0.1", command: "ssh '10.0.0.1'"),
            SSHHost(name: "beta", detail: "root@10.0.0.2", command: "ssh '10.0.0.2'"),
        ]),
        HostGroup(name: "Prod · db", hosts: [
            SSHHost(name: "web-db", detail: "root@10.0.0.3", command: "ssh '10.0.0.3'"),
            SSHHost(name: "cache", detail: "root@10.0.0.4", command: "ssh '10.0.0.4'"),
        ]),
    ]

    // "web" matches the group "Prod · web" (whole group) and the host "web-db" in the db group.
    let result = HostFiltering.filter(groups, query: "web")
    #expect(result.count == 2)
    #expect(result.first { $0.name == "Prod · web" }?.hosts.count == 2)
    #expect(result.first { $0.name == "Prod · db" }?.hosts.count == 1)

    // Empty query returns everything unchanged.
    #expect(HostFiltering.filter(groups, query: "  ").count == 2)

    // A host-only match keeps just that host.
    let alpha = HostFiltering.filter(groups, query: "alpha")
    #expect(alpha.count == 1)
    #expect(alpha.first?.hosts.count == 1)
}

// MARK: - Host field validation

@Test func hostValidationRejectsShellMetacharacters() {
    #expect(HostValidation.isSafe("web01.prod.example.com"))
    #expect(HostValidation.isSafe("10.0.0.1"))
    #expect(HostValidation.isSafe("deploy"))
    #expect(!HostValidation.isSafe("1.2.3.4; rm -rf ~"))
    #expect(!HostValidation.isSafe("a b"))
    #expect(!HostValidation.isSafe("$(reboot)"))
}

// MARK: - Server editing (add / edit / delete)

@Test func serverEditingAddUpdateDelete() {
    var file = JSONHostStore.File(
        groups: [.init(name: "A", hosts: [.init(name: "h1", host: "old", user: nil, port: nil, command: nil)])],
        hosts: nil
    )
    let h1id = file.groups![0].hosts[0].id

    // Add a new host to a new group.
    file = ServerEditing.add(file, group: "B", entry: .init(name: "h2", host: "x", user: nil, port: nil, command: nil))
    #expect(file.groups?.count == 2)

    // Update h1 in place (rename + host), staying in A.
    file = ServerEditing.update(file, group: "A", id: h1id,
                                to: .init(name: "h1b", host: "new", user: nil, port: nil, command: nil),
                                newGroup: "A")
    #expect(file.groups?.first { $0.name == "A" }?.hosts.first?.name == "h1b")
    #expect(file.groups?.first { $0.name == "A" }?.hosts.first?.host == "new")

    // Move it from A to B; A is emptied and removed.
    let h1bid = file.groups!.first { $0.name == "A" }!.hosts[0].id
    file = ServerEditing.update(file, group: "A", id: h1bid,
                                to: .init(name: "h1b", host: "new", user: nil, port: nil, command: nil),
                                newGroup: "B")
    #expect(file.groups?.contains { $0.name == "A" } == false)
    #expect(file.groups?.first { $0.name == "B" }?.hosts.count == 2)

    // Empty group name falls back to "Servers".
    file = ServerEditing.add(file, group: "   ", entry: .init(name: "loose", host: "y", user: nil, port: nil, command: nil))
    #expect(file.groups?.contains { $0.name == "Servers" } == true)
}

@Test func serverEditingHandlesDuplicateNames() {
    // Two entries with the SAME name but different hosts (the AdGuard case).
    var file = JSONHostStore.File(
        groups: [.init(name: "DNS", hosts: [
            .init(name: "AdGuard", host: "10.0.0.1", user: nil, port: nil, command: nil),
            .init(name: "AdGuard", host: "10.0.0.2", user: nil, port: nil, command: nil),
        ])],
        hosts: nil
    )
    let firstID = file.groups![0].hosts[0].id

    // Deleting by id removes ONLY that one, not both.
    file = ServerEditing.delete(file, group: "DNS", id: firstID)
    let remaining = file.groups!.first { $0.name == "DNS" }!.hosts
    #expect(remaining.count == 1)
    #expect(remaining.first?.host == "10.0.0.2") // the other one survives
}

// MARK: - SSH config parsing

@Test func sshConfigParsesHostsAndIgnoresWildcards() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let cfg = dir.appendingPathComponent("config")
    try "Host web\n  HostName web.example.com\n  User deploy\n\nHost *\n  ForwardAgent yes\n"
        .write(to: cfg, atomically: true, encoding: .utf8)

    let hosts = try SSHConfigParser.parse(at: cfg)
    #expect(hosts.count == 1)
    #expect(hosts.first?.name == "web")
    #expect(hosts.first?.command == "ssh 'web'")
}

@Test func sshConfigMissingFileReturnsEmptyWithoutThrowing() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    #expect(try SSHConfigParser.parse(at: dir.appendingPathComponent("nope")).isEmpty)
}

@Test func sshConfigUnreadableFileThrows() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let cfg = dir.appendingPathComponent("config")
    try "Host x\n  HostName x\n".write(to: cfg, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: cfg.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: cfg.path) }
    #expect(throws: (any Error).self) { try SSHConfigParser.parse(at: cfg) }
}

@Test func sshConfigIgnoresInlineCommentInHostLine() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let cfg = dir.appendingPathComponent("config")
    try "Host web # production box\n  HostName web.example.com\n"
        .write(to: cfg, atomically: true, encoding: .utf8)
    let hosts = try SSHConfigParser.parse(at: cfg)
    #expect(hosts.count == 1)
    #expect(hosts.first?.name == "web")
}

// MARK: - AppleScript escaping

@Test func appleScriptEscapingHandlesQuotesBackslashesAndControlChars() {
    #expect(TerminalLauncher.appleScriptEscaped("ssh 'user@host'") == "ssh 'user@host'")
    #expect(TerminalLauncher.appleScriptEscaped("a\"b") == "a\\\"b")
    #expect(TerminalLauncher.appleScriptEscaped("a\\b") == "a\\\\b")
    #expect(TerminalLauncher.appleScriptEscaped("a\nb") == "a\\nb")
    #expect(TerminalLauncher.appleScriptEscaped("a\tb") == "a\\tb")
    #expect(TerminalLauncher.appleScriptEscaped("a\r\nb") == "a\\r\\nb")
    // A backslash already present must not double-escape the control-char escapes.
    #expect(TerminalLauncher.appleScriptEscaped("x\\\ny") == "x\\\\\\ny")
}

@Test func serverEditingMovesWithinGroup() {
    var file = JSONHostStore.File(
        groups: [.init(name: "A", hosts: [
            .init(name: "a", host: "1", user: nil, port: nil, command: nil),
            .init(name: "b", host: "2", user: nil, port: nil, command: nil),
            .init(name: "c", host: "3", user: nil, port: nil, command: nil),
        ])],
        hosts: nil
    )
    func order() -> [String] { file.groups?.first?.hosts.map(\.name) ?? [] }

    // Move "c" (index 2) to the front.
    file = ServerEditing.move(file, group: "A", fromOffsets: IndexSet(integer: 2), toOffset: 0)
    #expect(order() == ["c", "a", "b"])
    // Move "c" (index 0) back down past "a".
    file = ServerEditing.move(file, group: "A", fromOffsets: IndexSet(integer: 0), toOffset: 2)
    #expect(order() == ["a", "c", "b"])
}

// MARK: - Launch mode resolution

@Test func launchModeFallsBackToWindowWhenNotRunning() {
    // Not running → always a new window, even when tab/split is requested.
    #expect(TerminalLauncher.effectiveMode(requested: .splitRight, supported: LaunchMode.allCases, isRunning: false) == .newWindow)
    #expect(TerminalLauncher.effectiveMode(requested: .newTab, supported: [.newWindow, .newTab], isRunning: false) == .newWindow)
    // Running → the requested mode is honored when supported.
    #expect(TerminalLauncher.effectiveMode(requested: .splitRight, supported: LaunchMode.allCases, isRunning: true) == .splitRight)
    #expect(TerminalLauncher.effectiveMode(requested: .newTab, supported: [.newWindow, .newTab], isRunning: true) == .newTab)
    // Running but the requested mode isn't supported → new window.
    #expect(TerminalLauncher.effectiveMode(requested: .splitRight, supported: [.newWindow], isRunning: true) == .newWindow)
}

// MARK: - Update check

@Test func updateCheckComparesVersionsNumerically() {
    #expect(UpdateCheck.isNewer("1.7.0", than: "1.6.4"))
    #expect(UpdateCheck.isNewer("v1.7.0", than: "1.6.4"))   // leading "v" tolerated
    #expect(UpdateCheck.isNewer("1.6.10", than: "1.6.9"))   // numeric, not lexical
    #expect(UpdateCheck.isNewer("2.0.0", than: "1.9.9"))
    #expect(!UpdateCheck.isNewer("1.6.4", than: "1.6.4"))   // equal → not newer
    #expect(!UpdateCheck.isNewer("1.6.3", than: "1.6.4"))   // older
    #expect(!UpdateCheck.isNewer("1.6", than: "1.6.0"))     // missing component counts as 0
}

// MARK: - JSON merge

@Test func mergeUpdatesMatchingAndAppendsNew() {
    let existing = JSONHostStore.File(
        groups: [.init(name: "A", hosts: [.init(name: "h1", host: "old", user: nil, port: nil, command: nil)])],
        hosts: nil
    )
    let incoming = JSONHostStore.File(
        groups: [
            .init(name: "A", hosts: [
                .init(name: "h1", host: "new", user: nil, port: nil, command: nil),
                .init(name: "h2", host: "x", user: nil, port: nil, command: nil),
            ]),
            .init(name: "B", hosts: [.init(name: "h3", host: "y", user: nil, port: nil, command: nil)]),
        ],
        hosts: nil
    )

    let merged = JSONHostStore.merge(incoming, into: existing)
    let groupA = merged.groups?.first { $0.name == "A" }
    #expect(groupA?.hosts.count == 2)
    #expect(groupA?.hosts.first { $0.name == "h1" }?.host == "new")
    #expect(merged.groups?.contains { $0.name == "B" } == true)
}

// MARK: - JSON load

@Test func jsonLoadMergesGroupsWithTheSameName() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("servers.json")
    try #"""
    {"groups":[
      {"name":"Prod","hosts":[{"name":"a","host":"a.example.com"}]},
      {"name":"Prod","hosts":[{"name":"b","host":"b.example.com"}]}
    ]}
    """#.write(to: url, atomically: true, encoding: .utf8)

    let groups = try JSONHostStore.load(from: url)
    #expect(groups.count == 1)
    #expect(groups.first?.name == "Prod")
    #expect(groups.first?.hosts.count == 2)
}

// MARK: - Backup rotation

@Test func backupRotationKeepsLastThreeAndDedups() throws {
    let dir = makeTempDir(); defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("servers.json")
    func set(_ value: String) throws { try value.data(using: .utf8)!.write(to: url) }

    for value in ["A", "B", "C", "D"] {
        try set(value)
        JSONHostStore.snapshotIfChanged(url)
        Thread.sleep(forTimeInterval: 0.005)
    }

    let backups = JSONHostStore.backups(in: dir, base: "servers", ext: "json")
    #expect(backups.count == 3)
    let contents = backups.compactMap { try? String(contentsOf: $0, encoding: .utf8) }
    #expect(contents == ["D", "C", "B"])

    // Re-saving identical content does not create another backup.
    try set("D")
    JSONHostStore.snapshotIfChanged(url)
    #expect(JSONHostStore.backups(in: dir, base: "servers", ext: "json").count == 3)
}
