import SwiftUI

/// A friend's page in your journal: who they are, their figures, and the
/// recipes they've written down, set as an index you can open.
struct UserProfileView: View {
    let user: FAFUser

    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var friendService = FriendService.shared
    @ObservedObject var userService = UserService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var userRecipes: [Recipe] = []
    @State private var isLoading = true
    @State private var confirmRemove = false

    private var isFriend: Bool {
        guard let id = user.id else { return false }
        return userService.currentUser?.friends.contains(id) ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                header

                Figures(items: [
                    (label: "Friends", value: "\(user.friends.count)"),
                    (label: "Recipes", value: isLoading ? "—" : "\(userRecipes.count)"),
                    (label: "Since", value: user.createdAt.formatted(.dateTime.month(.abbreviated).year())),
                ])

                VStack(alignment: .leading, spacing: 0) {
                    SectionHead(title: "Their recipes", figure: isLoading ? nil : "\(userRecipes.count)")
                        .padding(.bottom, 2)
                    if isLoading {
                        ProgressView()
                            .tint(Theme.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacingLG)
                    } else if userRecipes.isEmpty {
                        BlankLeaf(note: "Nothing written down yet.")
                    } else {
                        let sorted = userRecipes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { position, recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                IndexEntry(
                                    title: recipe.title,
                                    subtitle: recipe.description.isEmpty ? nil : recipe.description,
                                    figure: recipe.totalTimeMinutes?.printedMinutes ?? "—",
                                    serifTitle: true
                                )
                            }
                            .buttonStyle(.plain)
                            if position < sorted.count - 1 {
                                DashedDivider()
                            }
                        }
                    }
                }

                if isFriend {
                    MarginButton("Remove from your table", destructive: true) { confirmRemove = true }
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.spacingSM)
                }
            }
            .padding(.top, Theme.spacingSM)
            .padding(.bottom, Theme.spacingXL)
            .page()
        }
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .backLeaf()
        .plainToolbar {
            if let userId = user.id, userId != UserService.shared.currentUser?.id {
                ToolbarItem(placement: .topBarTrailing) {
                    ModerationMenu(
                        subject: ReportSubject(target: .user, targetId: userId, authorId: userId,
                                               authorUsername: user.username, label: "@\(user.username)"),
                        onBlocked: { dismiss() }
                    )
                }
            }
        }
        .task { await loadUserRecipes() }
        .confirmationDialog("Remove @\(user.username)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove from your table", role: .destructive) {
                Task { await removeFriend() }
            }
        } message: {
            Text("You'll stop seeing each other's cooking. You can ask them back any time.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 12)
            HStack(alignment: .center, spacing: Theme.spacingMD) {
                Monogram(name: user.displayName ?? user.username, imageURL: user.profileImageURL, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName ?? user.username)
                        .font(.plate(28))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(["@\(user.username)", user.location.isEmpty ? nil : user.location]
                        .compactMap { $0 }.joined(separator: " · ").uppercased())
                        .smallCaps(10, weight: .medium, tracking: 1.3)
                        .foregroundColor(Theme.ink2)
                        .lineLimit(1)
                }
            }
            Rule()
                .padding(.top, 12)
        }
    }

    // MARK: - Data

    private func loadUserRecipes() async {
        guard let userId = user.id else {
            isLoading = false
            return
        }
        #if DEBUG
        if DesignHarness.isOn {
            userRecipes = recipeService.globalRecipes.filter { $0.authorId == userId }
            isLoading = false
            return
        }
        #endif
        do {
            userRecipes = try await recipeService.fetchRecipes(by: [userId], limit: 50, publicOnly: !isFriend)
        } catch {
            print("Error fetching user recipes: \(error)")
        }
        isLoading = false
    }

    private func removeFriend() async {
        guard let me = userService.currentUser?.id, let friendId = user.id else { return }
        do {
            try await friendService.removeFriend(currentUserId: me, friendId: friendId)
            dismiss()
        } catch {
            print("Error removing friend: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(user: FAFUser(
            id: "123", email: "test@example.com", username: "johndoe", displayName: "John Doe",
            location: "San Francisco, CA", friends: ["1", "2", "3"], createdAt: Date(), updatedAt: Date()
        ))
    }
}
