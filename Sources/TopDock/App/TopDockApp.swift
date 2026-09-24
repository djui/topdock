import AppKit

@main
struct TopDockMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences()
    private lazy var store = AppStore(prefs: prefs)
    private lazy var panels = PanelController(store: store, prefs: prefs)
    private lazy var settings = SettingsWindowController(prefs: prefs, store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        prefs.onChange = { [weak self] in
            self?.store.rebuild()
            self?.panels.relayout()
        }
        store.onChange = { [weak self] in
            self?.panels.relayout()
        }
        panels.onOpenSettings = { [weak self] in
            self?.settings.show()
        }

        store.start()
        panels.start()

        if !prefs.hasLaunchedBefore {
            prefs.hasLaunchedBefore = true
            settings.show()
        }

        #if DEBUG
        if let path = ProcessInfo.processInfo.environment["TOPDOCK_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                MainActor.assumeIsolated {
                    self.panels.debugSnapshot(to: URL(fileURLWithPath: path))
                }
            }
        }
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return true
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit TopDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        return main
    }

    @objc private func openSettings() {
        settings.show()
    }
}
