import SwiftUI

public struct SpecularBorder: ViewModifier {
    public var cornerRadius: CGFloat
    public var lineWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(cornerRadius: CGFloat = GlassTheme.cardRadius, lineWidth: CGFloat = GlassTheme.specularLineWidth) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        strokeGradient,
                        lineWidth: lineWidth
                    )
            )
    }

    private var strokeGradient: LinearGradient {
        if reduceTransparency {
            return LinearGradient(
                colors: [Color.primary.opacity(0.15), Color.primary.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.08),
                    Color.black.opacity(0.35)
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
