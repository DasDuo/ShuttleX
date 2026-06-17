import Foundation

/// Opt-in update check against the public GitHub Releases API (no auth, no server).
enum UpdateCheck {
    static let releasesURL = URL(string: "https://github.com/DasDuo/ShuttleX/releases/latest")!
    private static let apiURL = URL(string: "https://api.github.com/repos/DasDuo/ShuttleX/releases/latest")!

    /// True if `remote` is strictly newer than `current`. Both are dotted versions
    /// like "1.7.0" with an optional leading "v"; missing components count as 0.
    static func isNewer(_ remote: String, than current: String) -> Bool {
        let r = components(remote), c = components(current)
        for index in 0..<max(r.count, c.count) {
            let a = index < r.count ? r[index] : 0
            let b = index < c.count ? c[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "v "))
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }

    /// Fetches the latest release tag from GitHub. Calls `completion` on the main
    /// queue with the version (e.g. "1.7.0") or `nil` on any error.
    static func fetchLatestVersion(completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { data, _, _ in
            var version: String?
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v "))
            }
            DispatchQueue.main.async { completion(version) }
        }.resume()
    }
}
