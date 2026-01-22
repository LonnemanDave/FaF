import SwiftUI

struct AIRecipeGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var aiService = AIService.shared
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared

    var initialRecipeIdea: String = ""

    @State private var recipeIdea = ""
    @State private var servings = ""
    @State private var selectedRestrictions: Set<DietaryRestriction> = []

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var generatedRecipe: Recipe?
    @State private var showCreateRecipe = false

    // Search state
    @State private var searchResults: [Recipe] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: FAFSpacing.lg) {
                    // Header
                    headerSection

                    // Input Section
                    inputSection

                    // Dietary Restrictions
                    restrictionsSection

                    // Generate Button
                    generateButton

                    // Search Results
                    if hasSearched && !searchResults.isEmpty {
                        searchResultsSection
                    }
                }
                .padding(FAFSpacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fafBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        FAFIcon(.close, size: 20, color: .fafGrayDark)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("AI Recipe Generator")
                        .font(FAFTypography.h3)
                        .foregroundColor(.fafTextPrimary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showCreateRecipe) {
                if let recipe = generatedRecipe {
                    CreateRecipeView(aiDraftRecipe: recipe)
                }
            }
            .onAppear {
                if !initialRecipeIdea.isEmpty && recipeIdea.isEmpty {
                    recipeIdea = initialRecipeIdea
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: FAFSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.fafSage.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(.fafSage)
            }

            VStack(spacing: FAFSpacing.xs) {
                Text("What would you like to cook?")
                    .font(FAFTypography.h2)
                    .foregroundColor(.fafTextPrimary)

                Text("Describe a dish and Claude will create a complete recipe for you.")
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                Text("Recipe Idea")
                    .font(FAFTypography.label)
                    .foregroundColor(.fafGrayDark)

                TextField("e.g., beef stew, quick pasta, healthy salad", text: $recipeIdea)
                    .font(FAFTypography.body)
                    .padding(FAFSpacing.md)
                    .background(Color.fafInputBackground)
                    .cornerRadius(FAFRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: FAFRadius.md)
                            .stroke(Color.fafDivider, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                Text("Servings (optional)")
                    .font(FAFTypography.label)
                    .foregroundColor(.fafGrayDark)

                TextField("e.g., 4", text: $servings)
                    .font(FAFTypography.body)
                    .keyboardType(.numberPad)
                    .padding(FAFSpacing.md)
                    .background(Color.fafInputBackground)
                    .cornerRadius(FAFRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: FAFRadius.md)
                            .stroke(Color.fafDivider, lineWidth: 1)
                    )
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Restrictions Section

    private var restrictionsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Dietary Restrictions (optional)")
                .font(FAFTypography.label)
                .foregroundColor(.fafGrayDark)

            FlowLayout(spacing: FAFSpacing.sm) {
                ForEach(DietaryRestriction.allCases) { restriction in
                    RestrictionChip(
                        restriction: restriction,
                        isSelected: selectedRestrictions.contains(restriction)
                    ) {
                        if selectedRestrictions.contains(restriction) {
                            selectedRestrictions.remove(restriction)
                        } else {
                            selectedRestrictions.insert(restriction)
                        }
                    }
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        VStack(spacing: FAFSpacing.sm) {
            Button {
                Task { await searchAndGenerate() }
            } label: {
                HStack(spacing: FAFSpacing.sm) {
                    if aiService.isLoading || isSearching {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                    }
                    Text(aiService.isLoading ? "Generating..." : isSearching ? "Searching..." : "Generate Recipe")
                        .font(FAFTypography.button)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FAFSpacing.md)
                .background(recipeIdea.isEmpty ? Color.fafGray : Color.fafSage)
                .cornerRadius(FAFRadius.md)
            }
            .disabled(recipeIdea.isEmpty || aiService.isLoading || isSearching)

            Text("We'll first search existing recipes, then generate if needed")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
        }
    }

    // MARK: - Search Results Section

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            HStack {
                Text("Existing Recipes Found")
                    .font(FAFTypography.h3)
                    .foregroundColor(.fafTextPrimary)

                Spacer()

                Button {
                    Task { await generateNewRecipe() }
                } label: {
                    Text("Generate New Instead")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafSage)
                }
            }

            ForEach(searchResults) { recipe in
                ExistingRecipeCard(recipe: recipe) {
                    // User selected an existing recipe - could navigate to it
                    dismiss()
                }
            }
        }
        .padding(FAFSpacing.lg)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.lg)
    }

    // MARK: - Actions

    private func searchAndGenerate() async {
        isSearching = true
        hasSearched = true

        // Search existing recipes
        let results = await searchExistingRecipes(query: recipeIdea)
        searchResults = results

        isSearching = false

        // If no results, generate new recipe
        if results.isEmpty {
            await generateNewRecipe()
        }
    }

    private func searchExistingRecipes(query: String) async -> [Recipe] {
        // Search in global recipes by title
        let lowercaseQuery = query.lowercased()

        // Combine all available recipes
        let allRecipes = recipeService.globalRecipes + recipeService.friendsRecipes + recipeService.userRecipes

        // Simple search - title or tags contain query
        let matches = allRecipes.filter { recipe in
            recipe.title.lowercased().contains(lowercaseQuery) ||
            recipe.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }

        // Return top 3 matches
        return Array(matches.prefix(3))
    }

    private func generateNewRecipe() async {
        guard let userId = userService.currentUser?.id else {
            errorMessage = "Please sign in to generate recipes"
            showError = true
            return
        }

        do {
            let servingsInt = Int(servings)
            let restrictions = Array(selectedRestrictions)

            let generated = try await aiService.generateRecipe(
                name: recipeIdea,
                servings: servingsInt,
                dietaryRestrictions: restrictions
            )

            // Convert to app Recipe model
            generatedRecipe = aiService.convertToRecipe(generated, authorId: userId)
            showCreateRecipe = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Restriction Chip

struct RestrictionChip: View {
    let restriction: DietaryRestriction
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(restriction.displayName)
                .font(FAFTypography.caption)
                .foregroundColor(isSelected ? .white : .fafTextPrimary)
                .padding(.horizontal, FAFSpacing.md)
                .padding(.vertical, FAFSpacing.sm)
                .background(isSelected ? Color.fafSage : Color.fafBackgroundSecondary)
                .cornerRadius(FAFRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.full)
                        .stroke(isSelected ? Color.fafSage : Color.fafDivider, lineWidth: 1)
                )
        }
    }
}

