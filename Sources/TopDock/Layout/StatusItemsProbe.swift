import AppKit
import ApplicationServices

enum AX {
    static func copy<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }

    /// Frame in global CoreGraphics coordinates.
    static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = copy(element, kAXPositionAttribute),
              let sizeValue: AXValue = copy(element, kAXSizeAttribute)
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: position, size: size)
    }
}

/// Collects menu bar extra (status item) frames through Accessibility, for macOS versions
/// where they aren't separate windows. Runs off the main thread because it queries every app.
@MainActor
enum StatusItemsProbe {
    private(set) static var frames: [CGRect] = []
    private static var isRunning = false
    private static var lastRun = Date.distantPast

    static func refreshIfNeeded() {
        guard AXIsProcessTrusted(), !isRunning, Date().timeIntervalSince(lastRun) > 10 else { return }
        isRunning = true
        lastRun = Date()
        let pids = NSWorkspace.shared.runningApplications.map(\.processIdentifier)
        Task.detached(priority: .utility) {
            let frames = collect(pids)
            await MainActor.run {
                StatusItemsProbe.frames = frames
                StatusItemsProbe.isRunning = false
            }
        }
    }

    nonisolated private static func collect(_ pids: [pid_t]) -> [CGRect] {
        var frames: [CGRect] = []
        for pid in pids {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.1)
            guard let extras: AXUIElement = AX.copy(app, "AXExtrasMenuBar"),
                  let items: [AXUIElement] = AX.copy(extras, kAXChildrenAttribute)
            else { continue }
            frames.append(contentsOf: items.compactMap(AX.frame(of:)).filter { $0.width > 0 && $0.height > 0 })
        }
        return frames
    }
}
