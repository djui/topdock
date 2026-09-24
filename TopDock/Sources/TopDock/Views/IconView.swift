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
            .overlay(alignment: .topTrailing) {
                if let badge = item.badge {
                    BadgeView(text: badge, iconSize: size)
                        .offset(x: size * 0.22, y: -size * 0.1)
                }
            }
    }
}

struct BadgeView: View {
    let text: String
    let iconSize: CGFloat

    var body: some View {
        let height = max(9, iconSize * 0.55)
        Text(text)
            .font(.system(size: height * 0.72, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(.white)
            .padding(.horizontal, text.count > 1 ? height * 0.25 : 0)
            .frame(minWidth: height, minHeight: height)
            .background(Capsule().fill(Color(nsColor: .systemRed)))
            .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
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
