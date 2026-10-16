import SwiftUI

// MARK: - FAFButton — legacy name, letterpress behaviour
//
// The app's original button, now set as JournalKit's press block: square,
// small caps, inked or outlined. Kept so the remaining call sites compile;
// new work uses `Button(...).buttonStyle(.press)` / `.pressOutline` directly.

enum FAFButtonStyle {
    /// Inked block — the one main action on a page.
    case primary
    /// Outlined block — the other choices.
    case secondary
    /// Was a coral fill. The journal has one inked button, so this is `primary`.
    case accent
    /// Small caps in the margin, no block.
    case ghost
}

struct FAFButton: View {
    let title: String
    let style: FAFButtonStyle
    var icon: FAFIconType?
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        switch style {
        case .primary, .accent:
            button.buttonStyle(.press)
        case .secondary:
            button.buttonStyle(.pressOutline)
        case .ghost:
            button.buttonStyle(.plain)
        }
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacingSM) {
                if isLoading {
                    ProgressView()
                        .tint(style == .secondary || style == .ghost ? Theme.ink : Theme.paper)
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon.sfSymbol)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    if style == .ghost {
                        Text(title.uppercased())
                            .smallCaps(11, weight: .semibold, tracking: 1.3)
                            .foregroundColor(Theme.ink)
                    } else {
                        Text(title)
                    }
                }
            }
        }
        .disabled(isLoading)
    }
}
