import SwiftUI

// MARK: - Theme
/// Central theme configuration for Food and Friends
/// Combines colors, typography, and spacing into a unified system

struct FAFTheme {

    // MARK: - Singleton
    static let shared = FAFTheme()

    private init() {}

    // MARK: - Color Scheme

    struct Colors {
        // Backgrounds
        let background = Color.fafWhite
        let backgroundSecondary = Color.fafGrayXXLight
        let backgroundTertiary = Color.fafGrayXLight

        // Text
        let textPrimary = Color.fafBlack
        let textSecondary = Color.fafGrayDark
        let textTertiary = Color.fafGray
        let textDisabled = Color.fafGrayLight

        // Accent
        let accent = Color.fafCoral
        let accentSecondary = Color.fafOrange
        let accentBackground = Color.fafCoralLight

        // Borders
        let border = Color.fafGrayXLight
        let borderStrong = Color.fafGrayLight

        // States
        let success = Color.fafSuccess
        let warning = Color.fafWarning
        let error = Color.fafError
    }

    let colors = Colors()

    // MARK: - Animation Durations

    struct Animation {
        let fast: Double = 0.15
        let normal: Double = 0.25
        let slow: Double = 0.35

        var fastSpring: SwiftUI.Animation {
            .spring(response: fast, dampingFraction: 0.8)
        }

        var normalSpring: SwiftUI.Animation {
            .spring(response: normal, dampingFraction: 0.75)
        }

        var slowSpring: SwiftUI.Animation {
            .spring(response: slow, dampingFraction: 0.7)
        }
    }

    let animation = Animation()

    // MARK: - Icon Sizes

    struct IconSize {
        let xs: CGFloat = 16
        let sm: CGFloat = 20
        let md: CGFloat = 24
        let lg: CGFloat = 32
        let xl: CGFloat = 48
    }

    let iconSize = IconSize()
}

// MARK: - Environment Key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = FAFTheme.shared
}

extension EnvironmentValues {
    var fafTheme: FAFTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func fafTheme(_ theme: FAFTheme = .shared) -> some View {
        environment(\.fafTheme, theme)
    }
}
