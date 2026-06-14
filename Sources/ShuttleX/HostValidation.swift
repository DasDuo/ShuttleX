import Foundation

enum HostValidation {
    /// Whitespace, control characters and shell metacharacters that must never
    /// appear in a connection target (host, IP, user). Real values don't use them.
    static let unsafeCharacters: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.formUnion(.controlCharacters)
        set.formUnion(CharacterSet(charactersIn: ";|&$`<>(){}[]!*?\\\"'#~,"))
        return set
    }()

    static func isSafe(_ value: String) -> Bool {
        value.rangeOfCharacter(from: unsafeCharacters) == nil
    }
}
