import AppKit

struct WindowInfo {
    let pid: pid_t
    let layer: Int
    /// Global CoreGraphics coordinates (origin top-left of the primary display).
    let cgBounds: CGRect
}

enum WindowList {
    static let mainMenuLayer = Int(CGWindowLevelForKey(.mainMenuWindow))
    static let statusLayer = Int(CGWindowLevelForKey(.statusWindow))

    /// On-screen windows. Bounds and owners are readable without Screen Recording permission.
    static func snapshot() -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return list.compactMap { info in
            guard let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict)
            else { return nil }
            return WindowInfo(pid: pid, layer: layer, cgBounds: bounds)
        }
    }

    @MainActor
    static func toAppKit(_ rect: CGRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    @MainActor
    static func toCG(_ rect: NSRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
