import AppKit

/// Source of truth for what TopDock shows: pinned apps, running apps and recently used apps.
@MainActor
final class AppStore {
    private(set) var items: [DockItem] = []
    private(set) var pinnedPaths: [String]
    var onChange: (() -> Void)?

    private let prefs: Preferences
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let maxRecencyEntries = 60

    /// Item id → last activation (seconds since 1970).
    private var recency: [String: Double]
    /// Item id → bundle path, so recently used apps can be shown after they quit.
    private var knownPaths: [String: String]
    private var bundleIDs: [String: String] = [:]
    private var observers: [NSObjectProtocol] = []

    init(prefs: Preferences) {
        self.prefs = prefs
        let d = UserDefaults.standard
        recency = d.dictionary(forKey: "recency") as? [String: Double] ?? [:]
        knownPaths = d.dictionary(forKey: "knownPaths") as? [String: String] ?? [:]
        pinnedPaths = d.stringArray(forKey: "pinnedPaths") ?? []
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        let refreshing: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
        ]
        for name in refreshing {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            })
        }
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.noteActivation() }
        })
        noteActivation()
    }

    // MARK: - Building the item list

    func rebuild() {
        let workspace = NSWorkspace.shared
        let frontPID = workspace.frontmostApplication?.processIdentifier
        let pinnedIDs = Set(pinnedPaths.map(identifier(forPath:)))

        var running: [(app: NSRunningApplication, id: String, url: URL)] = []
        var runningIDs = Set<String>()
        for app in workspace.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != ownPID {
            guard let url = app.bundleURL else { continue }
            let id = app.bundleIdentifier ?? url.path
            guard runningIDs.insert(id).inserted else { continue }
            running.append((app, id, url))
            knownPaths[id] = url.path
            if recency[id] == nil {
                recency[id] = app.launchDate?.timeIntervalSince1970 ?? 0
            }
        }
        let runningByID = Dictionary(uniqueKeysWithValues: running.map { ($0.id, $0.app) })

        func makeItem(id: String, url: URL) -> DockItem {
            let app = runningByID[id]
            return DockItem(
                id: id,
                url: url,
                name: app?.localizedName ?? Self.displayName(for: url),
                pid: app?.processIdentifier,
                isRunning: app != nil,
                isActive: app != nil && app?.processIdentifier == frontPID,
                isHidden: app?.isHidden ?? false,
                isPinned: pinnedIDs.contains(id)
            )
        }

        var result: [DockItem] = []
        var seen = Set<String>()

        if prefs.showPinned {
            for path in pinnedPaths where FileManager.default.fileExists(atPath: path) {
                let id = identifier(forPath: path)
                guard seen.insert(id).inserted else { continue }
                result.append(makeItem(id: id, url: runningByID[id]?.bundleURL ?? URL(fileURLWithPath: path)))
            }
        }

        let sortedRunning: [(app: NSRunningApplication, id: String, url: URL)]
        switch prefs.sortMode {
        case .recent:
            sortedRunning = running.sorted { (recency[$0.id] ?? 0) > (recency[$1.id] ?? 0) }
        case .launch:
            sortedRunning = running.sorted {
                ($0.app.launchDate ?? .distantPast) < ($1.app.launchDate ?? .distantPast)
            }
        case .name:
            sortedRunning = running.sorted {
                ($0.app.localizedName ?? "").localizedStandardCompare($1.app.localizedName ?? "") == .orderedAscending
            }
        }
        for entry in sortedRunning where seen.insert(entry.id).inserted {
            result.append(makeItem(id: entry.id, url: entry.url))
        }

        if prefs.showRecents {
            let recents = recency
                .filter { !seen.contains($0.key) }
                .sorted { $0.value > $1.value }
                .compactMap { entry -> DockItem? in
                    guard let path = knownPaths[entry.key],
                          FileManager.default.fileExists(atPath: path)
                    else { return nil }
                    return makeItem(id: entry.key, url: URL(fileURLWithPath: path))
                }
                .prefix(prefs.recentsLimit)
            result.append(contentsOf: recents)
        }

        if result != items {
            items = result
            onChange?()
        }
    }

    private func noteActivation() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.processIdentifier != ownPID,
           app.activationPolicy == .regular,
           let url = app.bundleURL {
            let id = app.bundleIdentifier ?? url.path
            recency[id] = Date().timeIntervalSince1970
            knownPaths[id] = url.path
            pruneAndPersist()
        }
        rebuild()
    }

    private func pruneAndPersist() {
        if recency.count > maxRecencyEntries {
            let keep = recency.sorted { $0.value > $1.value }.prefix(maxRecencyEntries).map(\.key)
            recency = recency.filter { keep.contains($0.key) }
            knownPaths = knownPaths.filter { recency[$0.key] != nil }
        }
        let d = UserDefaults.standard
        d.set(recency, forKey: "recency")
        d.set(knownPaths, forKey: "knownPaths")
    }

    private func identifier(forPath path: String) -> String {
        if let cached = bundleIDs[path] { return cached }
        let id = Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier ?? path
        bundleIDs[path] = id
        return id
    }

    private static func displayName(for url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    // MARK: - Pins

    /// Pins `url`, or moves an existing pin, so it sits before the pinned item `beforeID`
    /// (appends when `beforeID` is nil or isn't pinned).
    func pin(_ url: URL, before beforeID: String? = nil) {
        let path = url.standardizedFileURL.path
        guard path.hasSuffix(".app") else { return }
        let id = identifier(forPath: path)
        guard id != beforeID else { return }
        pinnedPaths.removeAll { identifier(forPath: $0) == id }
        if let beforeID, let index = pinnedPaths.firstIndex(where: { identifier(forPath: $0) == beforeID }) {
            pinnedPaths.insert(path, at: index)
        } else {
            pinnedPaths.append(path)
        }
        savePins()
    }

    func unpin(_ item: DockItem) {
        pinnedPaths.removeAll { identifier(forPath: $0) == item.id }
        savePins()
    }

    func importDockPins() {
        for path in DockPinsImporter.pinnedAppPaths()
        where !pinnedPaths.contains(where: { identifier(forPath: $0) == identifier(forPath: path) }) {
            pinnedPaths.append(path)
        }
        savePins()
    }

    func clearPins() {
        pinnedPaths = []
        savePins()
    }

    private func savePins() {
        UserDefaults.standard.set(pinnedPaths, forKey: "pinnedPaths")
        rebuild()
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
