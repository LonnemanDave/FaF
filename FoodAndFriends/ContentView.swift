import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        #if DEBUG
        if DesignHarness.isOn {
            switch DesignHarness.screen {
            case "login": LoginView()
            case "setup": ProfileSetupView()
            case "recipe-form": CreateRecipeView()
            case "recipe-edit": CreateRecipeView(recipeToEdit: DesignHarness.guinness)
            case "menu-form": ManualMealPlanCreatorView()
            case "ai-recipe": AIRecipeGeneratorView()
            case "ai-menu": AIMealPlanGeneratorView()
            case "menu-prefs": MealPlanPreferencesView(preferences: .constant(.default))
            case "ai-settings": AISettingsView()
            case "friends": FriendsView()
            case "add-friend": AddFriendView()
            case "friend": NavigationStack { UserProfileView(user: DesignHarness.friends[0]) }
            default: MainTabView()
            }
        } else {
            signedInFlow
        }
        #else
        signedInFlow
        #endif
    }

    private var signedInFlow: some View {
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
                .background(Color.fafBackground)

            case .signedOut:
                LoginView()

            case .needsProfileSetup:
                ProfileSetupView()

            case .signedIn:
                MainTabView()
            }
        }
        .animation(.easeInOut, value: authManager.authState)
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
