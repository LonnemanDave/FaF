import SwiftUI

struct RecipesView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var friendService = FriendService.shared

    @State private var hasLoaded = false
    @State private var selectedFilter: RecipeFilter = .mine
    @State private var showCreateRecipe = false

    enum RecipeFilter: String, CaseIterable {
        case global = "Global"
        case friends = "Friends"
        case mine = "Mine"
    }

    private var displayedRecipes: [Recipe] {
        switch selectedFilter {
        case .global:
            return recipeService.globalRecipes
        case .friends:
            return recipeService.friendsRecipes
        case .mine:
            return recipeService.userRecipes
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterTabs
                    .padding(.horizontal, FAFSpacing.lg)
                    .padding(.vertical, FAFSpacing.sm)

                Group {
                    if !hasLoaded || recipeService.isLoading {
                        RecipesLoadingView()
                    } else if displayedRecipes.isEmpty {
                        EmptyRecipesView(filter: selectedFilter, onCreateRecipe: { showCreateRecipe = true })
                    } else {
                        RecipesList(recipes: displayedRecipes)
                    }
                }
            }
            .background(Color.fafWhite)
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await seedBeefStew() }
                    } label: {
                        Text("Seed")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafGray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateRecipe = true
                    } label: {
                        FAFIcon(.plus, size: 20, color: .fafCoral)
                    }
                }
            }
            .sheet(isPresented: $showCreateRecipe, onDismiss: {
                Task { await loadRecipes() }
            }) {
                CreateRecipeView()
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
            .onChange(of: recipeService.needsRefresh) { _, needsRefresh in
                if needsRefresh {
                    Task {
                        await loadRecipes()
                        recipeService.needsRefresh = false
                    }
                }
            }
        }
    }

    private var filterTabs: some View {
        HStack(spacing: FAFSpacing.sm) {
            ForEach(RecipeFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(FAFTypography.button)
                        .foregroundColor(selectedFilter == filter ? .fafWhite : .fafGray)
                        .padding(.horizontal, FAFSpacing.md)
                        .padding(.vertical, FAFSpacing.xs)
                        .background(
                            Capsule()
                                .fill(selectedFilter == filter ? Color.fafCoral : Color.fafGrayXLight)
                        )
                }
            }
            Spacer()
        }
    }

    private func loadRecipes() async {
        guard let userId = userService.currentUser?.id else { return }

        if friendService.friends.isEmpty {
            await friendService.fetchFriends(for: userId)
        }

        async let userRecipes: () = recipeService.fetchUserRecipes(userId: userId)
        async let friendsRecipes: () = recipeService.fetchFriendsRecipes(
            friendIds: friendService.friends.compactMap { $0.id }
        )
        async let globalRecipes: () = recipeService.fetchGlobalRecipes()

        _ = await (userRecipes, friendsRecipes, globalRecipes)
    }

    private func seedBeefStew() async {
        guard let user = userService.currentUser else { return }
        do {
            try await recipeService.seedBeefStewRecipe(author: user)
            await loadRecipes()
        } catch {
            print("Error seeding beef stew: \(error)")
        }
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
        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
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
            }
            .padding(FAFSpacing.md)
            .background(Color.fafOffWhite)
            .cornerRadius(FAFRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct EmptyRecipesView: View {
    let filter: RecipesView.RecipeFilter
    var onCreateRecipe: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: FAFSpacing.lg) {
            Spacer()

            VStack(spacing: FAFSpacing.md) {
                Image(systemName: iconName)
                    .font(.system(size: 64))
                    .foregroundColor(.fafGrayLight)

                Text(titleText)
                    .font(FAFTypography.h2)
                    .foregroundColor(.fafBlack)

                Text(subtitleText)
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .multilineTextAlignment(.center)
            }

            if filter == .mine {
                Button {
                    onCreateRecipe?()
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
            }

            Spacer()
        }
        .padding(FAFSpacing.lg)
    }

    private var iconName: String {
        switch filter {
        case .global: return "globe"
        case .friends: return "person.2"
        case .mine: return "fork.knife"
        }
    }

    private var titleText: String {
        switch filter {
        case .global: return "No Public Recipes"
        case .friends: return "No Friend Recipes"
        case .mine: return "No Recipes Yet"
        }
    }

    private var subtitleText: String {
        switch filter {
        case .global: return "Be the first to share a recipe\nwith the community"
        case .friends: return "Your friends haven't shared\nany recipes yet"
        case .mine: return "Start building your recipe collection\nby adding your first recipe"
        }
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
