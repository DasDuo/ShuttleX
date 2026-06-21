import Foundation

/// Version and release-channel info read from the bundle.
///
/// `CFBundleShortVersionString` stays a plain numeric `X.Y.Z` (the update check
/// parses it numerically). The channel is a separate `ShuttleXChannel` key, so a
/// build can advertise itself as a beta without disturbing that.
enum AppInfo {
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"

    /// "stable" (default), "beta", or "alpha". The release workflow overwrites
    /// this to match the tag; the committed value is the default for local builds.
    static let channel = (Bundle.main.infoDictionary?["ShuttleXChannel"] as? String)?
        .lowercased() ?? "stable"

    static var isPrerelease: Bool { channel == "beta" || channel == "alpha" }

    /// "1.11.0" on stable, "1.11.0 (beta)" on a prerelease channel.
    static var displayVersion: String {
        isPrerelease ? "\(version) (\(channel))" : version
    }
}
