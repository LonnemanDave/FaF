import SwiftUI

// MARK: - Typography System
/// Food and Friends typography - clean, minimal, readable

struct FAFTypography {

    // MARK: - Font Family

    /// Primary font family - using system font for clean look
    /// Can be swapped for custom font later
    static let fontFamily = Font.Design.default

    // MARK: - Display Styles (Hero text, splash screens)

    static let displayLarge = Font.system(size: 48, weight: .bold, design: fontFamily)
    static let displayMedium = Font.system(size: 36, weight: .bold, design: fontFamily)
    static let displaySmall = Font.system(size: 28, weight: .bold, design: fontFamily)

    // MARK: - Heading Styles

    static let h1 = Font.system(size: 24, weight: .bold, design: fontFamily)
    static let h2 = Font.system(size: 20, weight: .semibold, design: fontFamily)
    static let h3 = Font.system(size: 18, weight: .semibold, design: fontFamily)
    static let h4 = Font.system(size: 16, weight: .medium, design: fontFamily)

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

    init(font: Font, color: Color = .fafBlack, lineSpacing: CGFloat = 4) {
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
