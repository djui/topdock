import AppKit
import SwiftUI

/// Transparent, non-activating panel that floats one level above the menu bar.
final class DockPanel: NSPanel {
    static let baseBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        // Set explicitly so clicks on transparent pixels (e.g. the topmost row above an
        // icon) reach the panel instead of passing through to the menu bar.
        ignoresMouseEvents = false
        collectionBehavior = Self.baseBehavior
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// AppKit normally keeps windows out of the menu bar; this panel lives there on purpose.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class StripHostingView: NSHostingView<StripView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
