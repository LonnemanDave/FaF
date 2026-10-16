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
    static let screenHorizontal: CGFloat = 20 // the printer's margin (Theme.margin)

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

/// Print has no rounded corners. Every radius is zero; the names stay only
/// so screens not yet rebuilt on JournalKit still compile. New work doesn't
/// round anything — a photograph is cropped, not carded.
struct FAFRadius {
    static let none: CGFloat = 0
    static let xs: CGFloat = 0
    static let sm: CGFloat = 0
    static let md: CGFloat = 0
    static let lg: CGFloat = 0
    static let xl: CGFloat = 0
    static let full: CGFloat = 0
}

// MARK: - Shadows

/// Nothing floats on a page. Kept as no-ops for unconverted screens.
struct FAFShadow {
    static let subtle = Shadow()
    static let `default` = Shadow()
    static let medium = Shadow()
    static let large = Shadow()
}

struct Shadow {
    let color: Color = .clear
    let radius: CGFloat = 0
    let x: CGFloat = 0
    let y: CGFloat = 0
}

// MARK: - View Extensions

extension View {
    func fafShadow(_ shadow: Shadow) -> some View {
        self
    }

    /// Standard screen padding
    func fafScreenPadding() -> some View {
        self.padding(.horizontal, Theme.margin)
            .padding(.vertical, FAFSpacing.screenVertical)
    }

    /// Card style padding
    func fafCardPadding() -> some View {
        self.padding(FAFSpacing.cardPadding)
    }
}
