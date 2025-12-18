import SwiftUI

// MARK: - Color Palette
/// Food and Friends color system
/// Monochrome base with warm food-inspired accents

extension Color {

    // MARK: - Primary (Monochrome)

    /// Pure black - for primary text and bold elements
    static let fafBlack = Color(hex: "000000")

    /// Pure white - for backgrounds and inverted text
    static let fafWhite = Color(hex: "FFFFFF")

    /// Off-white - softer background alternative
    static let fafOffWhite = Color(hex: "FAFAFA")

    // MARK: - Grays

    /// Dark gray - secondary text
    static let fafGrayDark = Color(hex: "333333")

    /// Medium gray - tertiary text, borders
    static let fafGray = Color(hex: "666666")

    /// Light gray - subtle borders, disabled states
    static let fafGrayLight = Color(hex: "999999")

    /// Extra light gray - backgrounds, dividers
    static let fafGrayXLight = Color(hex: "E5E5E5")

    /// Near white gray - subtle backgrounds
    static let fafGrayXXLight = Color(hex: "F5F5F5")

    // MARK: - Accent Colors (Food-Inspired)

    /// Coral - primary warm accent, CTAs, highlights
    static let fafCoral = Color(hex: "FF6B5B")

    /// Warm orange - secondary warm accent
    static let fafOrange = Color(hex: "FF8C42")

    /// Muted coral - lighter accent for backgrounds
    static let fafCoralLight = Color(hex: "FFE5E2")

    /// Sage green - primary cool accent, balance to coral
    static let fafSage = Color(hex: "8B9A7B")

    /// Deep sage - darker green for emphasis
    static let fafSageDark = Color(hex: "6B7A5B")

    /// Light sage - subtle green for backgrounds
    static let fafSageLight = Color(hex: "E8EDE4")

    // MARK: - Semantic Colors

    /// Success state
    static let fafSuccess = Color(hex: "4CAF50")

    /// Warning state
    static let fafWarning = Color(hex: "FFC107")

    /// Error state
    static let fafError = Color(hex: "F44336")
}

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Dark Mode Support

extension Color {

    /// Adaptive background - white in light mode, black in dark mode
    static let fafBackground = Color("Background")

    /// Adaptive foreground - black in light mode, white in dark mode
    static let fafForeground = Color("Foreground")

    /// Adaptive secondary background
    static let fafBackgroundSecondary = Color("BackgroundSecondary")
}
