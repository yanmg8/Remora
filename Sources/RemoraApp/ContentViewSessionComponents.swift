import SwiftUI

struct SessionTabBarItem: View {
    let title: String
    let tabID: UUID
    @ObservedObject var runtime: TerminalRuntime
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let accessibilityIdentifier: String
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                Text(title)
                    .lineLimit(1)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VisualStyle.textPrimary)
            }
            .buttonStyle(.plain)

            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VisualStyle.textSecondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? VisualStyle.leftSelectedBackground : (isHovering ? VisualStyle.leftHoverBackground : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? VisualStyle.borderStrong : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
