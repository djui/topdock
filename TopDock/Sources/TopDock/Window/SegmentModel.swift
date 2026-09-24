import AppKit
import Observation

/// View state for one strip of icons (one per screen, or one on each side of the notch).
@MainActor
@Observable
final class SegmentModel {
    var items: [DockItem] = []
    var overflowCount = 0
    var showChevron = false
    var iconSize: CGFloat = 18
    var spacing: CGFloat = 5
    var barHeight: CGFloat = 24
    var magnify = true
    var maxScale: CGFloat = 1.8
    /// Cursor x relative to the left edge of the unscaled strip; nil when not hovering.
    var mouseX: CGFloat?
    /// Distance from the panel's left edge to the strip's left edge.
    var inset: CGFloat = 0
    /// Visible fraction of the full item list, shown briefly while paging.
    var indicator: ClosedRange<Double>?

    @ObservationIgnored var onOpen: (DockItem) -> Void = { _ in }
    @ObservationIgnored var onChevron: () -> Void = {}
    @ObservationIgnored var onDrop: (URL, Int) -> Void = { _, _ in }

    static let chevronWidth: CGFloat = 24

    var slot: CGFloat { iconSize + spacing }
    var stripWidth: CGFloat { CGFloat(items.count) * slot }
    var iconTop: CGFloat { max(0, (barHeight - iconSize) / 2 - 1.5) }

    func layout() -> [IconSlot] {
        Magnification.layout(
            count: items.count,
            slot: slot,
            mouseX: magnify ? mouseX : nil,
            maxScale: maxScale
        )
    }

    var hoveredIndex: Int? {
        guard let mouseX, mouseX >= 0, mouseX < stripWidth else { return nil }
        return min(Int(mouseX / slot), items.count - 1)
    }

    /// Index of the icon at `x` in panel coordinates, using the magnified layout.
    func itemIndex(atPanelX x: CGFloat) -> Int? {
        let stripX = x - inset
        return layout().firstIndex { abs($0.centerX - stripX) <= $0.width / 2 }
    }

    /// Where an item dropped at `x` (panel coordinates) should be inserted.
    func insertionIndex(atPanelX x: CGFloat) -> Int {
        let stripX = x - inset
        return layout().firstIndex { stripX < $0.centerX } ?? items.count
    }

    /// Right edge of the icons in strip coordinates, including magnification.
    func contentMaxX(_ slots: [IconSlot]) -> CGFloat {
        max(stripWidth, slots.last.map { $0.centerX + $0.width / 2 } ?? 0)
    }
}
