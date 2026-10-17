import SwiftUI

public struct AdaptiveGlassContainer<Content: View>: View {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    @ViewBuilder public var content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    public init(
        cornerRadius: CGFloat = GlassTheme.cardRadius,
        padding: CGFloat = 16.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .specularBorder(cornerRadius: cornerRadius)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                radius: 8,
                x: 0,
                y: 3
            )
    }

    @ViewBuilder
    private var backgroundView: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .withinWindow,
                state: .active
            )
            .overlay(
                GlassTheme.glassBackgroundColor
            )
        }
    }
}
