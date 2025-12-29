import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var userService = UserService.shared

    let recipe: Recipe

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    private var isOwner: Bool {
        userService.currentUser?.id == recipe.authorId
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
                }
                .padding(FAFSpacing.lg)
            }
        }
        .background(Color.fafWhite)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        FAFIcon(.menu, size: 20, color: .fafBlack)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            CreateRecipeView(recipeToEdit: recipe)
        }
        .confirmationDialog("Delete Recipe", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deleteRecipe() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(recipe.title)\"? This cannot be undone.")
        }
    }

    private func deleteRecipe() async {
        isDeleting = true
        do {
            try await recipeService.deleteRecipe(recipe)
            dismiss()
        } catch {
            print("Error deleting recipe: \(error)")
        }
        isDeleting = false
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
                ForEach(recipe.ingredients) { ingredient in
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
                if !recipe.steps.isEmpty {
                    // New format with per-step ingredients
                    ForEach(Array(recipe.sortedSteps.enumerated()), id: \.element.id) { index, step in
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
                            let stepIngredients = recipe.ingredients(for: step)
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
