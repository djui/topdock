import AppKit

/// One panel showing one strip of icons.
@MainActor
final class SegmentPanel {
    static let padding: CGFloat = 4
    static let labelHeight: CGFloat = 30

    let panel = DockPanel()
    let model = SegmentModel()
    var screen: NSScreen
    var baseFrame: NSRect = .zero
    var hasContent = false
    private(set) var isExpanded = false
    private(set) var isShown = false

    init(screen: NSScreen) {
        self.screen = screen
        let hosting = StripHostingView(rootView: StripView(model: model))
        hosting.sizingOptions = []
        panel.contentView = hosting
        model.inset = Self.padding
    }

    private var horizontalMargin: CGFloat {
        guard model.magnify else { return 60 }
        return max(60, model.slot * (model.maxScale - 1) * 2.5)
    }

    private var expandedFrame: NSRect {
        let extra = (model.magnify ? model.iconSize * (model.maxScale - 1) : 0) + Self.labelHeight
        return NSRect(
            x: baseFrame.minX - horizontalMargin,
            y: baseFrame.minY - extra,
            width: baseFrame.width + horizontalMargin * 2,
            height: baseFrame.height + extra
        )
    }

    func setBaseFrame(_ frame: NSRect) {
        guard frame != baseFrame else { return }
        baseFrame = frame
        applyFrame()
    }

    func hover(at location: NSPoint) {
        if !isExpanded {
            isExpanded = true
            model.inset = Self.padding + horizontalMargin
            applyFrame()
        }
        model.mouseX = location.x - baseFrame.minX - Self.padding
    }

    func endHover() {
        guard isExpanded else { return }
        isExpanded = false
        model.mouseX = nil
        model.inset = Self.padding
        applyFrame()
    }

    func setShown(_ shown: Bool) {
        let shown = shown && hasContent
        guard shown != isShown else { return }
        isShown = shown
        if shown {
            panel.orderFrontRegardless()
        } else {
            endHover()
            panel.orderOut(nil)
        }
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }

    private func applyFrame() {
        panel.setFrame(isExpanded ? expandedFrame : baseFrame, display: true)
    }
}

/// Owns all panels, distributes items across them, and handles hover, scrolling and menus.
@MainActor
final class PanelController {
    var onOpenSettings: () -> Void = {}
    var onOpenAbout: () -> Void = {}

    private let store: AppStore
    private let prefs: Preferences
    private let fullscreen = FullscreenMonitor()
    private var panels: [String: SegmentPanel] = [:]
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var timers: [Timer] = []
    private var lastMouse = NSPoint(x: -1, y: -1)

    private var scrollOffset = 0
    private var scrollAccumulator: CGFloat = 0
    private var indicatorUntil = Date.distantPast

    private var menus: MenuFactory {
        MenuFactory(
            store: store,
            openSettings: { [weak self] in self?.onOpenSettings() },
            openAbout: { [weak self] in self?.onOpenAbout() }
        )
    }

