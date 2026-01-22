import SwiftUI

struct RecipesView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var friendService = FriendService.shared
    @ObservedObject var aiService = AIService.shared

    @State private var selectedFilter: RecipeFilter = .mine
    @State private var showCreateRecipe = false
    @State private var showAIGenerator = false

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
            ZStack {
                Color.fafBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    filterTabs
                        .padding(.horizontal, FAFSpacing.lg)
                        .padding(.vertical, FAFSpacing.sm)

                    Group {
                        if recipeService.isLoading {
                            RecipesLoadingView()
                        } else if displayedRecipes.isEmpty {
                            EmptyRecipesView(filter: selectedFilter, onCreateRecipe: { showCreateRecipe = true })
                        } else {
                            RecipesList(recipes: displayedRecipes)
                        }
                    }
                }
            }
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
                    HStack(spacing: FAFSpacing.md) {
                        if aiService.hasValidAPIKey {
                            Button {
                                showAIGenerator = true
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18))
                                    .foregroundColor(.fafSage)
                            }
                        }
                        Button {
                            showCreateRecipe = true
                        } label: {
                            FAFIcon(.plus, size: 20, color: .fafCoral)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateRecipe) {
                CreateRecipeView()
            }
            .sheet(isPresented: $showAIGenerator) {
                AIRecipeGeneratorView()
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

    private func seedBeefStew() async {
        guard let user = userService.currentUser else { return }
        do {
            try await recipeService.seedBeefStewRecipe(author: user)
            // Listeners will automatically update the UI
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
                // Recipe image
                Group {
                    if let imageURL = recipe.firstImageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                recipePlaceholder
                            @unknown default:
                                recipePlaceholder
                            }
                        }
                    } else {
                        recipePlaceholder
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: FAFRadius.sm))

                VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                    Text(recipe.title)
                        .font(FAFTypography.bodyBold)
                        .foregroundColor(.fafTextPrimary)
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
            .background(Color.fafCardBackground)
            .cornerRadius(FAFRadius.md)
        }
        .buttonStyle(.plain)
    }

    private var recipePlaceholder: some View {
        Rectangle()
            .fill(Color.fafGrayXLight)
            .overlay(
                FAFIcon(.fork, size: 24, color: .fafGray)
            )
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
                    .foregroundColor(.fafTextPrimary)

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
                    .background(Color.fafCardBackground)
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
