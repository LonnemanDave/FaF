import SwiftUI
import PhotosUI

struct CreateRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var userService = UserService.shared

    // Edit mode
    var recipeToEdit: Recipe?
    var isEditing: Bool { recipeToEdit != nil }

    // Basic Info
    @State private var title = ""
    @State private var description = ""
    @State private var servings = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var tags = ""
    @State private var isPublic = false

    // Master Ingredients
    @State private var ingredients: [Ingredient] = []
    @State private var newIngredientName = ""
    @State private var newIngredientQuantity = ""
    @State private var newIngredientUnit = ""

    // Steps
    @State private var steps: [RecipeStep] = []

    // UI State
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FAFSpacing.xl) {
                    basicInfoSection
                    Divider()
                    ingredientsSection
                    Divider()
                    stepsSection
                    Divider()
                    visibilitySection

                    FAFButton(
                        title: "Save Recipe",
                        style: .accent,
                        isLoading: isLoading
                    ) {
                        Task { await saveRecipe() }
                    }
                    .disabled(!isFormValid)
                    .padding(.top, FAFSpacing.md)
                }
                .padding(FAFSpacing.lg)
            }
            .background(Color.fafWhite)
            .navigationTitle(isEditing ? "Edit Recipe" : "New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.fafCoral)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let recipe = recipeToEdit {
                    populateFields(from: recipe)
                }
            }
        }
    }

    private func populateFields(from recipe: Recipe) {
        title = recipe.title
        description = recipe.description
        servings = recipe.servings.map { String($0) } ?? ""
        prepTime = recipe.prepTimeMinutes.map { String($0) } ?? ""
        cookTime = recipe.cookTimeMinutes.map { String($0) } ?? ""
        tags = recipe.tags.joined(separator: ", ")
        isPublic = recipe.isPublic
        ingredients = recipe.ingredients
        steps = recipe.sortedSteps
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionHeader(title: "Basic Info", systemIcon: "info.circle")

            FormField(label: "Title", placeholder: "Recipe name", text: $title)

            VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                Text("Description")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
                TextEditor(text: $description)
                    .font(FAFTypography.body)
                    .frame(minHeight: 80)
                    .padding(FAFSpacing.sm)
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: FAFRadius.md)
                            .stroke(Color.fafGrayXLight, lineWidth: 1)
                    )
            }

            HStack(spacing: FAFSpacing.md) {
                FormField(label: "Servings", placeholder: "4", text: $servings, keyboardType: .numberPad)
                FormField(label: "Prep (min)", placeholder: "15", text: $prepTime, keyboardType: .numberPad)
                FormField(label: "Cook (min)", placeholder: "30", text: $cookTime, keyboardType: .numberPad)
            }

            FormField(label: "Tags", placeholder: "dinner, easy, healthy", text: $tags)
            Text("Separate with commas")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGrayLight)
        }
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionHeader(title: "Ingredients", systemIcon: "list.bullet")

            HStack(spacing: FAFSpacing.sm) {
                TextField("Qty", text: $newIngredientQuantity)
                    .font(FAFTypography.body)
                    .frame(width: 50)
                    .padding(FAFSpacing.sm)
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.sm)
                    .keyboardType(.decimalPad)

                TextField("Unit", text: $newIngredientUnit)
                    .font(FAFTypography.body)
                    .frame(width: 60)
                    .padding(FAFSpacing.sm)
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.sm)

                TextField("Ingredient", text: $newIngredientName)
                    .font(FAFTypography.body)
                    .padding(FAFSpacing.sm)
                    .background(Color.fafOffWhite)
                    .cornerRadius(FAFRadius.sm)

                Button {
                    addIngredient()
                } label: {
                    FAFIcon(.plus, size: 20, color: newIngredientName.isEmpty || newIngredientQuantity.isEmpty ? .fafGrayLight : .fafCoral)
                }
                .disabled(newIngredientName.isEmpty || newIngredientQuantity.isEmpty)
            }

            if !ingredients.isEmpty {
                VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                    ForEach(ingredients) { ingredient in
                        HStack {
                            Circle()
                                .fill(Color.fafCoral)
                                .frame(width: 6, height: 6)

                            Text(ingredient.displayString)
                                .font(FAFTypography.body)
                                .foregroundColor(.fafBlack)

                            Spacer()

                            Button {
                                removeIngredient(ingredient)
                            } label: {
                                FAFIcon(.close, size: 16, color: .fafGray)
                            }
                        }
                        .padding(.vertical, FAFSpacing.xxs)
                    }
                }
            }
        }
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionHeader(title: "Steps", systemIcon: "list.number")

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                StepEditorCard(
                    stepNumber: index + 1,
                    step: $steps[index],
                    availableIngredients: ingredients,
                    onDelete: { removeStep(at: index) },
                    onMoveUp: index > 0 ? { moveStep(from: index, to: index - 1) } : nil,
                    onMoveDown: index < steps.count - 1 ? { moveStep(from: index, to: index + 1) } : nil
                )
            }

            Button {
                addStep()
            } label: {
                HStack {
                    FAFIcon(.plus, size: 18, color: .fafCoral)
                    Text("Add Step")
                        .font(FAFTypography.button)
                        .foregroundColor(.fafCoral)
                }
                .frame(maxWidth: .infinity)
                .padding(FAFSpacing.md)
                .background(Color.fafCoral.opacity(0.1))
                .cornerRadius(FAFRadius.md)
            }
        }
    }

    private func moveStep(from source: Int, to destination: Int) {
        steps.swapAt(source, destination)
        // Update order indices
        for i in steps.indices {
            steps[i].orderIndex = i
        }
    }

    // MARK: - Visibility Section

    private var visibilitySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: FAFSpacing.xxs) {
                Text("Make Public")
                    .font(FAFTypography.bodyBold)
                    .foregroundColor(.fafBlack)
                Text("Share with the community")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
            Spacer()
            Toggle("", isOn: $isPublic)
                .tint(.fafCoral)
        }
        .padding(FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }

    // MARK: - Helper Methods

    private var isFormValid: Bool {
        !title.isEmpty && !steps.isEmpty && steps.allSatisfy { !$0.instruction.isEmpty }
    }

    private func addIngredient() {
        let ingredient = Ingredient(
            name: newIngredientName,
            quantity: newIngredientQuantity,
            unit: newIngredientUnit.isEmpty ? nil : newIngredientUnit
        )
        ingredients.append(ingredient)
        newIngredientName = ""
        newIngredientQuantity = ""
        newIngredientUnit = ""
    }

    private func removeIngredient(_ ingredient: Ingredient) {
        ingredients.removeAll { $0.id == ingredient.id }
        for i in steps.indices {
            steps[i].ingredientIds.removeAll { $0 == ingredient.id }
        }
    }

    private func addStep() {
        let newStep = RecipeStep(
            instruction: "",
            ingredientIds: [],
            orderIndex: steps.count
        )
        steps.append(newStep)
    }

    private func removeStep(at index: Int) {
        steps.remove(at: index)
        for i in steps.indices {
            steps[i].orderIndex = i
        }
    }

    private func saveRecipe() async {
        guard let user = userService.currentUser else { return }

        isLoading = true
        defer { isLoading = false }

        let parsedTags = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        do {
            if isEditing, let existingRecipe = recipeToEdit {
                // Update existing recipe
                var updatedRecipe = existingRecipe
                updatedRecipe.title = title
                updatedRecipe.description = description
                updatedRecipe.ingredients = ingredients
                updatedRecipe.steps = steps
                updatedRecipe.isPublic = isPublic
                updatedRecipe.servings = Int(servings)
                updatedRecipe.prepTimeMinutes = Int(prepTime)
                updatedRecipe.cookTimeMinutes = Int(cookTime)
                updatedRecipe.tags = parsedTags

                try await recipeService.updateRecipe(updatedRecipe)
            } else {
                // Create new recipe
                let recipe = Recipe(
                    authorId: user.id ?? "",
                    title: title,
                    description: description,
                    ingredients: ingredients,
                    steps: steps,
                    isPublic: isPublic,
                    imageURLs: [],
                    servings: Int(servings),
                    prepTimeMinutes: Int(prepTime),
                    cookTimeMinutes: Int(cookTime),
                    tags: parsedTags,
                    authorUsername: user.username,
                    authorProfileImageURL: user.profileImageURL
                )
                _ = try await recipeService.createRecipe(recipe, author: user)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let systemIcon: String

    var body: some View {
        HStack(spacing: FAFSpacing.sm) {
            Image(systemName: systemIcon)
                .font(.system(size: 18))
                .foregroundColor(.fafCoral)
            Text(title)
                .font(FAFTypography.h3)
                .foregroundColor(.fafBlack)
        }
    }
}

// MARK: - Form Field

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.xs) {
            Text(label)
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)
            TextField(placeholder, text: $text)
                .font(FAFTypography.body)
                .keyboardType(keyboardType)
                .padding(FAFSpacing.md)
                .background(Color.fafOffWhite)
                .cornerRadius(FAFRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.md)
                        .stroke(Color.fafGrayXLight, lineWidth: 1)
                )
        }
    }
}

