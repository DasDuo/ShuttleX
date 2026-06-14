import Foundation

enum Shell {
    /// Wraps a value as a single inert shell token via POSIX single-quoting, so
    /// metacharacters (`;`, `|`, `$(…)`, backticks, spaces, …) cannot be interpreted.
    /// `a'b` becomes `'a'\''b'`.
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
