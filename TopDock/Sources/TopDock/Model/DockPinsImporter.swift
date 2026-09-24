import Foundation

/// Reads the apps pinned in the system Dock (`com.apple.dock` → `persistent-apps`).
enum DockPinsImporter {
    static func pinnedAppPaths() -> [String] {
        let entries: [Any]
        if let apps = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") {
            entries = apps
        } else {
            let plist = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Preferences/com.apple.dock.plist")
            guard let dict = NSDictionary(contentsOf: plist),
                  let apps = dict["persistent-apps"] as? [Any]
            else { return [] }
            entries = apps
        }

        return entries.compactMap { entry in
            guard let entry = entry as? [String: Any],
                  let tile = entry["tile-data"] as? [String: Any],
                  let file = tile["file-data"] as? [String: Any],
                  let urlString = file["_CFURLString"] as? String
            else { return nil }
            let url = urlString.hasPrefix("file://")
                ? URL(string: urlString)
                : URL(fileURLWithPath: urlString)
            guard let path = url?.standardizedFileURL.path, path.hasSuffix(".app") else { return nil }
            return path
        }
    }
}
