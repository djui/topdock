import AppKit

@MainActor
enum AboutPanel {
    static let projectURL = URL(string: "https://github.com/djui/topdock")!

    static func show() {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center

        let credits = NSMutableAttributedString(
            string: "Your Dock, in the middle of the menu bar.\n\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: centered,
            ]
        )
        credits.append(NSAttributedString(
            string: "github.com/djui/topdock",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .link: projectURL,
                .paragraphStyle: centered,
            ]
        ))

        var options: [NSApplication.AboutPanelOptionKey: Any] = [.credits: credits]
        if let icon = appIcon() {
            options[.applicationIcon] = icon
        }

        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    /// The bundled icon, or the source `.icns` when running an unbundled debug build.
    private static func appIcon() -> NSImage? {
        if Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil {
            return NSApp.applicationIconImage
        }
        #if DEBUG
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../Resources/AppIcon.icns")
        return NSImage(contentsOf: source)
        #else
        return nil
        #endif
    }
}
