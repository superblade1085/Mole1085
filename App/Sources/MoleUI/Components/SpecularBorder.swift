import SwiftUI

public struct SpecularBorder: ViewModifier {
    public var cornerRadius: CGFloat
    public var lineWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(cornerRadius: CGFloat = GlassTheme.cardRadius, lineWidth: CGFloat = GlassTheme.specularLineWidth) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    public func body(content: Content) -> some View {
        let effectiveLineWidth = colorSchemeContrast == .increased ? max(1.0, lineWidth) : lineWidth
        return content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        strokeGradient,
                        lineWidth: effectiveLineWidth
                    )
            )
    }

    private var strokeGradient: LinearGradient {
        if colorSchemeContrast == .increased {
            return LinearGradient(
                colors: [GlassTheme.highContrastBorderColor, GlassTheme.highContrastBorderColor],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        if reduceTransparency {
            return LinearGradient(
                colors: [Color.primary.opacity(0.18), Color.primary.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    GlassTheme.specularHighlightColor,
                    Color.white.opacity(0.08),
                    GlassTheme.specularDarkBorderColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.65),
                    Color.white.opacity(0.20),
                    Color.black.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

public extension View {
    func specularBorder(
        cornerRadius: CGFloat = GlassTheme.cardRadius,
        lineWidth: CGFloat = GlassTheme.specularLineWidth
    ) -> some View {
        modifier(SpecularBorder(cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}