    init(store: AppStore, prefs: Preferences) {
        self.store = store
        self.prefs = prefs
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                MenuBarGeometry.invalidateMenuWidth()
                self?.relayout()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        })

        let mouseEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.trackMouse() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mouseEvents, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.trackMouse() }
            return event
        }) {
            monitors.append(local)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .rightMouseDown], handler: { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return consumed ? nil : event
        }) {
            monitors.append(local)
        }

        // Polling covers mouse movement the event monitors miss (e.g. over other apps' menus).
        timers.append(Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackMouse() }
        })
        // Status items and app menus change without notifications.
        timers.append(Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        })

        fullscreen.onChange = { [weak self] in self?.updateVisibility() }
        fullscreen.start()
        relayout()
    }

    // MARK: - Layout

    func relayout() {
        StatusItemsProbe.refreshIfNeeded()
        let windows = WindowList.snapshot()
        let dock = store.layout
        let mainApps = dock.dockApps + dock.otherRunning
        let slot = prefs.iconSize + 5

        var screens = NSScreen.screens
        if !prefs.allDisplays || !NSScreen.screensHaveSeparateSpaces {
            screens = Array(screens.prefix(1))
        }

        var used = Set<String>()
        var maxOffset = 0

        for screen in screens {
            let layout = MenuBarGeometry.layout(for: screen, windows: windows, fallbackWidth: prefs.fallbackWidth)
            let segments = layout.segments
            let lastIndex = segments.count - 1

            let offset = min(scrollOffset, max(0, mainApps.count - 1))
            let main = entries(dockApps: dock.dockApps, otherRunning: dock.otherRunning, skipping: offset)

            var widths = segments.map { $0.rect.width - 2 * SegmentPanel.padding }
            var fitted = fill(main, into: widths, slot: slot)
            let needsChevron = fitted.consumed < main.count || offset > 0
            if needsChevron {
                widths[lastIndex] -= SegmentModel.chevronWidth
                fitted = fill(main, into: widths, slot: slot)
            } else if !dock.recents.isEmpty {
                // Recent apps only use space left over after the Dock's and running apps.
                let divider: [StripEntry] = dock.otherRunning.isEmpty ? [.divider] : []
                fitted = fill(main + divider + dock.recents.map(StripEntry.app), into: widths, slot: slot)
            }

            let visibleIDs = Set(fitted.groups.joined().compactMap(\.item?.id))
            let overflow = mainApps.filter { !visibleIDs.contains($0.id) }
            let visibleMainCount = mainApps.count - overflow.count
            maxOffset = max(maxOffset, overflow.count)

            let showIndicator = Date() < indicatorUntil && needsChevron && !mainApps.isEmpty
            let indicator: ClosedRange<Double>? = showIndicator
                ? Double(offset) / Double(mainApps.count)...Double(offset + visibleMainCount) / Double(mainApps.count)
                : nil

            for (index, segment) in segments.enumerated() {
                let key = "\(layout.screenID)-\(index)"
                used.insert(key)
                let panel = panels[key] ?? SegmentPanel(screen: screen)
                panels[key] = panel
                panel.screen = screen
                configure(
                    panel,
                    entries: fitted.groups[index],
                    overflow: index == lastIndex && needsChevron ? overflow : nil,
                    segment: segment,
                    barHeight: layout.barHeight,
                    indicator: indicator
                )
            }
        }

        for (key, panel) in panels where !used.contains(key) {
            panel.close()
            panels[key] = nil
        }
        scrollOffset = min(scrollOffset, maxOffset)
        updateVisibility()
    }

    /// The Dock's apps, a divider, then other running apps, starting `offset` apps in.
    private func entries(dockApps: [DockItem], otherRunning: [DockItem], skipping offset: Int) -> [StripEntry] {
        let dockPart = dockApps.dropFirst(offset).map(StripEntry.app)
        let runningPart = otherRunning.dropFirst(max(0, offset - dockApps.count)).map(StripEntry.app)
        let divider: [StripEntry] = dockPart.isEmpty || runningPart.isEmpty ? [] : [.divider]
        return dockPart + divider + runningPart
    }

    /// Places a prefix of `entries` into the segments left to right, keeping their order.
    /// Stops at the first entry that doesn't fit or once `maxSlots` apps are placed.
    private func fill(
        _ entries: [StripEntry],
        into widths: [CGFloat],
        slot: CGFloat
    ) -> (groups: [[StripEntry]], consumed: Int) {
        var groups = Array(repeating: [StripEntry](), count: widths.count)
        var segment = 0
        var usedWidth: CGFloat = 0
        var apps = 0
        var consumed = 0

        placing: for entry in entries {
            let isDivider = entry.item == nil
            if !isDivider && apps >= prefs.maxSlots { break }
            let width = isDivider ? SegmentModel.dividerWidth : slot
            while usedWidth + width > widths[segment] {
                segment += 1
                usedWidth = 0
                if segment == widths.count { break placing }
            }
            consumed += 1
            // A divider at the start of a segment separates nothing.
            if isDivider && groups[segment].isEmpty { continue }
            groups[segment].append(entry)
            usedWidth += width
            if !isDivider { apps += 1 }
        }

        for index in groups.indices where groups[index].last == .divider {
            groups[index].removeLast()
        }
        return (groups, consumed)
    }

    private func configure(
        _ panel: SegmentPanel,
        entries: [StripEntry],
        overflow: [DockItem]?,
        segment: MenuBarSegment,
        barHeight: CGFloat,
        indicator: ClosedRange<Double>?
    ) {
        let model = panel.model
        if model.entries != entries { model.entries = entries }
        model.showChevron = overflow != nil
        model.overflowCount = overflow?.count ?? 0
        model.iconSize = prefs.iconSize
        model.barHeight = barHeight
        model.magnify = prefs.magnify
        model.maxScale = prefs.magnification
        model.indicator = indicator

        model.onOpen = { [weak self] item in self?.store.open(item) }
        model.onChevron = { [weak self] in
            self?.popUp(self?.menus.overflowMenu(for: overflow ?? []))
        }
        panel.panel.collectionBehavior = prefs.hideWhenMenuBarHidden
            ? DockPanel.baseBehavior
            : DockPanel.baseBehavior.union(.fullScreenAuxiliary)

        let width = 2 * SegmentPanel.padding
            + model.stripWidth
            + (overflow != nil ? SegmentModel.chevronWidth : 0)
        let rect = segment.rect
        let x: CGFloat
        switch segment.anchor {
        case .center(let midX):
            x = width >= rect.width ? rect.minX : min(max(midX - width / 2, rect.minX), rect.maxX - width)
        case .trailing:
            x = rect.maxX - width
        case .leading:
            x = rect.minX
        }
        panel.hasContent = !entries.isEmpty || overflow != nil
        panel.setBaseFrame(NSRect(x: x.rounded(), y: rect.maxY - barHeight, width: width, height: barHeight))
    }

    private func updateVisibility() {
        let windows = prefs.hideWhenMenuBarHidden ? WindowList.snapshot() : []
        for panel in panels.values {
            let visible = !prefs.hideWhenMenuBarHidden
                || fullscreen.isMenuBarVisible(on: panel.screen, barHeight: panel.model.barHeight, windows: windows)
            panel.setShown(visible)
        }
    }

    // MARK: - Mouse

    private func trackMouse() {
        let location = NSEvent.mouseLocation
        guard location != lastMouse else { return }
        lastMouse = location
        for panel in panels.values {
            let base = panel.baseFrame
            let hotZone = NSRect(x: base.minX, y: base.minY, width: base.width, height: base.height + 2)
            if panel.isShown, hotZone.contains(location) {
                panel.hover(at: location)
            } else {
                panel.endHover()
            }
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let window = event.window,
              let panel = panels.values.first(where: { $0.panel === window })
        else { return false }

        switch event.type {
        case .scrollWheel:
            scroll(by: event)
            return true
        case .rightMouseDown:
            let menu: NSMenu
            if let item = panel.model.item(atPanelX: event.locationInWindow.x) {
                menu = menus.contextMenu(for: item)
            } else {
                menu = menus.appMenu()
            }
            popUp(menu)
            return true
        default:
            return false
        }
    }

    private func scroll(by event: NSEvent) {
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        let delta = abs(dx) > abs(dy) ? -dx : -dy
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 18 : 0.5
        scrollAccumulator += delta

        var steps = 0
        while scrollAccumulator >= threshold { steps += 1; scrollAccumulator -= threshold }
        while scrollAccumulator <= -threshold { steps -= 1; scrollAccumulator += threshold }
        if event.phase == .ended || event.momentumPhase == .ended { scrollAccumulator = 0 }
        guard steps != 0 else { return }

        scrollOffset = max(0, scrollOffset + steps)
        indicatorUntil = Date().addingTimeInterval(1.2)
        relayout()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.3))
            self?.relayout()
        }
    }

    private func popUp(_ menu: NSMenu?) {
        menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    #if DEBUG
    /// Renders each panel, idle and hovered over its second icon, into `directory`.
    func debugSnapshot(to directory: URL) {
        for (key, panel) in panels {
            panel.writeSnapshot(to: directory.appendingPathComponent("\(key)-idle.png"))
            let base = panel.baseFrame
            panel.hover(at: NSPoint(x: base.minX + SegmentPanel.padding + panel.model.slot * 1.5, y: base.midY))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MainActor.assumeIsolated {
                    panel.writeSnapshot(to: directory.appendingPathComponent("\(key)-hover.png"))
                    panel.endHover()
                }
            }
        }
    }
    #endif
}

#if DEBUG
extension SegmentPanel {
    func writeSnapshot(to url: URL) {
        guard let view = panel.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
