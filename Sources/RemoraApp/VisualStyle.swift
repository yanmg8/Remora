import SwiftUI

enum VisualStyle {
    static let pagePadding: CGFloat = 14
    static let panelSpacing: CGFloat = 12
    static let cardRadius: CGFloat = 14
    static let smallRadius: CGFloat = 10

    static let leftSidebarBackground = Color(
        red: 243.0 / 255.0,
        green: 243.0 / 255.0,
        blue: 244.0 / 255.0
    )
    static let leftInteractiveBackground = Color(
        red: 214.0 / 255.0,
        green: 216.0 / 255.0,
        blue: 219.0 / 255.0
    )
    static let leftHoverBackground = Color(
        red: 223.0 / 255.0,
        green: 224.0 / 255.0,
        blue: 227.0 / 255.0
    )
    static let leftSelectedBackground = Color(
        red: 210.0 / 255.0,
        green: 212.0 / 255.0,
        blue: 216.0 / 255.0
    )
    static let rightPanelBackground = Color.white
    static let terminalBackground = Color.black

    static let textPrimary = Color.black.opacity(0.95)
    static let textSecondary = Color.black.opacity(0.72)
    static let textTertiary = Color.black.opacity(0.55)

    static let borderStrong = Color.black.opacity(0.22)
    static let borderNormal = Color.black.opacity(0.15)
    static let borderSoft = Color.black.opacity(0.09)

    static let shadowColor = Color.black.opacity(0.06)
}

private struct GlassCardModifier: ViewModifier {
    var radius: CGFloat
    var fill: Color
    var border: Color

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .shadow(color: VisualStyle.shadowColor, radius: 10, x: 0, y: 4)
    }
}

extension View {
    func glassCard(
        radius: CGFloat = VisualStyle.cardRadius,
        fill: Color = VisualStyle.rightPanelBackground,
        border: Color = VisualStyle.borderNormal
    ) -> some View {
        modifier(GlassCardModifier(radius: radius, fill: fill, border: border))
    }

    func panelTitleStyle() -> some View {
        self
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(VisualStyle.textPrimary)
    }

    func monoMetaStyle() -> some View {
        self
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(VisualStyle.textSecondary)
    }
}
