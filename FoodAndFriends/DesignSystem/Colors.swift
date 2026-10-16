import SwiftUI

// MARK: - Legacy names, journal behaviour
//
// The colours the app was first built with, kept only so screens not yet
// rebuilt on JournalKit still compile. Every one now resolves to the
// journal's single ramp (see Theme), so an unconverted screen is at worst
// plain — never unreadable in either edition.
//
// The old palette had fixed colours (pure white, pure black, a near-white)
// next to adaptive ones, and screens used both freely. That is how text
// went white-on-white in dark mode. Nothing here is fixed any more.
//
// New work uses `Theme` directly. When the last screen is rebuilt, delete
// this file and let the compiler find any stragglers.

extension Color {

    // MARK: Surfaces — one page
    //
    // There is no second background tier: what were cards are set on the
    // page itself. Only a text entry keeps a faint fill, so it can still be
    // found until its screen moves to FieldLine.

    static let fafBackground = Theme.paper
    static let fafBackgroundSecondary = Theme.paper
    static let fafBackgroundTertiary = Theme.paper
    static let fafCardBackground = Theme.paper
    static let fafInputBackground = Theme.fill

    // MARK: Ink

    static let fafTextPrimary = Theme.ink
    static let fafTextSecondary = Theme.ink2
    static let fafTextTertiary = Theme.ink2
    static let fafTextDisabled = Theme.ink3
    static let fafDivider = Theme.rule

    // MARK: Formerly fixed

    /// Was pure black. Now ink, which follows the edition.
    static let fafBlack = Theme.ink
    /// Was pure white — used both as a page and as text on an accent. Paper serves as both.
    static let fafWhite = Theme.paper
    /// Was a fixed near-white. Now the page.
    static let fafOffWhite = Theme.paper

    // MARK: Greys

    static let fafGrayDark = Theme.ink2
    static let fafGray = Theme.ink2
    static let fafGrayLight = Theme.ink3
    static let fafGrayXLight = Theme.rule
    static let fafGrayXXLight = Theme.paper

    // MARK: Accents

    static let fafCoral = Theme.paprika
    /// Was a pale coral wash behind things. The journal doesn't tint boxes.
    static let fafCoralLight = Theme.paper
    static let fafOrange = Theme.saffron
    static let fafSage = Theme.herb
    static let fafSageDark = Theme.herb
    /// Was a pale sage wash. Same as above.
    static let fafSageLight = Theme.paper

    // MARK: States

    static let fafSuccess = Theme.herb
    static let fafWarning = Theme.warning
    static let fafError = Theme.error
}
