import AppKit
import Observation

enum StripEntry: Equatable, Identifiable {
    case app(DockItem)
    /// Separates the Dock's kept apps from other running and recent apps.
    case divider

    var id: String {
        switch self {
        case .app(let item): item.id
        case .divider: "divider"
        }
    }

    var item: DockItem? {
        if case .app(let item) = self { item } else { nil }
    }
}

/// View state for one strip of icons (one per screen, or one on each side of the notch).
@MainActor
@Observable
final class SegmentModel {
    var entries: [StripEntry] = []
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

    static let chevronWidth: CGFloat = 24
    static let dividerWidth: CGFloat = 9

    var slot: CGFloat { iconSize + spacing }
    var iconTop: CGFloat { max(0, (barHeight - iconSize) / 2 - 1.5) }

    var baseWidths: [CGFloat] {
        entries.map { $0.item == nil ? Self.dividerWidth : slot }
    }

    var stripWidth: CGFloat { baseWidths.reduce(0, +) }

    func layout() -> [IconSlot] {
        Magnification.layout(
            widths: baseWidths,
            scalable: entries.map { $0.item != nil },
            mouseX: magnify ? mouseX : nil,
            maxScale: maxScale,
            reach: slot * 2.5
        )
    }

    /// Index of the app entry under the cursor in the unscaled layout.
    var hoveredIndex: Int? {
        guard let mouseX, mouseX >= 0, mouseX < stripWidth else { return nil }
        var left: CGFloat = 0
        for (index, width) in baseWidths.enumerated() {
            if mouseX < left + width { return entries[index].item == nil ? nil : index }
            left += width
        }
        return nil
    }

    /// The app at `x` in panel coordinates, using the magnified layout.
    func item(atPanelX x: CGFloat) -> DockItem? {
        let stripX = x - inset
        let slots = layout()
        return slots.indices
            .first { abs(slots[$0].centerX - stripX) <= slots[$0].width / 2 }
            .flatMap { entries[$0].item }
    }

    /// Right edge of the entries in strip coordinates, including magnification.
    func contentMaxX(_ slots: [IconSlot]) -> CGFloat {
        max(stripWidth, slots.last.map { $0.centerX + $0.width / 2 } ?? 0)
    }
}
