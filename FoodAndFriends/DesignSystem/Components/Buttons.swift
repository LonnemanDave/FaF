import SwiftUI

// MARK: - Button Styles
/// Food and Friends button components - minimal, elegant

// MARK: - Primary Button (Filled)

struct FAFPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FAFTypography.button)
            .foregroundColor(.fafWhite)
            .background(isEnabled ? Color.fafBlack : Color.fafGrayLight)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button (Outlined)

struct FAFSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FAFTypography.button)
            .foregroundColor(isEnabled ? .fafTextPrimary : .fafGrayLight)
            .background(Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isEnabled ? Color.fafTextPrimary : Color.fafGrayLight, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Accent Button (Coral filled)

struct FAFAccentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FAFTypography.button)
            .foregroundColor(.fafWhite)
            .background(isEnabled ? Color.fafCoral : Color.fafGrayLight)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Ghost Button (Text only)

struct FAFGhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FAFTypography.button)
            .foregroundColor(isEnabled ? .fafTextPrimary : .fafGrayLight)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Icon Button

struct FAFIconButtonStyle: ButtonStyle {
    let size: CGFloat

    init(size: CGFloat = 44) {
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.fafGrayXLight : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func fafPrimaryButton() -> some View {
        buttonStyle(FAFPrimaryButtonStyle())
    }

    func fafSecondaryButton() -> some View {
        buttonStyle(FAFSecondaryButtonStyle())
    }

    func fafAccentButton() -> some View {
        buttonStyle(FAFAccentButtonStyle())
    }

    func fafGhostButton() -> some View {
        buttonStyle(FAFGhostButtonStyle())
    }

    func fafIconButton(size: CGFloat = 44) -> some View {
        buttonStyle(FAFIconButtonStyle(size: size))
    }
}

// MARK: - Full Width Button Modifier

struct FullWidthButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func fafFullWidth() -> some View {
        modifier(FullWidthButtonModifier())
    }
}

// MARK: - FAFButton Component

enum FAFButtonStyle {
    case primary
    case secondary
    case accent
    case ghost
}

struct FAFButton: View {
    let title: String
    let style: FAFButtonStyle
    var icon: FAFIconType?
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FAFSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        FAFIcon(icon, size: 18, color: textColor)
                    }
                    Text(title)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .disabled(isLoading)
        .modifier(FAFButtonStyleModifier(style: style))
    }

    private var textColor: Color {
        switch style {
        case .primary, .accent:
            return .fafWhite
        case .secondary, .ghost:
            return .fafTextPrimary
        }
    }
}

// MARK: - Button Style Modifier

struct FAFButtonStyleModifier: ViewModifier {
    let style: FAFButtonStyle

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content.buttonStyle(FAFPrimaryButtonStyle())
        case .secondary:
            content.buttonStyle(FAFSecondaryButtonStyle())
        case .accent:
            content.buttonStyle(FAFAccentButtonStyle())
        case .ghost:
            content.buttonStyle(FAFGhostButtonStyle())
        }
    }
}
