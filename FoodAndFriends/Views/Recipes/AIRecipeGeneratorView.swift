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
    @State private var openedRecipe: Recipe?

    private var isBusy: Bool { aiService.isLoading || isSearching }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingXL) {
                    PlateHeader(title: "Ask for a recipe", subtitle: "Written up by Claude")

                    Text("Name a dish and Claude writes it up — ingredients, method and all. The box is looked through first, in case it's already in there.")
                        .font(.setting(15))
                        .foregroundColor(Theme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    inputSection

                    restrictionsSection

                    generateButton

                    if hasSearched && !searchResults.isEmpty {
                        searchResultsSection
                    }
                }
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .plainToolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MarginButton("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .navigationDestination(item: $openedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
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

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            FieldLine(
                label: "The dish",
                text: $recipeIdea,
                prompt: "beef stew, a quick pasta, something with leeks"
            )
            .submitLabel(.done)

            FieldLine(label: "Serves", text: $servings, prompt: "4", note: "optional")
                .keyboardType(.numberPad)
                .frame(width: 120)
        }
    }

    // MARK: - Restrictions Section

    private var restrictionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            SectionHead(
                title: "Keep it",
                figure: selectedRestrictions.isEmpty ? "optional" : "\(selectedRestrictions.count) chosen"
            )

            FlowLayout(spacing: 6) {
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
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Button {
                Task { await searchAndGenerate() }
            } label: {
                HStack(spacing: Theme.spacingSM) {
                    if isBusy {
                        ProgressView()
                            .tint(Theme.paper)
                    }
                    Text(aiService.isLoading ? "Writing it up…" : isSearching ? "Looking in the box…" : "Ask for a recipe")
                }
            }
            .buttonStyle(.press)
            .disabled(recipeIdea.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)

            Text("Recipes already in the box are shown first; if there's none, a new one is written.")
                .font(.setting(12).italic())
                .foregroundColor(Theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Search Results Section

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "Already in the box", figure: "\(searchResults.count)")
                .padding(.bottom, 2)

            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, recipe in
                if index > 0 {
                    DashedDivider()
                }
                ExistingRecipeCard(recipe: recipe) {
                    openedRecipe = recipe
                }
            }

            Rule()

            HStack {
                Spacer()
                MarginButton("Write a new one instead") {
                    Task { await generateNewRecipe() }
                }
                .disabled(isBusy)
                .opacity(isBusy ? 0.35 : 1)
            }
            .padding(.top, Theme.spacingMD)
        }
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
        let allRecipes = recipeService.globalRecipes.unblocked + recipeService.friendsRecipes.unblocked + recipeService.userRecipes

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

/// A dietary need, set as a small-caps word in a ruled square — inked in when chosen.
struct RestrictionChip: View {
    let restriction: DietaryRestriction
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(restriction.displayName.uppercased())
                .smallCaps(11, weight: .semibold, tracking: 1.2)
                .foregroundColor(isSelected ? Theme.paper : Theme.ink2)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(isSelected ? Theme.ink : Color.clear)
                .overlay(Rectangle().stroke(isSelected ? Theme.ink : Theme.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Existing Recipe Card

/// A recipe already in the box, set as an index line: the name in the serif,
/// whose it is underneath, the time opposite.
struct ExistingRecipeCard: View {
    let recipe: Recipe
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            IndexEntry(
                title: recipe.title,
                subtitle: recipe.authorUsername.map { "From the kitchen of @\($0)" },
                figure: recipe.totalTimeMinutes?.printedMinutes ?? "—",
                figureColor: recipe.totalTimeMinutes == nil ? Theme.ink3 : Theme.accent,
                serifTitle: true
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.ink3)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AIRecipeGeneratorView()
}
