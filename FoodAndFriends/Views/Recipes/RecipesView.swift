import SwiftUI

/// Recipes — the index at the back of the cookbook. Your recipes, your
/// friends', or everyone's, set A to Z under letter heads, each with its
/// time carried across on a dot leader. Search finds a recipe by its name,
/// what's in it, or how it's tagged.
struct RecipesView: View {
    @ObservedObject var userService = UserService.shared
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var aiService = AIService.shared
    @ObservedObject var moderation = ModerationService.shared

    @State private var selectedFilter: RecipeFilter = .mine
    @State private var query = ""
    @State private var showCreateRecipe = false
    @State private var showAIGenerator = false

    enum RecipeFilter: String, CaseIterable {
        case mine = "Mine"
        case friends = "Friends"
        case global = "Everyone"
    }

    private func recipes(for filter: RecipeFilter) -> [Recipe] {
        switch filter {
        case .mine: return recipeService.userRecipes
        case .friends: return recipeService.friendsRecipes.unblocked
        case .global: return recipeService.globalRecipes.unblocked
        }
    }

    /// The chosen shelf, narrowed by the search.
    private var displayedRecipes: [Recipe] {
        let shelf = recipes(for: selectedFilter)
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return shelf }
        return shelf.filter { recipe in
            let haystack = ([recipe.title, recipe.description] + recipe.tags + recipe.ingredients.map(\.name))
                .joined(separator: " ")
                .lowercased()
            return words.allSatisfy(haystack.contains)
        }
    }

    /// A to Z under letter heads; anything not starting with a letter under "#".
    private var letters: [(letter: String, recipes: [Recipe])] {
        Dictionary(grouping: displayedRecipes) { recipe -> String in
            guard let first = recipe.title.trimmingCharacters(in: .whitespaces).first, first.isLetter else { return "#" }
            return String(first).uppercased()
        }
        .map { (letter: $0.key, recipes: $0.value.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) }
        .sorted { lhs, rhs in
            lhs.letter == "#" ? false : (rhs.letter == "#" ? true : lhs.letter < rhs.letter)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    plate

                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        IndexSelector(
                            options: RecipeFilter.allCases.map { (value: $0, label: $0.rawValue) },
                            selection: $selectedFilter
                        ) {
                            Text("\(recipes(for: selectedFilter).count)")
                                .font(.figure(11, .medium))
                                .foregroundColor(Theme.ink3)
                                .padding(.bottom, 7)
                        }
                        SearchLine(placeholder: "A recipe, an ingredient, a tag", text: $query)
                    }

                    index
                }
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingXL)
                .page()
            }
            .background(Theme.paper)
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.immediately)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $showCreateRecipe) {
                CreateRecipeView()
            }
            .sheet(isPresented: $showAIGenerator) {
                AIRecipeGeneratorView()
            }
        }
    }

    // MARK: - Plate

    private var plusMark: some View {
        Image(systemName: "plus")
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(Theme.ink)
            .frame(width: 36, height: 36, alignment: .trailing)
            .contentShape(Rectangle())
    }

    private var plate: some View {
        VStack(alignment: .leading, spacing: 0) {
            DoubleRule()
                .padding(.bottom, 12)

            HStack(alignment: .firstTextBaseline) {
                Text("Recipes")
                    .font(.plate(32))
                    .foregroundColor(Theme.ink)

                Spacer(minLength: Theme.spacingSM)

                // With the assistant, + offers a choice; without it, + just opens the form.
                if aiService.hasValidAPIKey {
                    Menu {
                        Button {
                            showCreateRecipe = true
                        } label: {
                            Label("Write a recipe", systemImage: "square.and.pencil")
                        }
                        Button {
                            showAIGenerator = true
                        } label: {
                            Label("Ask for a recipe", systemImage: "sparkles")
                        }
                    } label: {
                        plusMark
                    }
                    .accessibilityLabel("Add a recipe")
                } else {
                    Button {
                        showCreateRecipe = true
                    } label: {
                        plusMark
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a recipe")
                }
            }

            Text(edition.uppercased())
                .smallCaps(10, weight: .medium, tracking: 1.4)
                .foregroundColor(Theme.ink2)
                .padding(.top, 4)

            Rule()
                .padding(.top, 12)
        }
        .padding(.top, Theme.spacingSM)
    }

    /// The line under the title — how full the box is.
    private var edition: String {
        let count = recipeService.userRecipes.count
        switch count {
        case 0: return "The recipe box · empty so far"
        case 1: return "The recipe box · 1 written down"
        default: return "The recipe box · \(count) written down"
        }
    }

    // MARK: - The index

    @ViewBuilder
    private var index: some View {
        if recipeService.isLoading && displayedRecipes.isEmpty {
            ProgressView()
                .tint(Theme.ink3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacingXL)
        } else if displayedRecipes.isEmpty {
            emptyLeaf
        } else {
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                ForEach(letters, id: \.letter) { chapter in
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHead(title: chapter.letter, figure: "\(chapter.recipes.count)")
                            .padding(.bottom, 2)
                        ForEach(Array(chapter.recipes.enumerated()), id: \.element.id) { position, recipe in
                            NavigationLink(value: recipe) {
                                IndexEntry(
                                    title: recipe.title,
                                    subtitle: subtitle(for: recipe),
                                    figure: recipe.totalTimeMinutes?.printedMinutes ?? "—",
                                    serifTitle: true
                                )
                            }
                            .buttonStyle(.plain)

                            if position < chapter.recipes.count - 1 {
                                DashedDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    /// Under the name: the recipe's own line — and whose it is, when it isn't yours.
    private func subtitle(for recipe: Recipe) -> String? {
        let mine = recipe.authorId == userService.currentUser?.id
        let author = mine ? nil : recipe.authorUsername.map { "@\($0)" }
        let description = recipe.description.isEmpty ? nil : recipe.description
        let parts = [author, description].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var emptyLeaf: some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            BlankLeaf(note: "Nothing in \(selectedFilter == .mine ? "your box" : "here") for \"\(query)\".")
        } else {
            switch selectedFilter {
            case .mine:
                BlankLeaf(
                    note: "No recipes written down yet.",
                    action: (label: "Write one", run: { showCreateRecipe = true })
                )
            case .friends:
                BlankLeaf(note: "When friends write down a recipe, it's filed here.")
            case .global:
                BlankLeaf(note: "No one has shared a recipe with everyone yet.")
            }
        }
    }
}

#Preview {
    RecipesView()
}
