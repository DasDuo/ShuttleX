import Foundation

/// Reads spreadsheets (CSV, TSV, Excel .xlsx) with the columns
/// User, Server DNS, Server IP, Cluster, Stage and builds the ShuttleX JSON.
enum TableImporter {
    enum ConnectTarget: String, CaseIterable, Identifiable {
        case dns, ip
        var id: String { rawValue }
        var label: String { self == .dns ? "DNS name" : "IP address" }
    }

    enum ImportMode: String, CaseIterable, Identifiable {
        case merge, replace
        var id: String { rawValue }
        var label: String { self == .merge ? "Merge" : "Replace" }
    }

    enum ImportError: LocalizedError {
        case unsupported(String)
        case unreadable(String)
        case noRows

        var errorDescription: String? {
            switch self {
            case .unsupported(let ext): return "Format “.\(ext)” is not supported (CSV, TSV, or XLSX)."
            case .unreadable(let reason): return reason
            case .noRows: return "No servers found in the spreadsheet."
            }
        }
    }

    struct Row {
        var user = "", dns = "", ip = "", cluster = "", stage = ""
        var hasTarget: Bool { !dns.isEmpty || !ip.isEmpty }
    }

    struct ColumnMapping {
        var user: Int?, dns: Int?, ip: Int?, cluster: Int?, stage: Int?
        var hasHeader = false
    }

    struct ParseResult: Identifiable {
        let id = UUID()
        var rows: [Row]
        var mapping: ColumnMapping
        var fileName: String
    }

    // MARK: - Reading

    static func parse(url: URL) throws -> ParseResult {
        let ext = url.pathExtension.lowercased()
        let grid: [[String]]
        switch ext {
        case "csv", "tsv", "txt":
            let text: String
            if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                text = utf8
            } else if let latin = try? String(contentsOf: url, encoding: .isoLatin1) {
                text = latin
            } else {
                throw ImportError.unreadable("Could not read the file.")
            }
            // Normalize line endings: Swift otherwise treats "\r\n" as a single
            // Character grapheme, so no line would break.
            let normalized = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            let delimiter: Character = ext == "tsv" ? "\t" : detectDelimiter(normalized)
            grid = parseDelimited(normalized, delimiter: delimiter)
        case "xlsx":
            grid = try readXLSX(url)
        default:
            throw ImportError.unsupported(ext)
        }

