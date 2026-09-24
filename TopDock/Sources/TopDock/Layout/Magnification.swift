import CoreGraphics
import Foundation

struct IconSlot: Equatable {
    var centerX: CGFloat
    var scale: CGFloat
    var width: CGFloat
}

/// Dock-style magnification: icons near the cursor grow and push their neighbours apart,
/// while the point under the cursor stays fixed.
enum Magnification {
    /// - Parameters:
    ///   - widths: Unscaled width of each entry.
    ///   - scalable: Whether each entry magnifies (dividers don't).
    ///   - reach: Distance from the cursor at which magnification fades out.
    static func layout(
        widths: [CGFloat],
        scalable: [Bool],
        mouseX: CGFloat?,
        maxScale: CGFloat,
        reach: CGFloat
    ) -> [IconSlot] {
        let count = widths.count
        guard count > 0 else { return [] }

        var baseLefts: [CGFloat] = []
        var cursor: CGFloat = 0
        for width in widths {
            baseLefts.append(cursor)
            cursor += width
        }
        let total = cursor

        guard let mouseX, maxScale > 1.001, reach > 0 else {
            return (0..<count).map { IconSlot(centerX: baseLefts[$0] + widths[$0] / 2, scale: 1, width: widths[$0]) }
        }

        let scales = (0..<count).map { index -> CGFloat in
            guard scalable[index] else { return 1 }
            let distance = abs(mouseX - (baseLefts[index] + widths[index] / 2)) / reach
            guard distance < 1 else { return 1 }
            return 1 + (maxScale - 1) * (cos(distance * .pi) + 1) / 2
        }
        let scaledWidths = (0..<count).map { widths[$0] * scales[$0] }
        var lefts: [CGFloat] = []
        cursor = 0
        for width in scaledWidths {
            lefts.append(cursor)
            cursor += width
        }

        let anchor = min(max(mouseX, 0), total)
        let index = baseLefts.lastIndex { $0 <= anchor }.map { min($0, count - 1) } ?? 0
        let fraction = widths[index] > 0 ? (anchor - baseLefts[index]) / widths[index] : 0
        let offset = anchor - (lefts[index] + fraction * scaledWidths[index])

        return (0..<count).map {
            IconSlot(centerX: lefts[$0] + scaledWidths[$0] / 2 + offset, scale: scales[$0], width: scaledWidths[$0])
        }
    }
}
