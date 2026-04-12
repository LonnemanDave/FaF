import SwiftUI

// MARK: - Spacing System
/// Food and Friends spacing constants - consistent rhythm throughout the app

struct FAFSpacing {

    // MARK: - Base Unit
    /// Base spacing unit (4pt grid system)
    static let unit: CGFloat = 4

    // MARK: - Spacing Scale

    /// 4pt - Minimal spacing (icons, tight elements)
    static let xxxs: CGFloat = unit        // 4

    /// 8pt - Extra extra small
    static let xxs: CGFloat = unit * 2     // 8

    /// 12pt - Extra small
    static let xs: CGFloat = unit * 3      // 12

    /// 16pt - Small (default padding)
    static let sm: CGFloat = unit * 4      // 16

    /// 20pt - Medium small
    static let md: CGFloat = unit * 5      // 20

    /// 24pt - Medium
    static let lg: CGFloat = unit * 6      // 24

    /// 32pt - Large
    static let xl: CGFloat = unit * 8      // 32

    /// 40pt - Extra large
    static let xxl: CGFloat = unit * 10    // 40

    /// 48pt - Extra extra large
    static let xxxl: CGFloat = unit * 12   // 48

    /// 64pt - Huge
    static let huge: CGFloat = unit * 16   // 64

    // MARK: - Screen Padding

    /// Standard horizontal screen padding
    static let screenHorizontal: CGFloat = sm  // 16

    /// Standard vertical screen padding
    static let screenVertical: CGFloat = lg    // 24

    // MARK: - Component Spacing

    /// Space between list items
    static let listItemSpacing: CGFloat = xs   // 12

    /// Space between sections
    static let sectionSpacing: CGFloat = xl    // 32

    /// Space between form fields
    static let formFieldSpacing: CGFloat = sm  // 16

    /// Card internal padding
    static let cardPadding: CGFloat = sm       // 16

    /// Button internal padding (horizontal)
    static let buttonPaddingH: CGFloat = lg    // 24

    /// Button internal padding (vertical)
    static let buttonPaddingV: CGFloat = xs    // 12
}

// MARK: - Corner Radius

struct FAFRadius {

    /// No radius
    static let none: CGFloat = 0

    /// Small radius - subtle rounding (4pt)
    static let xs: CGFloat = 4

    /// Default radius - buttons, inputs (8pt)
    static let sm: CGFloat = 8

    /// Medium radius - cards (12pt)
    static let md: CGFloat = 12

    /// Large radius - modals, large cards (16pt)
    static let lg: CGFloat = 16

    /// Extra large radius - floating elements (24pt)
    static let xl: CGFloat = 24

    /// Full/Pill radius
    static let full: CGFloat = 9999
}

// MARK: - Shadows

struct FAFShadow {

    /// Subtle shadow - for slight elevation
    static let subtle = Shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

    /// Default shadow - cards, buttons
    static let `default` = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

    /// Medium shadow - dropdowns, popovers
    static let medium = Shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)

    /// Large shadow - modals, dialogs
    static let large = Shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 12)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    func fafShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Standard screen padding
    func fafScreenPadding() -> some View {
        self.padding(.horizontal, FAFSpacing.screenHorizontal)
            .padding(.vertical, FAFSpacing.screenVertical)
    }

    /// Card style padding
    func fafCardPadding() -> some View {
        self.padding(FAFSpacing.cardPadding)
    }
}
