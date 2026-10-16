import SwiftUI

/// You — the inside cover: your portrait and name, the figures of your
/// kitchen, and the few settings the journal has.
struct ProfileView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var mealPlanService = MealPlanService.shared
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @ObservedObject var aiService = AIService.shared
    @EnvironmentObject private var router: TabRouter

    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAISettings = false
    @State private var showFriends = false
    @State private var confirmSignOut = false
    @State private var confirmDeleteAccount = false
    @State private var isDeletingAccount = false
    @State private var showBlocked = false
    @ObservedObject private var moderation = ModerationService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    header

                    Figures(items: [
                        (label: "Friends", value: "\(userService.currentUser?.friends.count ?? 0)"),
                        (label: "Recipes", value: "\(recipeService.userRecipes.count)"),
                        (label: "Menus", value: "\(mealPlanService.userMealPlans.count)"),
                    ])

                    VStack(alignment: .leading, spacing: 0) {
                        SectionHead(title: "Your kitchen")
                            .padding(.bottom, 2)
                        kitchenLine("Friends", figure: "\(userService.currentUser?.friends.count ?? 0)") { showFriends = true }
                        DashedDivider()
                        kitchenLine("Recipes", figure: "\(recipeService.userRecipes.count)") { router.selection = .recipes }
                        DashedDivider()
                        kitchenLine("Menus", figure: "\(mealPlanService.userMealPlans.count)") { router.selection = .mealPlans }
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        SectionHead(title: "Look")
                        IndexSelector(
                            options: AppearanceMode.allCases.map { (value: $0, label: $0.rawValue) },
                            selection: Binding(
                                get: { appearanceManager.appearanceMode },
                                set: { mode in withAnimation(.easeInOut(duration: 0.2)) { appearanceManager.appearanceMode = mode } }
                            )
                        )
                        Text(lookNote)
                            .font(.setting(12).italic())
                            .foregroundColor(Theme.ink3)
                    }

                    if AIService.isEnabled {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHead(title: "AI assistant")
                            .padding(.bottom, 2)
                        Button {
                            showAISettings = true
                        } label: {
                            IndexEntry(
                                title: "Claude API key",
                                subtitle: aiService.hasValidAPIKey
                                    ? "Recipes and menus can be asked for"
                                    : "Add one to ask for recipes and menus",
                                figure: aiService.hasValidAPIKey ? "Set" : "Not set",
                                figureColor: aiService.hasValidAPIKey ? Theme.herb : Theme.ink3
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        SectionHead(title: "Privacy & safety")
                            .padding(.bottom, 2)
                        kitchenLine("Blocked", figure: "\(moderation.blockedIds.count)") { showBlocked = true }
                        DashedDivider()
                        linkLine("Terms of use", LegalLinks.terms)
                        DashedDivider()
                        linkLine("Privacy policy", LegalLinks.privacy)
                        DashedDivider()
                        linkLine("Help & support", LegalLinks.support)
                    }

                    VStack(spacing: Theme.spacingMD) {
                        MarginButton("Sign out", destructive: true) { confirmSignOut = true }
                        DashedDivider()
                        VStack(spacing: 6) {
                            MarginButton("Delete account", destructive: true) { confirmDeleteAccount = true }
                                .accessibilityLabel("Delete account")
                                .disabled(isDeletingAccount)
                            Text("Removes your account and everything in it, for good.")
                                .font(.setting(12).italic())
                                .foregroundColor(Theme.ink3)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.spacingMD)
                }
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    do {
                        try authManager.signOut()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
            .sheet(isPresented: $showBlocked) {
                BlockedPeopleView()
            }
            .alert("Delete account?", isPresented: $confirmDeleteAccount) {
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and everything in it: your recipes and variations, menus, shopping lists, photos, and friends. It can't be undone.")
            }
            .overlay {
                if isDeletingAccount {
                    ZStack {
                        Theme.paper.opacity(0.85).ignoresSafeArea()
                        VStack(spacing: Theme.spacingSM) {
                            ProgressView().tint(Theme.ink)
                            Text("Deleting your account…")
                                .font(.setting(14).italic())
                                .foregroundColor(Theme.ink2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAISettings) {
                AISettingsView()
            }
            .sheet(isPresented: $showFriends) {
                FriendsView(showsClose: true)
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    Task { await uploadProfileImage(image) }
                }
            }
        }
    }

    // MARK: - Header

    /// The inside cover: portrait in a ruled square, the name, where you cook.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 14)
            HStack(alignment: .center, spacing: Theme.spacingMD) {
                ZStack {
                    ProfileImagePicker(
                        selectedImage: $selectedImage,
                        currentImageURL: userService.currentUser?.profileImageURL,
                        size: 88
                    )
                    if isUploading {
                        Theme.paper.opacity(0.7)
                            .frame(width: 88, height: 88)
                        ProgressView().tint(Theme.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.plate(28))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle.uppercased())
                        .smallCaps(10, weight: .medium, tracking: 1.3)
                        .foregroundColor(Theme.ink2)
                        .lineLimit(2)
                }
            }
            Rule()
                .padding(.top, 14)
        }
        .padding(.top, Theme.spacingSM)
    }

    private var name: String {
        guard let user = userService.currentUser else { return "You" }
        if let display = user.displayName, !display.isEmpty { return display }
        return user.username
    }

    private var subtitle: String {
        guard let user = userService.currentUser else { return "" }
        return ["@\(user.username)", user.location.isEmpty ? nil : user.location].compactMap { $0 }.joined(separator: " · ")
    }

    private var lookNote: String {
        switch appearanceManager.appearanceMode {
        case .system: return "Follows your phone — paper by day, stone by night."
        case .light: return "Always the paper edition."
        case .dark: return "Always the stone edition."
        }
    }

    /// A line that opens one of the web pages — terms, privacy, help.
    private func linkLine(_ title: String, _ url: URL) -> some View {
        Link(destination: url) {
            IndexEntry(title: title, figure: "") {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.ink3)
            }
        }
        .buttonStyle(.plain)
    }

    private func kitchenLine(_ title: String, figure: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IndexEntry(title: title, figure: figure, figureColor: Theme.ink) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.ink3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete Account

    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await userService.deleteAccount()
        } catch {
            errorMessage = "Your account couldn't be deleted. Check your connection and try again.\n\n\(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Upload Image

    private func uploadProfileImage(_ image: UIImage) async {
        guard let userId = userService.currentUser?.id else { return }

        isUploading = true

        do {
            let resizedImage = image.resized(toMaxDimension: 500)
            let imageURL = try await StorageService.shared.uploadProfileImage(resizedImage, userId: userId)

            if var user = userService.currentUser {
                user.profileImageURL = imageURL
                try await userService.updateUser(user)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            selectedImage = nil
        }

        isUploading = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(TabRouter())
}