        let mapping = detectColumns(in: grid)
        let dataRows = mapping.hasHeader ? Array(grid.dropFirst()) : grid
        let rows = dataRows.compactMap { cols -> Row? in
            func value(_ index: Int?) -> String {
                guard let index, index >= 0, index < cols.count else { return "" }
                return cols[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let row = Row(user: value(mapping.user), dns: value(mapping.dns),
                          ip: value(mapping.ip), cluster: value(mapping.cluster),
                          stage: value(mapping.stage))
            return row.hasTarget ? row : nil
        }
        guard !rows.isEmpty else { throw ImportError.noRows }
        return ParseResult(rows: rows, mapping: mapping, fileName: url.lastPathComponent)
    }

    // MARK: - JSON construction

    static func buildFile(rows: [Row], target: ConnectTarget) -> JSONHostStore.File {
        var order: [String] = []
        var byGroup: [String: [JSONHostStore.Entry]] = [:]

        for row in rows {
            let host = connectHost(row, target: target)
            guard !host.isEmpty else { continue }
            let group = groupName(stage: row.stage, cluster: row.cluster)
            let entry = JSONHostStore.Entry(
                name: displayName(row),
                host: host,
                user: row.user.isEmpty ? nil : row.user,
                port: nil,
                command: nil
            )
            if byGroup[group] == nil {
                byGroup[group] = []
                order.append(group)
            }
            byGroup[group]?.append(entry)
        }

        let groups = order.map { JSONHostStore.Group(name: $0, hosts: byGroup[$0] ?? []) }
        return JSONHostStore.File(groups: groups, hosts: nil)
    }

    /// Group name "Stage · Cluster" (empty parts are omitted).
    private static func groupName(stage: String, cluster: String) -> String {
        let parts = [stage, cluster].filter { !$0.isEmpty }
        return parts.isEmpty ? "Servers" : parts.joined(separator: " · ")
    }

    private static func connectHost(_ row: Row, target: ConnectTarget) -> String {
        switch target {
        case .dns: return row.dns.isEmpty ? row.ip : row.dns
        case .ip: return row.ip.isEmpty ? row.dns : row.ip
        }
    }

    /// Display name = value of the name/DNS column (verbatim), otherwise the IP.
    private static func displayName(_ row: Row) -> String {
        row.dns.isEmpty ? row.ip : row.dns
    }

    // MARK: - Column detection

    private static func detectColumns(in grid: [[String]]) -> ColumnMapping {
        guard let header = grid.first else { return ColumnMapping() }
        let normalized = header.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        func find(_ keywords: [String]) -> Int? {
            normalized.firstIndex { cell in keywords.contains { cell.contains($0) } }
        }

        var mapping = ColumnMapping()
        mapping.user = find(["user", "benutzer", "login", "account"])
        mapping.dns = find(["dns", "fqdn", "hostname", "host name", "servername", "server name", "name", "domain", "host"])
        mapping.ip = find(["ip", "ipv4", "adresse", "address"])
        mapping.cluster = find(["cluster"])
        mapping.stage = find(["stage", "umgebung", "environment", "env"])
        // Only treat as a header from two matches on – a single coincidental
        // value like "clusterA" shouldn't swallow a whole data row.
        let matches = [mapping.user, mapping.dns, mapping.ip,
                       mapping.cluster, mapping.stage].compactMap { $0 }.count
        mapping.hasHeader = matches >= 2

        // No recognizable header: fixed order as specified.
        if !mapping.hasHeader {
            let width = grid.first?.count ?? 0
            mapping.user = width > 0 ? 0 : nil
            mapping.dns = width > 1 ? 1 : nil
            mapping.ip = width > 2 ? 2 : nil
            mapping.cluster = width > 3 ? 3 : nil
            mapping.stage = width > 4 ? 4 : nil
        }
        return mapping
    }

    // MARK: - CSV/TSV

    private static func detectDelimiter(_ text: String) -> Character {
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        let candidates: [(Character, Int)] = [
            (",", firstLine.filter { $0 == "," }.count),
            (";", firstLine.filter { $0 == ";" }.count),
            ("\t", firstLine.filter { $0 == "\t" }.count),
        ]
        return candidates.max { $0.1 < $1.1 }?.0 ?? ","
    }

    private static func parseDelimited(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\""); i += 2; continue
                    }
                    inQuotes = false
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == delimiter {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                row.append(field); field = ""
                rows.append(row); row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        // Drop empty lines.
        return rows.filter { cols in
            !(cols.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        }
    }

    // MARK: - XLSX (unzip + read XML, without third-party libraries)

    private static func readXLSX(_ url: URL) throws -> [[String]] {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("shuttlex-xlsx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", url.path, "-d", tmp.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ImportError.unreadable("Could not unzip the Excel file.")
        }
        guard process.terminationStatus == 0 else {
            throw ImportError.unreadable("Could not unzip the Excel file.")
        }

        let sharedStrings = (try? String(contentsOf: tmp.appendingPathComponent("xl/sharedStrings.xml"), encoding: .utf8))
            .map(parseSharedStrings) ?? []

        guard let sheetURL = firstWorksheet(in: tmp),
              let sheetXML = try? String(contentsOf: sheetURL, encoding: .utf8) else {
            throw ImportError.unreadable("Worksheet not found.")
        }
        return parseSheet(sheetXML, sharedStrings: sharedStrings)
    }

    private static func firstWorksheet(in directory: URL) -> URL? {
        let primary = directory.appendingPathComponent("xl/worksheets/sheet1.xml")
        if FileManager.default.fileExists(atPath: primary.path) { return primary }
        let worksheets = directory.appendingPathComponent("xl/worksheets")
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: worksheets.path)) ?? []
        guard let first = entries.filter({ $0.hasSuffix(".xml") }).sorted().first else { return nil }
        return worksheets.appendingPathComponent(first)
    }

    private static func parseSharedStrings(_ xml: String) -> [String] {
        let delegate = SharedStringsParser()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    private static func parseSheet(_ xml: String, sharedStrings: [String]) -> [[String]] {
        let delegate = SheetParser(sharedStrings: sharedStrings)
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    static func columnIndex(fromCellRef ref: String) -> Int {
        var index = 0
        for char in ref {
            guard char.isLetter else { break }
            let value = Int(char.uppercased().unicodeScalars.first!.value) - 64
            index = index * 26 + value
        }
        return max(0, index - 1)
    }
}

// MARK: - XMLParser delegates

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var insideItem = false
    private var insideText = false

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        if name == "si" { insideItem = true; current = "" }
        if name == "t" { insideText = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideItem, insideText { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        if name == "t" { insideText = false }
        if name == "si" { strings.append(current); insideItem = false }
    }
}

private final class SheetParser: NSObject, XMLParserDelegate {
    var rows: [[String]] = []
    private let sharedStrings: [String]
    private var cells: [(col: Int, value: String)] = []
    private var cellType = ""
    private var cellColumn = 0
    private var valueBuffer = ""
    private var textBuffer = ""
    private var insideValue = false
    private var insideText = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        switch name {
        case "row":
            cells = []
        case "c":
            cellType = attributes["t"] ?? ""
            cellColumn = TableImporter.columnIndex(fromCellRef: attributes["r"] ?? "")
            valueBuffer = ""
            textBuffer = ""
        case "v":
            insideValue = true
        case "t":
            insideText = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideValue { valueBuffer += string }
        if insideText { textBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch name {
        case "v":
            insideValue = false
        case "t":
            insideText = false
        case "c":
            let value: String
            if cellType == "s", let index = Int(valueBuffer), index < sharedStrings.count {
                value = sharedStrings[index]
            } else if cellType == "inlineStr" {
                value = textBuffer
            } else {
                value = valueBuffer
            }
            cells.append((cellColumn, value))
        case "row":
            let width = (cells.map(\.col).max() ?? -1) + 1
            var line = Array(repeating: "", count: max(width, 0))
            for cell in cells where cell.col < line.count {
                line[cell.col] = cell.value
            }
            rows.append(line)
        default:
            break
        }
    }
}
