import SwiftUI

struct IconView: View {
    let item: DockItem
    let size: CGFloat

    var body: some View {
        Image(nsImage: IconCache.shared.icon(for: item.url))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .opacity(item.isHidden ? 0.5 : 1)
            .background {
                if item.isActive {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .fill(.white.opacity(0.22))
                        .frame(width: size + 3, height: size + 3)
                        .blur(radius: 1.5)
                }
            }
    }
}

struct RunningDot: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(.primary.opacity(isActive ? 0.95 : 0.6))
            .frame(width: 3, height: 3)
    }
}
