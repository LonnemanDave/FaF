import SwiftUI

// MARK: - Typography — legacy names, journal behaviour
/// The old type scale, re-set in the journal's faces so unconverted screens
/// match: display and headings in the serif (New York), body in the text
/// face. New work uses `Font.plate` / `.figure` / `.setting` and
/// `Text.smallCaps` from JournalKit directly.

struct FAFTypography {

    // MARK: - Font Family

    /// Primary font family - using system font for clean look
    /// Can be swapped for custom font later
    static let fontFamily = Font.Design.default

    // MARK: - Display Styles (Hero text, splash screens)

    static let displayLarge = Font.plate(44)
    static let displayMedium = Font.plate(34)
    static let displaySmall = Font.plate(28)

    // MARK: - Heading Styles

    static let h1 = Font.plate(26)
    static let h2 = Font.plate(21, .semibold)
    static let h3 = Font.plate(18, .semibold)
    static let h4 = Font.plate(16, .semibold)

    // MARK: - Body Styles

    static let bodyLarge = Font.system(size: 17, weight: .regular, design: fontFamily)
    static let body = Font.system(size: 15, weight: .regular, design: fontFamily)
    static let bodyBold = Font.system(size: 15, weight: .semibold, design: fontFamily)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: fontFamily)

    // MARK: - Label Styles

    static let labelLarge = Font.system(size: 14, weight: .medium, design: fontFamily)
    static let label = Font.system(size: 12, weight: .medium, design: fontFamily)
    static let labelSmall = Font.system(size: 10, weight: .medium, design: fontFamily)

    // MARK: - Caption Styles

    static let caption = Font.system(size: 12, weight: .regular, design: fontFamily)
    static let captionSmall = Font.system(size: 10, weight: .regular, design: fontFamily)

    // MARK: - Button Styles

    static let buttonLarge = Font.system(size: 17, weight: .semibold, design: fontFamily)
    static let button = Font.system(size: 15, weight: .semibold, design: fontFamily)
    static let buttonSmall = Font.system(size: 13, weight: .semibold, design: fontFamily)
}

// MARK: - Text Style View Modifier

struct FAFTextStyle: ViewModifier {
    let font: Font
    let color: Color
    let lineSpacing: CGFloat

    init(font: Font, color: Color = Theme.ink, lineSpacing: CGFloat = 4) {
        self.font = font
        self.color = color
        self.lineSpacing = lineSpacing
    }

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
            .lineSpacing(lineSpacing)
    }
}

// MARK: - View Extensions

extension View {
    func fafDisplayLarge(color: Color = .fafBlack) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.displayLarge, color: color))
    }

    func fafDisplayMedium(color: Color = .fafBlack) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.displayMedium, color: color))
    }

    func fafH1(color: Color = .fafBlack) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.h1, color: color))
    }

    func fafH2(color: Color = .fafBlack) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.h2, color: color))
    }

    func fafH3(color: Color = .fafBlack) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.h3, color: color))
    }

    func fafBody(color: Color = .fafGrayDark) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.body, color: color))
    }

    func fafBodyLarge(color: Color = .fafGrayDark) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.bodyLarge, color: color))
    }

    func fafLabel(color: Color = .fafGray) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.label, color: color))
    }

    func fafCaption(color: Color = .fafGrayLight) -> some View {
        modifier(FAFTextStyle(font: FAFTypography.caption, color: color))
    }
}
