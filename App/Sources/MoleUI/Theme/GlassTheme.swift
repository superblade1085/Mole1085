import SwiftUI
import MoleEngine

public enum GlassTheme {
    public static let cardRadius: CGFloat = 12.0
    public static let innerRadius: CGFloat = 8.0
    public static let specularLineWidth: CGFloat = 0.5

    public static let specularHighlightColor = Color.white.opacity(0.15)
    public static let specularDarkBorderColor = Color.black.opacity(0.25)
    public static let glassBackgroundColor = Color(nsColor: .windowBackgroundColor).opacity(0.55)

    public static func color(for group: CleanCategoryGroup) -> Color {
        switch group {
        case .developer:
            return Color(red: 0.20, green: 0.60, blue: 1.0) // Vibrance Blue
        case .systemCaches:
            return Color(red: 1.0, green: 0.62, blue: 0.20) // Amber Orange
        case .appLeftovers:
            return Color(red: 0.70, green: 0.40, blue: 0.95) // Neon Purple
        case .logs:
            return Color(red: 1.0, green: 0.35, blue: 0.45) // Coral Rose
        }
    }

    public static func gradient(for group: CleanCategoryGroup) -> LinearGradient {
        let base = color(for: group)
        return LinearGradient(
            colors: [base.opacity(0.85), base],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