// MARK: - Existing Recipe Card

struct ExistingRecipeCard: View {
    let recipe: Recipe
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FAFSpacing.md) {
                // Recipe image or placeholder
                if let imageURL = recipe.firstImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.fafGrayXLight
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(FAFRadius.sm)
                } else {
                    ZStack {
                        Color.fafGrayXLight
                        Image(systemName: "fork.knife")
                            .foregroundColor(.fafGray)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(FAFRadius.sm)
                }

                VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                    Text(recipe.title)
                        .font(FAFTypography.bodyBold)
                        .foregroundColor(.fafTextPrimary)
                        .lineLimit(1)

                    if let author = recipe.authorUsername {
                        Text("by @\(author)")
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafGray)
                    }

                    if let time = recipe.totalTimeMinutes {
                        HStack(spacing: FAFSpacing.xxs) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text("\(time) min")
                                .font(FAFTypography.caption)
                        }
                        .foregroundColor(.fafGrayLight)
                    }
                }

                Spacer()

                FAFIcon(.forward, size: 16, color: .fafGrayLight)
            }
            .padding(FAFSpacing.md)
            .background(Color.fafBackgroundSecondary)
            .cornerRadius(FAFRadius.md)
        }
    }
}

#Preview {
    AIRecipeGeneratorView()
}
