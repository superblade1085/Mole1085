import SwiftUI
import MoleEngine

public enum GlassTheme {
    public static let cardRadius: CGFloat = 12.0
    public static let innerRadius: CGFloat = 8.0
    public static let specularLineWidth: CGFloat = 0.5

    public static let specularHighlightColor = Color.white.opacity(0.22)
    public static let specularDarkBorderColor = Color.black.opacity(0.35)
    public static let highContrastBorderColor = Color.primary.opacity(0.40)
    public static let glassBackgroundColor = Color(nsColor: .windowBackgroundColor).opacity(0.55)

    // MARK: - MacSpace-Inspired Neutral Apple Palette
    public static let warmAmber = Color(red: 0.78, green: 0.48, blue: 0.11)       // #c87a1d (Reclaimable, Primary Action)
    public static let warmAmberDark = Color(red: 0.87, green: 0.54, blue: 0.16)   // #df8a28 (Night Glow)
    public static let sageGreen = Color(red: 0.24, green: 0.55, blue: 0.33)       // #3d8c55 / #4ea868 (Safe, Verified)
    public static let atmosphericBlue = Color(red: 0.24, green: 0.44, blue: 0.66) // #3c6fa8 / #5f92ce (System / Used)
    public static let softLavender = Color(red: 0.48, green: 0.48, blue: 0.76)    // #7a7ac2 / #9898dc (App Leftovers)
    public static let neutralSlate = Color(red: 0.39, green: 0.39, blue: 0.40)    // #636366 / #8e8e93 (Logs, Diagnostics)

    public static func color(for group: CleanCategoryGroup) -> Color {
        switch group {
        case .developer:
            return atmosphericBlue
        case .systemCaches:
            return warmAmber
        case .appLeftovers:
            return softLavender
        case .logs:
            return neutralSlate
        }
    }

    public static func safetyTint(for level: SafetyLevel) -> Color {
        switch level {
        case .guaranteedSafe:
            return sageGreen
        case .rebuildable:
            return atmosphericBlue
        case .deadLeftover:
            return softLavender
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

