import Foundation

/// The real Dock's layout, read from the `com.apple.dock` preferences.
struct DockPreferences: Equatable {
    /// Apps kept in the Dock, in Dock order (Finder isn't listed; the Dock always adds it first).
    var persistentApps: [URL]
    /// The Dock's "recent apps" section.
    var recentApps: [URL]
    var showRecents: Bool
    var recentCount: Int

    static func read() -> DockPreferences {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)

        func value(_ key: String) -> Any? {
            CFPreferencesCopyAppValue(key as CFString, domain)
        }

        return DockPreferences(
            persistentApps: appURLs(value("persistent-apps")),
            recentApps: appURLs(value("recent-apps")),
            showRecents: (value("show-recents") as? Bool) ?? true,
            recentCount: (value("show-recent-count") as? Int) ?? 3
        )
    }

    private static func appURLs(_ tiles: Any?) -> [URL] {
        guard let tiles = tiles as? [Any] else { return [] }
        return tiles.compactMap { entry in
            guard let entry = entry as? [String: Any],
                  let tile = entry["tile-data"] as? [String: Any],
                  let file = tile["file-data"] as? [String: Any],
                  let urlString = file["_CFURLString"] as? String
            else { return nil }
            let url = urlString.hasPrefix("file://")
                ? URL(string: urlString)
                : URL(fileURLWithPath: urlString)
            guard let url = url?.standardizedFileURL, url.path.hasSuffix(".app") else { return nil }
            return url
        }
    }
}
