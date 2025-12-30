import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var userService = UserService.shared
    @ObservedObject var friendService = FriendService.shared

    let recipe: Recipe

    @State private var showEditSheet = false
    @State private var showVariationSheet = false
    @State private var variations: [RecipeVariation] = []
    @State private var selectedVariation: RecipeVariation?
    @State private var isLoadingVariations = false

    private var isOwner: Bool {
        userService.currentUser?.id == recipe.authorId
    }

    private var currentIngredients: [Ingredient] {
        selectedVariation?.ingredients ?? recipe.ingredients
    }

    private var currentSteps: [RecipeStep] {
        selectedVariation?.sortedSteps ?? recipe.sortedSteps
    }

    private func ingredientsForStep(_ step: RecipeStep) -> [Ingredient] {
        let allIngredients = currentIngredients
        return allIngredients.filter { step.ingredientIds.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                recipeImage

                VStack(alignment: .leading, spacing: FAFSpacing.lg) {
                    // Title & Meta
                    headerSection

                    // Quick Stats
                    statsSection

                    // Chef Selector (only show if variations exist)
                    if !variations.isEmpty {
                        chefSelectorSection
                    }

                    // Variation notes (if viewing a variation)
                    if let variation = selectedVariation, !variation.notes.isEmpty {
                        variationNotesSection(for: variation)
                    }

                    Divider()

                    // Ingredients
                    ingredientsSection

                    Divider()

                    // Instructions
                    instructionsSection

                    // Tags
                    if !recipe.tags.isEmpty {
                        Divider()
                        tagsSection
                    }

                    // Add Variation Button (for non-owners who haven't added one yet)
                    if !isOwner && !hasUserVariation {
                        addVariationButton
                    }
                }
                .padding(FAFSpacing.lg)
            }
        }
        .background(Color.fafWhite)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.fafCoral)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            CreateRecipeView(recipeToEdit: recipe, onDelete: {
                dismiss()
            })
        }
        .sheet(isPresented: $showVariationSheet) {
            CreateRecipeView(baseRecipeForVariation: recipe)
        }
        .task {
            await loadVariations()
        }
    }

    private var hasUserVariation: Bool {
        guard let userId = userService.currentUser?.id else { return false }
        return variations.contains { $0.authorId == userId }
    }

    private func loadVariations() async {
        guard let recipeId = recipe.id else { return }
        isLoadingVariations = true
        do {
            let friendIds = friendService.friends.compactMap { $0.id }
            let allVariations = try await recipeService.fetchVariations(for: recipeId, friendIds: friendIds)
            // Filter out variations from the recipe owner (handles edge case after promotion)
            variations = allVariations.filter { $0.authorId != recipe.authorId }
        } catch {
            print("Error loading variations: \(error)")
        }
        isLoadingVariations = false
    }

    // MARK: - Chef Selector

    private var chefSelectorSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            Text("Chef Variations")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FAFSpacing.sm) {
                    // Original recipe pill
                    Button {
                        selectedVariation = nil
                    } label: {
                        HStack(spacing: FAFSpacing.xs) {
                            if selectedVariation == nil {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text("Original")
                                .font(FAFTypography.caption)
                            if let author = recipe.authorUsername {
                                Text("@\(author)")
                                    .font(FAFTypography.caption)
                                    .opacity(0.7)
                            }
                        }
                        .foregroundColor(selectedVariation == nil ? .fafWhite : .fafGray)
                        .padding(.horizontal, FAFSpacing.md)
                        .padding(.vertical, FAFSpacing.sm)
                        .background(selectedVariation == nil ? Color.fafCoral : Color.fafGrayXLight)
                        .cornerRadius(FAFRadius.full)
                    }

                    // Variation pills
                    ForEach(variations) { variation in
                        Button {
                            selectedVariation = variation
                        } label: {
                            HStack(spacing: FAFSpacing.xs) {
                                if selectedVariation?.id == variation.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                if let author = variation.authorUsername {
                                    Text("@\(author)")
                                        .font(FAFTypography.caption)
                                }
                                if variation.likeCount > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 8))
                                        Text("\(variation.likeCount)")
                                            .font(FAFTypography.caption)
                                    }
                                    .opacity(0.7)
                                }
                            }
                            .foregroundColor(selectedVariation?.id == variation.id ? .fafWhite : .fafGray)
                            .padding(.horizontal, FAFSpacing.md)
                            .padding(.vertical, FAFSpacing.sm)
                            .background(selectedVariation?.id == variation.id ? Color.fafCoral : Color.fafGrayXLight)
                            .cornerRadius(FAFRadius.full)
                        }
                    }
                }
            }
        }
    }

    private func variationNotesSection(for variation: RecipeVariation) -> some View {
        VStack(alignment: .leading, spacing: FAFSpacing.xs) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundColor(.fafSage)
                Text("Chef's Notes")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)

                Spacer()

                // Like button
                Button {
                    Task { await likeVariation(variation) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.system(size: 14))
                        if variation.likeCount > 0 {
                            Text("\(variation.likeCount)")
                                .font(FAFTypography.caption)
                        }
                    }
                    .foregroundColor(.fafCoral)
                }

                // Promote button (owner only)
                if isOwner {
                    Button {
                        Task { await promoteVariation(variation) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 14))
                            Text("Promote")
                                .font(FAFTypography.caption)
                        }
                        .foregroundColor(.fafSage)
                    }
                }
            }

            Text(variation.notes)
                .font(FAFTypography.body)
                .foregroundColor(.fafBlack)
                .italic()
        }
        .padding(FAFSpacing.md)
        .background(Color.fafSage.opacity(0.1))
        .cornerRadius(FAFRadius.md)
    }

    private var addVariationButton: some View {
        Button {
            showVariationSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                Text("Add Your Variation")
                    .font(FAFTypography.button)
            }
            .foregroundColor(.fafCoral)
            .frame(maxWidth: .infinity)
            .padding(FAFSpacing.md)
            .background(Color.fafCoral.opacity(0.1))
            .cornerRadius(FAFRadius.md)
        }
        .padding(.top, FAFSpacing.md)
    }

    private func likeVariation(_ variation: RecipeVariation) async {
        guard let recipeId = recipe.id else { return }
        do {
            try await recipeService.likeVariation(variation, recipeId: recipeId)
            await loadVariations()
        } catch {
            print("Error liking variation: \(error)")
        }
    }

    private func promoteVariation(_ variation: RecipeVariation) async {
        guard let user = userService.currentUser else { return }
        do {
            try await recipeService.promoteVariation(variation, recipe: recipe, currentUser: user)
            dismiss()
        } catch {
            print("Error promoting variation: \(error)")
        }
    }

    // MARK: - Hero Image

    private var recipeImage: some View {
        ZStack {
            Rectangle()
                .fill(Color.fafGrayXLight)
                .frame(height: 250)

            if let imageURL = recipe.firstImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    FAFIcon(.fork, size: 48, color: .fafGray)
                }
                .frame(height: 250)
                .clipped()
            } else {
                VStack(spacing: FAFSpacing.sm) {
                    FAFIcon(.fork, size: 48, color: .fafGray)
                    Text("No photo")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            Text(recipe.title)
                .font(FAFTypography.h1)
                .foregroundColor(.fafBlack)

            if !recipe.description.isEmpty {
                Text(recipe.description)
                    .font(FAFTypography.body)
                    .foregroundColor(.fafGray)
            }

            // Author info
            if let authorUsername = recipe.authorUsername {
                HStack(spacing: FAFSpacing.xs) {
                    Circle()
                        .fill(Color.fafGrayXLight)
                        .frame(width: 24, height: 24)
                        .overlay(
                            FAFIcon(.profile, size: 12, color: .fafGray)
                        )
                    Text("@\(authorUsername)")
                        .font(FAFTypography.caption)
                        .foregroundColor(.fafGray)
                }
                .padding(.top, FAFSpacing.xs)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: FAFSpacing.lg) {
            if let prepTime = recipe.prepTimeMinutes {
                StatItem(icon: "clock", label: "Prep", value: "\(prepTime) min")
            }

            if let cookTime = recipe.cookTimeMinutes {
                StatItem(icon: "flame", label: "Cook", value: "\(cookTime) min")
            }

            if let servings = recipe.servings {
                StatItem(icon: "person.2", label: "Serves", value: "\(servings)")
            }
        }
        .padding(FAFSpacing.md)
        .frame(maxWidth: .infinity)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Ingredients")
                .font(FAFTypography.h2)
                .foregroundColor(.fafBlack)

            VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                ForEach(currentIngredients) { ingredient in
                    HStack(alignment: .top, spacing: FAFSpacing.sm) {
                        Circle()
                            .fill(Color.fafCoral)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(ingredient.displayString)
                            .font(FAFTypography.body)
                            .foregroundColor(.fafBlack)
                    }
                }
            }
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            Text("Instructions")
                .font(FAFTypography.h2)
                .foregroundColor(.fafBlack)

            VStack(alignment: .leading, spacing: FAFSpacing.xl) {
                if !currentSteps.isEmpty {
                    // New format with per-step ingredients
                    ForEach(Array(currentSteps.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                            HStack(alignment: .top, spacing: FAFSpacing.md) {
                                Text("\(index + 1)")
                                    .font(FAFTypography.h3)
                                    .foregroundColor(.fafWhite)
                                    .frame(width: 28, height: 28)
                                    .background(Color.fafCoral)
                                    .clipShape(Circle())

                                Text(step.instruction)
                                    .font(FAFTypography.body)
                                    .foregroundColor(.fafBlack)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Per-step ingredients
                            let stepIngredients = ingredientsForStep(step)
                            if !stepIngredients.isEmpty {
                                VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                                    ForEach(stepIngredients) { ingredient in
                                        HStack(spacing: FAFSpacing.sm) {
                                            Circle()
                                                .fill(Color.fafSage)
                                                .frame(width: 4, height: 4)
                                            Text(ingredient.displayString)
                                                .font(FAFTypography.caption)
                                                .foregroundColor(.fafGray)
                                        }
                                    }
                                }
                                .padding(.leading, 40)
                            }
                        }
                    }
                } else if let instructions = recipe.instructions {
                    // Old format fallback
                    ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: FAFSpacing.md) {
                            Text("\(index + 1)")
                                .font(FAFTypography.h3)
                                .foregroundColor(.fafWhite)
                                .frame(width: 28, height: 28)
                                .background(Color.fafCoral)
                                .clipShape(Circle())

                            Text(instruction)
                                .font(FAFTypography.body)
                                .foregroundColor(.fafBlack)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            Text("Tags")
                .font(FAFTypography.h3)
                .foregroundColor(.fafBlack)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FAFSpacing.xs) {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text(tag)
                            .font(FAFTypography.caption)
                            .foregroundColor(.fafGray)
                            .padding(.horizontal, FAFSpacing.sm)
                            .padding(.vertical, FAFSpacing.xxs)
                            .background(Color.fafGrayXLight)
                            .cornerRadius(FAFRadius.sm)
                    }
                }
            }
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: FAFSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.fafCoral)

            Text(value)
                .font(FAFTypography.bodyBold)
                .foregroundColor(.fafBlack)

            Text(label)
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let beef = Ingredient(name: "beef chuck", quantity: "2", unit: "lbs")
    let potatoes = Ingredient(name: "potatoes", quantity: "4", unit: "medium")
    let carrots = Ingredient(name: "carrots", quantity: "3", unit: "large")

    return NavigationStack {
        RecipeDetailView(recipe: Recipe(
            authorId: "123",
            title: "Classic Beef Stew",
            description: "A hearty, warming beef stew with tender chunks of beef and vegetables.",
            ingredients: [beef, potatoes, carrots],
            steps: [
                RecipeStep(instruction: "Cut beef into cubes and season with salt.", ingredientIds: [beef.id], orderIndex: 0),
                RecipeStep(instruction: "Brown the beef in a Dutch oven.", ingredientIds: [beef.id], orderIndex: 1),
                RecipeStep(instruction: "Add vegetables and broth, simmer for 2 hours.", ingredientIds: [potatoes.id, carrots.id], orderIndex: 2)
            ],
            servings: 6,
            prepTimeMinutes: 20,
            cookTimeMinutes: 90,
            tags: ["dinner", "comfort food", "beef"],
            authorUsername: "johndoe"
        ))
    }
}
