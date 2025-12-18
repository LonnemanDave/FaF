import SwiftUI

struct UserProfileView: View {
    let user: FAFUser

    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var friendService = FriendService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var userRecipes: [Recipe] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Hero Header
                headerSection

                // Content
                VStack(spacing: FAFSpacing.lg) {
                    // Stats Cards
                    statsSection

                    // User's Recipes
                    recipesSection
                }
                .padding(.horizontal, FAFSpacing.lg)
                .padding(.top, FAFSpacing.lg)
                .padding(.bottom, FAFSpacing.xxxl)
            }
        }
        .background(Color.fafWhite)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("@\(user.username)")
                    .font(FAFTypography.h3)
                    .foregroundColor(.fafBlack)
            }
        }
        .task {
            await loadUserRecipes()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 0) {
            // Banner background
            ZStack(alignment: .bottom) {
                ProfileHeaderBackground()
                    .frame(height: 160)

                // Profile image
                ZStack {
                    Circle()
                        .fill(Color.fafWhite)
                        .frame(width: 148, height: 148)

                    if let imageURL = user.profileImageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.fafGrayXLight)
                                .overlay(
                                    FAFIcon(.profile, size: 48, color: .fafGray)
                                )
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.fafGrayXLight)
                            .frame(width: 140, height: 140)
                            .overlay(
                                FAFIcon(.profile, size: 48, color: .fafGray)
                            )
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
                .offset(y: 74)
            }

            // User Info
            VStack(spacing: FAFSpacing.xs) {
                Text(user.displayName ?? user.username)
                    .font(FAFTypography.h1)
                    .foregroundColor(.fafBlack)

                if user.displayName != nil {
                    Text("@\(user.username)")
                        .font(FAFTypography.body)
                        .foregroundColor(.fafGray)
                }

                HStack(spacing: FAFSpacing.xxxs) {
                    FAFIcon(.location, size: 14, color: .fafGrayLight)
                    Text(user.location)
                        .font(FAFTypography.bodySmall)
                        .foregroundColor(.fafGrayLight)
                }
                .padding(.top, FAFSpacing.xxxs)
            }
            .padding(.top, 80)
            .padding(.bottom, FAFSpacing.md)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: FAFSpacing.md) {
            StatCard(
                value: "\(user.friends.count)",
                label: "Friends",
                icon: .friends
            )
            StatCard(
                value: "\(userRecipes.count)",
                label: "Recipes",
                icon: .fork
            )
        }
    }

    // MARK: - Recipes Section

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Recipes")
                .font(FAFTypography.h3)
                .foregroundColor(.fafBlack)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, FAFSpacing.xl)
            } else if userRecipes.isEmpty {
                VStack(spacing: FAFSpacing.sm) {
                    FAFIcon(.fork, size: 32, color: .fafGray)
                    Text("No recipes yet")
                        .font(FAFTypography.body)
                        .foregroundColor(.fafGray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FAFSpacing.xl)
                .background(Color.fafOffWhite)
                .cornerRadius(FAFRadius.md)
            } else {
                LazyVStack(spacing: FAFSpacing.sm) {
                    ForEach(userRecipes) { recipe in
                        UserRecipeCard(recipe: recipe)
                    }
                }
            }
        }
    }

    // MARK: - Load Data

    private func loadUserRecipes() async {
        guard let userId = user.id else {
            isLoading = false
            return
        }

        do {
            userRecipes = try await recipeService.fetchRecipes(by: [userId], limit: 50)
        } catch {
            print("Error fetching user recipes: \(error)")
        }

        isLoading = false
    }
}

// MARK: - User Recipe Card

struct UserRecipeCard: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: FAFSpacing.md) {
            // Recipe image placeholder
            RoundedRectangle(cornerRadius: FAFRadius.sm)
                .fill(Color.fafGrayXLight)
                .frame(width: 60, height: 60)
                .overlay(
                    FAFIcon(.fork, size: 20, color: .fafGray)
                )

            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                Text(recipe.title)
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafBlack)
                    .lineLimit(1)

                if let time = recipe.totalTimeMinutes {
                    Label("\(time) min", systemImage: "clock")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                }
            }

            Spacer()
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.sm)
    }
}

#Preview {
    NavigationStack {
        UserProfileView(user: FAFUser(
            id: "123",
            email: "test@example.com",
            username: "johndoe",
            displayName: "John Doe",
            location: "San Francisco, CA",
            friends: ["1", "2", "3"],
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
