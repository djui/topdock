import AppKit

/// Decides whether the menu bar is currently visible on a screen, so TopDock can hide with it.
///
/// Fullscreen Spaces are already handled by the window server (the panel doesn't use
/// `.fullScreenAuxiliary`); this additionally covers fullscreen windows that stay on a
/// regular Space and the "Automatically hide and show the menu bar" setting.
@MainActor
final class FullscreenMonitor {
    var onChange: (() -> Void)?

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onChange?() }
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    func isMenuBarVisible(on screen: NSScreen, barHeight: CGFloat, windows: [WindowInfo]) -> Bool {
        let screenCG = WindowList.toCG(screen.frame)

        if let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
           windows.contains(where: { window in
               window.pid == frontPID && window.layer == 0 && Self.approximatelyEqual(window.cgBounds, screenCG)
           }) {
            return false
        }

        let autoHides = screen.visibleFrame.maxY >= screen.frame.maxY - 1
        guard autoHides else { return true }

        let mouse = NSEvent.mouseLocation
        if screen.frame.contains(mouse), mouse.y >= screen.frame.maxY - barHeight - 1 {
            return true
        }
        return windows.contains { window in
            window.layer == WindowList.mainMenuLayer
                && window.cgBounds.minX < screenCG.maxX && window.cgBounds.maxX > screenCG.minX
                && window.cgBounds.minY <= screenCG.minY + 1
                && window.cgBounds.maxY >= screenCG.minY + barHeight / 2
        }
    }

    private static func approximatelyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 2 && abs(a.minY - b.minY) < 2
            && abs(a.width - b.width) < 2 && abs(a.height - b.height) < 2
    }
}
