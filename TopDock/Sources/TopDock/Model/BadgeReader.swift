import AppKit
import ApplicationServices

/// Reads the notification badges shown on the real Dock's icons through Accessibility.
/// There's no public API for other apps' badges, and no change notification, so it polls.
@MainActor
final class BadgeReader {
    var onChange: (() -> Void)?

    /// Badge text keyed by app bundle path, plus a fallback keyed by Dock title.
    private var byPath: [String: String] = [:]
    private var byName: [String: String] = [:]
    private var timer: Timer?
    private var isReading = false

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func badge(for url: URL, name: String) -> String? {
        byPath[url.standardizedFileURL.path] ?? byName[name]
    }

    private func refresh() {
        guard !isReading else { return }
        guard AXIsProcessTrusted(),
              let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
                .first?.processIdentifier
        else {
            update(byPath: [:], byName: [:])
            return
        }
        isReading = true
        Task.detached(priority: .utility) { [weak self] in
            let (byPath, byName) = Self.read(dockPID: dockPID)
            await MainActor.run {
                self?.isReading = false
                self?.update(byPath: byPath, byName: byName)
            }
        }
    }

    private func update(byPath: [String: String], byName: [String: String]) {
        guard byPath != self.byPath || byName != self.byName else { return }
        self.byPath = byPath
        self.byName = byName
        onChange?()
    }

    nonisolated private static func read(dockPID: pid_t) -> ([String: String], [String: String]) {
        let dock = AXUIElementCreateApplication(dockPID)
        AXUIElementSetMessagingTimeout(dock, 0.25)
        var byPath: [String: String] = [:]
        var byName: [String: String] = [:]

        let lists: [AXUIElement] = AX.copy(dock, kAXChildrenAttribute) ?? []
        for list in lists {
            let items: [AXUIElement] = AX.copy(list, kAXChildrenAttribute) ?? []
            for item in items {
                guard let badge: String = AX.copy(item, "AXStatusLabel"), !badge.isEmpty else { continue }
                if let url: URL = AX.copy(item, "AXURL") {
                    byPath[url.standardizedFileURL.path] = badge
                }
                if let title: String = AX.copy(item, kAXTitleAttribute) {
                    byName[title] = badge
                }
            }
        }
        return (byPath, byName)
    }
}
