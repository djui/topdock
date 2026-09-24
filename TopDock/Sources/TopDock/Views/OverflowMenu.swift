import AppKit

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, image: NSImage? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        self.image = image
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func fire() {
        handler()
    }
}

/// Builds the chevron (overflow) menu and the per-icon context menu.
@MainActor
struct MenuFactory {
    let store: AppStore
    let openSettings: () -> Void
    let openAbout: () -> Void

    func overflowMenu(for items: [DockItem]) -> NSMenu {
        let menu = NSMenu()
        let runningImage = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Running")
        runningImage?.size = NSSize(width: 5, height: 5)

        for item in items {
            let entry = ClosureMenuItem(item.name, image: IconCache.shared.menuIcon(for: item.url)) {
                store.open(item)
            }
            if item.isRunning {
                entry.state = .on
                entry.onStateImage = runningImage
            }
            if let badge = item.badge {
                entry.badge = NSMenuItemBadge(string: badge)
            }
            menu.addItem(entry)
        }
        if !items.isEmpty { menu.addItem(.separator()) }
        appendAppItems(to: menu)
        return menu
    }

    func contextMenu(for item: DockItem) -> NSMenu {
        let menu = NSMenu()
        let optionHeld = NSEvent.modifierFlags.contains(.option)

        menu.addItem(ClosureMenuItem("Show in Finder") { store.revealInFinder(item) })

        if item.isRunning {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(item.isHidden ? "Unhide" : "Hide") { store.toggleHidden(item) })
            if optionHeld {
                menu.addItem(ClosureMenuItem("Force Quit") { store.quit(item, force: true) })
            } else {
                menu.addItem(ClosureMenuItem("Quit") { store.quit(item, force: false) })
            }
        }

        menu.addItem(.separator())
        appendAppItems(to: menu)
        return menu
    }

    func appMenu() -> NSMenu {
        let menu = NSMenu()
        appendAppItems(to: menu)
        return menu
    }

    private func appendAppItems(to menu: NSMenu) {
        menu.addItem(ClosureMenuItem("TopDock Settings…") { openSettings() })
        menu.addItem(ClosureMenuItem("About TopDock") { openAbout() })
        menu.addItem(ClosureMenuItem("Quit TopDock") { NSApp.terminate(nil) })
    }
}
