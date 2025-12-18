import SwiftUI

struct RecipesView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared

    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            Group {
                if !hasLoaded || recipeService.isLoading {
                    RecipesLoadingView()
                } else if recipeService.userRecipes.isEmpty {
                    EmptyRecipesView()
                } else {
                    RecipesList(recipes: recipeService.userRecipes)
                }
            }
            .background(Color.fafWhite)
            .navigationTitle("My Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Navigate to create recipe
                    } label: {
                        FAFIcon(.plus, size: 20, color: .fafCoral)
                    }
                }
            }
            .task {
                if !hasLoaded {
                    await loadRecipes()
                    hasLoaded = true
                }
            }
            .refreshable {
                await loadRecipes()
            }
        }
    }

    private func loadRecipes() async {
        guard let userId = userService.currentUser?.id else { return }
        await recipeService.fetchUserRecipes(userId: userId)
    }
}

// MARK: - Recipes List

struct RecipesList: View {
    let recipes: [Recipe]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: FAFSpacing.md) {
                ForEach(recipes) { recipe in
                    RecipeRowCard(recipe: recipe)
                }
            }
            .padding(.horizontal, FAFSpacing.lg)
            .padding(.vertical, FAFSpacing.md)
        }
    }
}

struct RecipeRowCard: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: FAFSpacing.md) {
            // Recipe image placeholder
            RoundedRectangle(cornerRadius: FAFRadius.sm)
                .fill(Color.fafGrayXLight)
                .frame(width: 80, height: 80)
                .overlay(
                    FAFIcon(.fork, size: 24, color: .fafGray)
                )

            VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                Text(recipe.title)
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafBlack)
                    .lineLimit(2)

                if !recipe.description.isEmpty {
                    Text(recipe.description)
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                        .lineLimit(2)
                }

                HStack(spacing: FAFSpacing.md) {
                    if let time = recipe.totalTimeMinutes {
                        Label("\(time) min", systemImage: "clock")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafGray)
                    }

                    if let servings = recipe.servings {
                        Label("\(servings)", systemImage: "person.2")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafGray)
                    }
                }
            }

            Spacer()

            FAFIcon(.forward, size: 16, color: .fafGray)
        }
        .padding(FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }
}

// MARK: - Empty State

struct EmptyRecipesView: View {
    var body: some View {
        VStack(spacing: FAFSpacing.lg) {
            Spacer()

            VStack(spacing: FAFSpacing.md) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 64))
                    .foregroundColor(.fafGrayLight)

                Text("No Recipes Yet")
                    .font(FAFTypography.h2)
                    .foregroundColor(.fafBlack)

                Text("Start building your recipe collection\nby adding your first recipe")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .multilineTextAlignment(.center)
            }

            Button {
                // TODO: Navigate to create recipe
            } label: {
                HStack(spacing: FAFSpacing.sm) {
                    FAFIcon(.plus, size: 16, color: .fafWhite)
                    Text("Create Recipe")
                        .font(FAFTypography.button)
                }
                .foregroundColor(.fafWhite)
                .padding(.horizontal, FAFSpacing.xl)
                .padding(.vertical, FAFSpacing.md)
                .background(Color.fafCoral)
                .cornerRadius(FAFRadius.md)
            }

            Spacer()
        }
        .padding(FAFSpacing.lg)
    }
}

// MARK: - Loading State

struct RecipesLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: FAFSpacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: FAFSpacing.md) {
                        RoundedRectangle(cornerRadius: FAFRadius.sm)
                            .fill(Color.fafGrayXLight)
                            .frame(width: 80, height: 80)

                        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.fafGrayXLight)
                                .frame(height: 16)
                                .frame(maxWidth: 150)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.fafGrayXXLight)
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.fafGrayXXLight)
                                .frame(height: 12)
                                .frame(maxWidth: 100)
                        }

                        Spacer()
                    }
                    .padding(FAFSpacing.md)
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.md)
                }
            }
            .padding(.horizontal, FAFSpacing.lg)
            .padding(.vertical, FAFSpacing.md)
        }
        .redacted(reason: .placeholder)
    }
}

#Preview {
    RecipesView()
}
