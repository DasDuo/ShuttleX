import Foundation

enum HostValidation {
    /// Whitespace, control characters and shell metacharacters that must never
    /// appear in a connection target (host, IP, user). Real values don't use them.
    ///
    /// This is defense-in-depth only — the actual injection guard is `Shell.quote`,
    /// which single-quotes every target when the `ssh` command is built. Square
    /// brackets are therefore deliberately *allowed*: they carry no shell risk once
    /// quoted, and they're legitimate IPv6 syntax, e.g. `[2001:db8::1]`.
    static let unsafeCharacters: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.formUnion(.controlCharacters)
        set.formUnion(CharacterSet(charactersIn: ";|&$`<>(){}!*?\\\"'#~,"))
        return set
    }()

    static func isSafe(_ value: String) -> Bool {
        value.rangeOfCharacter(from: unsafeCharacters) == nil
    }
}
