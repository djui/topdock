import AppKit

/// Optional TopDock icon among the menu bar extras, giving access to Settings, About and Quit.
@MainActor
final class StatusItemController {
    var onSettings: () -> Void = {}
    var onAbout: () -> Void = {}

    private var item: NSStatusItem?

    func setVisible(_ visible: Bool) {
        if visible, item == nil {
            item = makeItem()
        } else if !visible, let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    private func makeItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: "TopDock")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "TopDock"
        }

        let menu = NSMenu()
        let settings = ClosureMenuItem("Settings…") { [weak self] in self?.onSettings() }
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(ClosureMenuItem("About TopDock") { [weak self] in self?.onAbout() })
        menu.addItem(.separator())
        let quit = ClosureMenuItem("Quit TopDock") { NSApp.terminate(nil) }
        quit.keyEquivalent = "q"
        menu.addItem(quit)
        item.menu = menu
        return item
    }
}
