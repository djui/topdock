import AppKit

/// The apps TopDock shows, in the same sections and order as the real Dock.
struct DockLayout: Equatable {
    /// Finder followed by the apps kept in the Dock, in Dock order.
    var dockApps: [DockItem] = []
    /// Running apps that aren't kept in the Dock, in launch order.
    var otherRunning: [DockItem] = []
    /// The Dock's recent apps that aren't shown already, capped like the Dock.
    var recents: [DockItem] = []
}

/// Mirrors the real Dock: its kept apps and recent apps, plus running app state.
@MainActor
final class AppStore {
    private(set) var layout = DockLayout()
    var onChange: (() -> Void)?

    private let prefs: Preferences
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var bundleIDs: [String: String] = [:]
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    init(prefs: Preferences) {
        self.prefs = prefs
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        let refreshing: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
        ]
        for name in refreshing {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            })
        }
        // The Dock doesn't announce changes to its layout.
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
        rebuild()
    }

    func rebuild() {
        let workspace = NSWorkspace.shared
        let dock = DockPreferences.read()
        let frontPID = workspace.frontmostApplication?.processIdentifier

        var runningByID: [String: NSRunningApplication] = [:]
        var running: [NSRunningApplication] = []
        for app in workspace.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != ownPID {
            guard let url = app.bundleURL else { continue }
            let id = app.bundleIdentifier ?? url.path
            guard runningByID[id] == nil else { continue }
            runningByID[id] = app
            running.append(app)
        }

        func makeItem(id: String, url: URL) -> DockItem {
            let app = runningByID[id]
            return DockItem(
                id: id,
                url: app?.bundleURL ?? url,
                name: app?.localizedName ?? Self.displayName(for: url),
                pid: app?.processIdentifier,
                isRunning: app != nil,
                isActive: app != nil && app?.processIdentifier == frontPID,
                isHidden: app?.isHidden ?? false
            )
        }

        var seen = Set<String>()
        var result = DockLayout()

        let finderURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.finder")
            ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        for url in [finderURL] + dock.persistentApps where FileManager.default.fileExists(atPath: url.path) {
            let id = identifier(for: url)
            guard seen.insert(id).inserted else { continue }
            result.dockApps.append(makeItem(id: id, url: url))
        }

        for app in running.sorted(by: { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }) {
            guard let url = app.bundleURL else { continue }
            let id = app.bundleIdentifier ?? url.path
            guard seen.insert(id).inserted else { continue }
            result.otherRunning.append(makeItem(id: id, url: url))
        }

        if dock.showRecents {
            for url in dock.recentApps where result.recents.count < dock.recentCount {
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                let id = identifier(for: url)
                guard seen.insert(id).inserted else { continue }
                result.recents.append(makeItem(id: id, url: url))
            }
        }

        if result != layout {
            layout = result
            onChange?()
        }
    }

    private func identifier(for url: URL) -> String {
        if let cached = bundleIDs[url.path] { return cached }
        let id = Bundle(url: url)?.bundleIdentifier ?? url.path
        bundleIDs[url.path] = id
        return id
    }

    private static func displayName(for url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    // MARK: - Actions

    func open(_ item: DockItem) {
        if let app = item.runningApp {
            if prefs.clickActiveHides, app.isActive {
                app.hide()
                return
            }
            if app.isHidden { app.unhide() }
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: item.url, configuration: config) { _, error in
            if let error { NSLog("TopDock: failed to open app: \(error.localizedDescription)") }
        }
    }

    func toggleHidden(_ item: DockItem) {
        guard let app = item.runningApp else { return }
        if app.isHidden { app.unhide() } else { app.hide() }
    }

    func quit(_ item: DockItem, force: Bool) {
        guard let app = item.runningApp else { return }
        if force { app.forceTerminate() } else { app.terminate() }
    }

    func revealInFinder(_ item: DockItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}
