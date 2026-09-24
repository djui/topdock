import AppKit
import ApplicationServices

struct MenuBarSegment {
    enum Anchor {
        /// Centered on the given x, shifted as needed to stay inside `rect`.
        case center(CGFloat)
        /// Hugs the right edge of `rect` (left of the notch).
        case trailing
        /// Hugs the left edge of `rect` (right of the notch).
        case leading
    }

    var rect: NSRect
    var anchor: Anchor
}

struct MenuBarLayout {
    let screen: NSScreen
    let screenID: CGDirectDisplayID
    let barHeight: CGFloat
    let segments: [MenuBarSegment]
}

/// Computes the free menu bar space between the frontmost app's menus and the status items.
@MainActor
enum MenuBarGeometry {
    private static let gap: CGFloat = 10
    private static var menuWidthCache: (pid: pid_t, width: CGFloat, time: Date)?

    static func screenID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    static func barHeight(for screen: NSScreen) -> CGFloat {
        let reserved = screen.frame.maxY - screen.visibleFrame.maxY
        if reserved > 10 { return reserved }
        if screen.safeAreaInsets.top > 0 { return screen.safeAreaInsets.top }
        return max(NSStatusBar.system.thickness, 24)
    }

    static func layout(for screen: NSScreen, windows: [WindowInfo], fallbackWidth: CGFloat) -> MenuBarLayout {
        let frame = screen.frame
        let height = barHeight(for: screen)
        let band = NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height)
        let knownStatusMinX = statusItemsMinX(in: band, windows: windows)
        let statusMinX = knownStatusMinX ?? (frame.maxX - 240)
        let menuEnd = appMenuWidth().map { frame.minX + $0 }

        func segment(_ minX: CGFloat, _ maxX: CGFloat, _ anchor: MenuBarSegment.Anchor) -> MenuBarSegment {
            MenuBarSegment(rect: NSRect(x: minX, y: band.minY, width: max(0, maxX - minX), height: height), anchor: anchor)
        }

        if let (left, right) = notchAreas(of: screen, band: band, windows: windows) {
            var segments: [MenuBarSegment] = []
            let leftStart = max(left.minX, menuEnd.map { $0 + gap } ?? (left.maxX - fallbackWidth / 2))
            let leftEnd = left.maxX - gap
            if leftEnd - leftStart > 0 {
                segments.append(segment(leftStart, leftEnd, .trailing))
            }
            let rightStart = max(right.minX + gap, (menuEnd ?? 0) + gap)
            var rightEnd = min(right.maxX, statusMinX - gap)
            if knownStatusMinX == nil { rightEnd = min(rightEnd, right.minX + fallbackWidth / 2) }
            if rightEnd - rightStart > 0 {
                segments.append(segment(rightStart, rightEnd, .leading))
            }
            if !segments.isEmpty {
                return MenuBarLayout(screen: screen, screenID: screenID(screen), barHeight: height, segments: segments)
            }
        }

        var minX = menuEnd.map { $0 + gap } ?? (frame.midX - fallbackWidth / 2)
        var maxX = statusMinX - gap
        if menuEnd == nil || knownStatusMinX == nil { maxX = min(maxX, frame.midX + fallbackWidth / 2) }
        if maxX < minX { minX = maxX }
        return MenuBarLayout(
            screen: screen,
            screenID: screenID(screen),
            barHeight: height,
            segments: [segment(minX, maxX, .center(frame.midX))]
        )
    }

    /// Left edge of the leftmost status item (menu bar extra) on this screen.
    private static func statusItemsMinX(in band: NSRect, windows: [WindowInfo]) -> CGFloat? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var frames = windows
            .filter { $0.layer == WindowList.statusLayer && $0.pid != ownPID }
            .map(\.cgBounds)
        // Newer macOS versions no longer expose status items as windows.
        if frames.isEmpty { frames = StatusItemsProbe.frames }
        return frames
            .map { WindowList.toAppKit($0) }
            .filter { rect in
                rect.height <= band.height + 4 && rect.width < 600
                    && rect.midY >= band.minY - 2 && rect.midY <= band.maxY + 2
                    && rect.minX >= band.minX && rect.maxX <= band.maxX + 1
                    && rect.minX > band.midX - band.width / 4
            }
            .map(\.minX)
            .min()
    }

    /// Unobscured menu bar areas left and right of the camera housing, in global coordinates.
    private static func notchAreas(of screen: NSScreen, band: NSRect, windows: [WindowInfo]) -> (NSRect, NSRect)? {
        if screen.safeAreaInsets.top > 0,
           var left = screen.auxiliaryTopLeftArea,
           var right = screen.auxiliaryTopRightArea,
           !left.isEmpty, !right.isEmpty {
            if !screen.frame.intersects(left) {
                left = left.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY)
                right = right.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY)
            }
            return (left, right)
        }
        guard let overlay = centerOverlay(in: band, windows: windows) else { return nil }
        return (
            NSRect(x: band.minX, y: band.minY, width: overlay.minX - band.minX, height: band.height),
            NSRect(x: overlay.maxX, y: band.minY, width: band.maxX - overlay.maxX, height: band.height)
        )
    }

    /// A small window pinned to the top center above the menu bar, such as a
    /// notch-simulating or "dynamic island" app. Treated like a hardware notch.
    private static func centerOverlay(in band: NSRect, windows: [WindowInfo]) -> NSRect? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return windows
            .filter { $0.pid != ownPID && $0.layer > WindowList.statusLayer && $0.layer < 1000 }
            .map { WindowList.toAppKit($0.cgBounds) }
            .first { rect in
                rect.maxY >= band.maxY - 1 && rect.height <= band.height + 16
                    && rect.width >= 20 && rect.width <= 500
                    && abs(rect.midX - band.midX) < 150
            }
    }

    // MARK: - Accessibility

    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    static func invalidateMenuWidth() {
        menuWidthCache = nil
    }

    /// Width of the frontmost app's menus measured from the screen's left edge, via Accessibility.
    static func appMenuWidth() -> CGFloat? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        if pid == ProcessInfo.processInfo.processIdentifier { return menuWidthCache?.width }
        if let cache = menuWidthCache, cache.pid == pid, Date().timeIntervalSince(cache.time) < 5 {
            return cache.width
        }

        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard let menuBar: AXUIElement = AX.copy(element, kAXMenuBarAttribute),
              let children: [AXUIElement] = AX.copy(menuBar, kAXChildrenAttribute),
              let first = children.first.flatMap(AX.frame(of:)),
              let last = children.last.flatMap(AX.frame(of:))
        else { return menuWidthCache?.pid == pid ? menuWidthCache?.width : nil }

        let screenMinX = NSScreen.screens.first { $0.frame.minX <= first.minX && first.minX < $0.frame.maxX }?.frame.minX ?? 0
        let width = last.maxX - screenMinX
        menuWidthCache = (pid, width, Date())
        return width
    }
}
