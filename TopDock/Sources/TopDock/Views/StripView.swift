import SwiftUI

struct StripView: View {
    let model: SegmentModel

    var body: some View {
        let slots = model.layout()
        let hovered = model.hoveredIndex

        ZStack(alignment: .topLeading) {
            Color.clear

            ForEach(Array(model.entries.enumerated()), id: \.element.id) { index, entry in
                let slot = slots[index]

                switch entry {
                case .app(let item):
                    let size = model.iconSize * slot.scale
                    // The click target spans the whole column from the screen's top edge,
                    // so flinging the cursor against the top still hits the icon.
                    let columnHeight = max(model.barHeight, model.iconTop + size + 4)

                    IconView(item: item, size: size)
                        .position(x: model.inset + slot.centerX, y: model.iconTop + size / 2)
                        .allowsHitTesting(false)

                    Color.clear
                        .frame(width: slot.width, height: columnHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { model.onOpen(item) }
                        .help(item.name)
                        .position(x: model.inset + slot.centerX, y: columnHeight / 2)

                    if item.isRunning && model.indicator == nil {
                        RunningDot(isActive: item.isActive)
                            .position(x: model.inset + slot.centerX, y: model.iconTop + size + 2.5)
                            .allowsHitTesting(false)
                    }

                case .divider:
                    Capsule()
                        .fill(.primary.opacity(0.3))
                        .frame(width: 1, height: model.barHeight * 0.6)
                        .position(x: model.inset + slot.centerX, y: model.barHeight / 2)
                        .allowsHitTesting(false)
                }
            }

            if let hovered, let item = model.entries[hovered].item {
                let slot = slots[hovered]
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule())
                    .position(
                        x: model.inset + slot.centerX,
                        y: model.iconTop + model.iconSize * slot.scale + 15
                    )
                    .allowsHitTesting(false)
            }

            if model.showChevron {
                ChevronView(overflowCount: model.overflowCount)
                    .frame(width: SegmentModel.chevronWidth, height: model.barHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { model.onChevron() }
                    .position(
                        x: model.inset + model.contentMaxX(slots) + SegmentModel.chevronWidth / 2,
                        y: model.barHeight / 2
                    )
            }

            if let indicator = model.indicator {
                PageIndicator(range: indicator)
                    .frame(width: model.stripWidth, height: 2)
                    .position(x: model.inset + model.stripWidth / 2, y: model.barHeight - 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
    }
}

private struct ChevronView: View {
    let overflowCount: Int

    var body: some View {
        Group {
            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } else {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundStyle(.primary.opacity(0.8))
    }
}

private struct PageIndicator: View {
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.18))
                Capsule()
                    .fill(.primary.opacity(0.75))
                    .frame(width: max(4, width * (range.upperBound - range.lowerBound)))
                    .offset(x: width * range.lowerBound)
            }
        }
    }
}
