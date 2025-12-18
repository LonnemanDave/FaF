import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                // Loading state while checking auth
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(FAFTypography.body)
                        .foregroundColor(.fafGray)
                        .padding(.top, FAFSpacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.fafWhite)

            case .signedOut:
                LoginView()

            case .needsProfileSetup:
                ProfileSetupView()

            case .signedIn:
                HomeView()
            }
        }
        .animation(.easeInOut, value: authManager.authState)
        .preferredColorScheme(.light)
    }
}

// MARK: - Color Swatch Component

struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack(spacing: FAFSpacing.xxxs) {
            RoundedRectangle(cornerRadius: FAFRadius.sm)
                .fill(color)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.sm)
                        .stroke(Color.fafGrayXLight, lineWidth: 1)
                )
            Text(name)
                .font(.system(size: 9))
                .foregroundColor(.fafGray)
        }
    }
}

#Preview {
    ContentView()
}