// MARK: - Step Editor Card

struct StepEditorCard: View {
    let stepNumber: Int
    @Binding var step: RecipeStep
    let availableIngredients: [Ingredient]
    let onDelete: () -> Void
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    @State private var showIngredientPicker = false

    private var selectedIngredients: [Ingredient] {
        availableIngredients.filter { step.ingredientIds.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            HStack {
                Text("\(stepNumber)")
                    .font(FAFTypography.h3)
                    .foregroundColor(.fafWhite)
                    .frame(width: 28, height: 28)
                    .background(Color.fafCoral)
                    .clipShape(Circle())

                Spacer()

                // Reorder buttons
                HStack(spacing: FAFSpacing.xs) {
                    if let moveUp = onMoveUp {
                        Button { moveUp() } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.fafGray)
                                .frame(width: 32, height: 32)
                                .background(Color.fafGrayXLight)
                                .clipShape(Circle())
                        }
                    }

                    if let moveDown = onMoveDown {
                        Button { moveDown() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.fafGray)
                                .frame(width: 32, height: 32)
                                .background(Color.fafGrayXLight)
                                .clipShape(Circle())
                        }
                    }
                }

                Button { onDelete() } label: {
                    FAFIcon(.close, size: 18, color: .fafGray)
                }
            }

            TextEditor(text: $step.instruction)
                .font(FAFTypography.body)
                .frame(minHeight: 60)
                .padding(FAFSpacing.sm)
                .background(Color.fafWhite)
                .cornerRadius(FAFRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.sm)
                        .stroke(Color.fafGrayXLight, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: FAFSpacing.xs) {
                if !availableIngredients.isEmpty {
                    Button {
                        showIngredientPicker.toggle()
                    } label: {
                        HStack {
                            FAFIcon(.plus, size: 14, color: .fafSage)
                            Text(showIngredientPicker ? "Done adding" : "Add ingredients to this step")
                                .font(FAFTypography.caption)
                                .foregroundColor(.fafSage)
                        }
                    }
                }

                if !selectedIngredients.isEmpty {
                    FlowLayout(spacing: FAFSpacing.xs) {
                        ForEach(selectedIngredients) { ingredient in
                            IngredientChip(ingredient: ingredient) {
                                step.ingredientIds.removeAll { $0 == ingredient.id }
                            }
                        }
                    }
                }

                if showIngredientPicker {
                    ingredientPickerView
                }
            }
        }
        .padding(FAFSpacing.md)
        .background(Color.fafOffWhite)
        .cornerRadius(FAFRadius.md)
    }

    private var ingredientPickerView: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.xs) {
            Text("Select ingredients:")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)

            ForEach(availableIngredients) { ingredient in
                let isSelected = step.ingredientIds.contains(ingredient.id)
                Button {
                    if isSelected {
                        step.ingredientIds.removeAll { $0 == ingredient.id }
                    } else {
                        step.ingredientIds.append(ingredient.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .fafCoral : .fafGray)
                        Text(ingredient.displayString)
                            .font(FAFTypography.body)
                            .foregroundColor(.fafBlack)
                        Spacer()
                    }
                    .padding(.vertical, FAFSpacing.xxs)
                }
            }
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafWhite)
        .cornerRadius(FAFRadius.sm)
    }
}

// MARK: - Ingredient Chip

struct IngredientChip: View {
    let ingredient: Ingredient
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: FAFSpacing.xxs) {
            Text(ingredient.displayString)
                .font(FAFTypography.caption)
                .foregroundColor(.fafBlack)
            Button { onRemove() } label: {
                FAFIcon(.close, size: 12, color: .fafGray)
            }
        }
        .padding(.horizontal, FAFSpacing.sm)
        .padding(.vertical, FAFSpacing.xxs)
        .background(Color.fafSage.opacity(0.2))
        .cornerRadius(FAFRadius.full)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    CreateRecipeView()
}
