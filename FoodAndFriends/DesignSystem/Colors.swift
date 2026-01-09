import SwiftUI

// MARK: - Color Palette
/// Food and Friends color system
/// Monochrome base with warm food-inspired accents
/// Supports both light and dark mode

extension Color {

    // MARK: - Adaptive Colors (Light/Dark)

    /// Primary background - white in light, dark gray in dark
    static let fafBackground = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1C1C1E"))

    /// Secondary background - off-white in light, slightly lighter dark in dark
    static let fafBackgroundSecondary = Color(light: Color(hex: "F5F5F5"), dark: Color(hex: "2C2C2E"))

    /// Tertiary background - light gray in light, medium dark in dark
    static let fafBackgroundTertiary = Color(light: Color(hex: "FAFAFA"), dark: Color(hex: "3A3A3C"))

    /// Card/elevated background
    static let fafCardBackground = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "2C2C2E"))

    /// Primary text - black in light, white in dark
    static let fafTextPrimary = Color(light: Color(hex: "000000"), dark: Color(hex: "FFFFFF"))

    /// Secondary text - dark gray in light, light gray in dark
    static let fafTextSecondary = Color(light: Color(hex: "333333"), dark: Color(hex: "EBEBF5"))

    /// Tertiary text - medium gray
    static let fafTextTertiary = Color(light: Color(hex: "666666"), dark: Color(hex: "EBEBF599"))

    /// Disabled/placeholder text
    static let fafTextDisabled = Color(light: Color(hex: "999999"), dark: Color(hex: "636366"))

    /// Dividers and borders
    static let fafDivider = Color(light: Color(hex: "E5E5E5"), dark: Color(hex: "38383A"))

    /// Input field backgrounds
    static let fafInputBackground = Color(light: Color(hex: "FAFAFA"), dark: Color(hex: "1C1C1E"))

    // MARK: - Legacy Static Colors (for backwards compatibility)

    /// Pure black - for primary text and bold elements
    static let fafBlack = Color(hex: "000000")

    /// Pure white - for backgrounds and inverted text
    static let fafWhite = Color(hex: "FFFFFF")

    /// Off-white - softer background alternative
    static let fafOffWhite = Color(hex: "FAFAFA")

    // MARK: - Grays (Adaptive)

    /// Dark gray - secondary text (adapts to light gray in dark mode)
    static let fafGrayDark = Color(light: Color(hex: "333333"), dark: Color(hex: "CCCCCC"))

    /// Medium gray - tertiary text, borders (adapts in dark mode)
    static let fafGray = Color(light: Color(hex: "666666"), dark: Color(hex: "A0A0A0"))

    /// Light gray - subtle borders, disabled states (adapts in dark mode)
    static let fafGrayLight = Color(light: Color(hex: "999999"), dark: Color(hex: "8E8E93"))

    /// Extra light gray - backgrounds, dividers (adapts in dark mode)
    static let fafGrayXLight = Color(light: Color(hex: "E5E5E5"), dark: Color(hex: "3A3A3C"))

    /// Near white gray - subtle backgrounds (adapts in dark mode)
    static let fafGrayXXLight = Color(light: Color(hex: "F5F5F5"), dark: Color(hex: "2C2C2E"))

    // MARK: - Accent Colors (Food-Inspired)
    // These remain consistent across light/dark for brand identity

    /// Coral - primary warm accent, CTAs, highlights
    static let fafCoral = Color(hex: "FF6B5B")

    /// Warm orange - secondary warm accent
    static let fafOrange = Color(hex: "FF8C42")

    /// Muted coral - lighter accent for backgrounds (adapts in dark mode)
    static let fafCoralLight = Color(light: Color(hex: "FFE5E2"), dark: Color(hex: "4A2522"))

    /// Sage green - primary cool accent, balance to coral
    static let fafSage = Color(hex: "8B9A7B")

    /// Deep sage - darker green for emphasis
    static let fafSageDark = Color(hex: "6B7A5B")

    /// Light sage - subtle green for backgrounds (adapts in dark mode)
    static let fafSageLight = Color(light: Color(hex: "E8EDE4"), dark: Color(hex: "2A3328"))

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
    /// Creates an adaptive color that changes based on the current color scheme
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}
