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
    static func layout(
        count: Int,
        slot: CGFloat,
        mouseX: CGFloat?,
        maxScale: CGFloat,
        radius: CGFloat = 2.5
    ) -> [IconSlot] {
        guard count > 0 else { return [] }
        guard let mouseX, maxScale > 1.001 else {
            return (0..<count).map { IconSlot(centerX: slot * (CGFloat($0) + 0.5), scale: 1, width: slot) }
        }

        let scales = (0..<count).map { index -> CGFloat in
            let distance = abs(mouseX - slot * (CGFloat(index) + 0.5)) / (radius * slot)
            guard distance < 1 else { return 1 }
            return 1 + (maxScale - 1) * (cos(distance * .pi) + 1) / 2
        }
        let widths = scales.map { $0 * slot }
        var lefts: [CGFloat] = []
        var cursor: CGFloat = 0
        for width in widths {
            lefts.append(cursor)
            cursor += width
        }

        let total = slot * CGFloat(count)
        let anchor = min(max(mouseX, 0), total)
        let index = min(Int(anchor / slot), count - 1)
        let fraction = (anchor - slot * CGFloat(index)) / slot
        let offset = anchor - (lefts[index] + fraction * widths[index])

        return (0..<count).map {
            IconSlot(centerX: lefts[$0] + widths[$0] / 2 + offset, scale: scales[$0], width: widths[$0])
        }
    }
}
