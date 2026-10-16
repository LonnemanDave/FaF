import SwiftUI

/// The cooking journal's palette and measures.
///
/// One ramp, defined once in the asset catalog with a light edition (cream
/// paper, brown ink) and a dark one (warm stone, cream ink):
/// `paper` → `fill` → `rule` → `ink3` → `ink2` → `ink`, plus `paprika`
/// (the accent), `herb`, `saffron` and the two state inks.
///
/// Never introduce a one-off colour — no hex in a view, no `.white`, no
/// `.black`, and no tinted boxes (`accent.opacity(0.1)` behind a button).
/// Colour marks a word or a figure; it never fills a block. Add to the ramp
/// here and in the asset catalog, or use what's there. A fixed colour is how
/// text went white-on-white in dark mode.
enum Theme {
    // MARK: - The ramp

    /// The page. One surface — there is no second background tier.
    static let paper = Color("Paper")
    /// The one step off the page: input lines, a chosen block, a photo's empty frame.
    static let fill = Color("Fill")
    /// Hairlines — the rules that replace card edges.
    static let rule = Color("Rule")
    /// Titles and body text.
    static let ink = Color("Ink")
    /// Secondary text — descriptions, labels.
    static let ink2 = Color("Ink2")
    /// Marginalia — timestamps, placeholders, dot leaders. Never for anything that must be read.
    static let ink3 = Color("Ink3")

    // MARK: - Inks

    /// The accent. Figures, the open chapter, anything that wants the eye.
    static let paprika = Color("Paprika")
    /// The second ink — vegetables, a chef's note, the lunch stamp.
    static let herb = Color("Herb")
    /// Breakfast, a star, a favourite.
    static let saffron = Color("Saffron")
    static let error = Color("Error")
    static let warning = Color("Warning")

    /// The accent by its job rather than its name.
    static let accent = paprika

    // MARK: - Measures

    /// The printer's margin — one measure, used on every page.
    static let margin: CGFloat = 20

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
}
