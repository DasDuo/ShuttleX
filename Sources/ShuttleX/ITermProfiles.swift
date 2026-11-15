import Foundation

/// Reads the profiles configured in iTerm2, so a server entry can pick one that
/// actually exists instead of carrying a hand-typed name that only fails at
/// launch time — iTerm2 raises an AppleScript error for an unknown profile.
enum ITermProfiles {
    static let domain = "com.googlecode.iterm2"

    /// Profile names in the order iTerm2 stores them. Empty when iTerm2 isn't
    /// installed, or when its preferences can't be read.
    static func installed() -> [String] {
        preferences().map(names(in:)) ?? []
    }

    /// Parses the profile names out of an iTerm2 preferences dictionary.
    /// Separate from the lookup so it can be tested without touching the
    /// machine's real preferences.
    static func names(in preferences: [String: Any]) -> [String] {
        guard let bookmarks = preferences["New Bookmarks"] as? [[String: Any]] else { return [] }
        return bookmarks
            .compactMap { $0["Name"] as? String }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// iTerm2 can be configured to keep its preferences in a custom folder. The
    /// standard domain then holds only the pointer, not the profiles — reading
    /// just the domain would report "no profiles" for those users.
    private static func preferences() -> [String: Any]? {
        let standard = UserDefaults.standard.persistentDomain(forName: domain)
        if let standard,
           standard["LoadPrefsFromCustomFolder"] as? Bool == true,
           let folder = standard["PrefsCustomFolder"] as? String, !folder.isEmpty {
            let url = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath)
                .appendingPathComponent("\(domain).plist")
            if let custom = NSDictionary(contentsOf: url) as? [String: Any],
               custom["New Bookmarks"] != nil {
                return custom
            }
        }
        return standard
    }
}
