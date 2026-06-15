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

@Test func serverEditingUpsertAndDelete() {
    var file = JSONHostStore.File(
        groups: [.init(name: "A", hosts: [.init(name: "h1", host: "old", user: nil, port: nil, command: nil)])],
        hosts: nil
    )

    // Add a new host to a new group.
    file = ServerEditing.upsert(file, group: "B",
                                entry: .init(name: "h2", host: "x", user: nil, port: nil, command: nil),
                                replacing: nil)
    #expect(file.groups?.count == 2)

    // Edit h1: rename, change host, and move it from group A to B.
    file = ServerEditing.upsert(file, group: "B",
                                entry: .init(name: "h1b", host: "new", user: nil, port: nil, command: nil),
                                replacing: (group: "A", name: "h1"))
    #expect(file.groups?.contains { $0.name == "A" } == false) // emptied → removed
    let groupB = file.groups?.first { $0.name == "B" }
    #expect(groupB?.hosts.count == 2)
    #expect(groupB?.hosts.contains { $0.name == "h1b" && $0.host == "new" } == true)

    // Empty group name falls back to "Servers".
    file = ServerEditing.upsert(file, group: "   ",
                                entry: .init(name: "loose", host: "y", user: nil, port: nil, command: nil),
                                replacing: nil)
    #expect(file.groups?.contains { $0.name == "Servers" } == true)

    // Delete.
    file = ServerEditing.delete(file, group: "B", name: "h2")
    #expect(file.groups?.first { $0.name == "B" }?.hosts.count == 1)
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
