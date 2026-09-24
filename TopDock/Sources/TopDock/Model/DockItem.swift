import AppKit

struct DockItem: Identifiable, Equatable {
    /// Bundle identifier, or the bundle path for apps without one.
    let id: String
    let url: URL
    let name: String
    var pid: pid_t?
    var isRunning: Bool
    var isActive: Bool
    var isHidden: Bool
    /// Notification badge text from the Dock, e.g. "3".
    var badge: String?

    var runningApp: NSRunningApplication? {
        pid.flatMap { NSRunningApplication(processIdentifier: $0) }
    }
}

@MainActor
final class IconCache {
    static let shared = IconCache()

    private var icons: [String: NSImage] = [:]

    func icon(for url: URL) -> NSImage {
        if let cached = icons[url.path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[url.path] = icon
        return icon
    }

    func menuIcon(for url: URL) -> NSImage {
        let image = icon(for: url).copy() as! NSImage
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
