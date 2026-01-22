import SwiftUI
import PhotosUI

struct CreateRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var recipeService = RecipeService.shared
    @ObservedObject var userService = UserService.shared

    // Edit mode
    var recipeToEdit: Recipe?
    var onDelete: (() -> Void)?
    var isEditing: Bool { recipeToEdit != nil && recipeToEdit?.id != nil }

    // AI Draft mode - pre-populated but creates new recipe
    var aiDraftRecipe: Recipe?
    var isAIDraft: Bool { aiDraftRecipe != nil }

    // Variation mode
    var baseRecipeForVariation: Recipe?
    var variationToEdit: RecipeVariation?
    var onVariationUpdated: (() -> Void)?
    var isVariationMode: Bool { baseRecipeForVariation != nil }
    var isEditingVariation: Bool { variationToEdit != nil }

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
    @State private var editingIngredientId: String?

    // Steps
    @State private var steps: [RecipeStep] = []

    // Variation
    @State private var variationNotes = ""

    // UI State
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showDuplicatePrompt = false
    @State private var duplicateRecipe: Recipe?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FAFSpacing.xl) {
                    // Close button
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.fafGray)
                                .padding(FAFSpacing.sm)
                                .background(Color.fafGrayXLight)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }

                    // Variation header
                    if effectiveVariationMode, let baseRecipe = effectiveBaseRecipe {
                        variationHeader(for: baseRecipe)
                    }

                    if !effectiveVariationMode {
                        basicInfoSection
                        Divider()
                    }

                    ingredientsSection
                    Divider()
                    stepsSection

                    if effectiveVariationMode {
                        Divider()
                        notesSection
                    } else {
                        Divider()
                        visibilitySection
                    }

                    if isEditing {
                        Divider()
                        deleteSection
                    }

                    FAFButton(
                        title: effectiveVariationMode ? "Save Variation" : "Save Recipe",
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fafBackground.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Recipe", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deleteRecipe() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this recipe? This cannot be undone.")
            }
            .confirmationDialog("Recipe Exists", isPresented: $showDuplicatePrompt, titleVisibility: .visible) {
                Button("Add My Variation") {
                    if let existingRecipe = duplicateRecipe {
                        // Switch to variation mode
                        switchToVariationMode(for: existingRecipe)
                    }
                }
                Button("Change Title", role: .cancel) {}
            } message: {
                if let existingRecipe = duplicateRecipe {
                    Text("\"\(existingRecipe.title)\" already exists. Would you like to add your variation instead?")
                }
            }
            .onAppear {
                if let recipe = recipeToEdit {
                    populateFields(from: recipe)
                } else if let draft = aiDraftRecipe {
                    populateFields(from: draft)
                } else if let variation = variationToEdit {
                    populateFieldsFromVariation(variation)
                } else if let baseRecipe = baseRecipeForVariation {
                    populateFieldsForVariation(from: baseRecipe)
                }
            }
        }
    }

    private var navigationTitle: String {
        if isEditingVariation {
            return "Edit Variation"
        } else if effectiveVariationMode {
            return "Your Variation"
        } else if isEditing {
            return "Edit Recipe"
        } else if isAIDraft {
            return "AI Generated Recipe"
        } else {
            return "New Recipe"
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

    private func populateFieldsForVariation(from recipe: Recipe) {
        // Copy the base recipe's ingredients and steps as starting point
        ingredients = recipe.ingredients
        steps = recipe.sortedSteps
    }

    private func populateFieldsFromVariation(_ variation: RecipeVariation) {
        // Populate from an existing variation for editing
        ingredients = variation.ingredients
        steps = variation.sortedSteps
        variationNotes = variation.notes
    }

    @State private var internalVariationMode = false
    @State private var internalBaseRecipe: Recipe?

    private var effectiveBaseRecipe: Recipe? {
        baseRecipeForVariation ?? internalBaseRecipe
    }

    private var effectiveVariationMode: Bool {
        isVariationMode || internalVariationMode || isEditingVariation
    }

    private func switchToVariationMode(for recipe: Recipe) {
        internalBaseRecipe = recipe
        internalVariationMode = true
        populateFieldsForVariation(from: recipe)
    }

    // MARK: - Variation Header

    private func variationHeader(for recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: FAFSpacing.sm) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.fafCoral)
                Text("Your Variation of:")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
            Text(recipe.title)
                .font(FAFTypography.h2)
                .foregroundColor(.fafTextPrimary)
            if let author = recipe.authorUsername {
                Text("Original by @\(author)")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FAFSpacing.md)
        .background(Color.fafCoral.opacity(0.1))
        .cornerRadius(FAFRadius.md)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionHeader(title: "Chef's Notes", systemIcon: "note.text")

            Text("Describe what makes your variation different")
                .font(FAFTypography.caption)
                .foregroundColor(.fafGray)

            TextEditor(text: $variationNotes)
                .font(FAFTypography.body)
                .frame(minHeight: 100)
                .padding(FAFSpacing.sm)
                .background(Color.fafInputBackground)
                .cornerRadius(FAFRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.md)
                        .stroke(Color.fafDivider, lineWidth: 1)
                )
        }
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
                    .background(Color.fafInputBackground)
                    .cornerRadius(FAFRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: FAFRadius.md)
                            .stroke(Color.fafDivider, lineWidth: 1)
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

    private var isEditingIngredient: Bool {
        editingIngredientId != nil
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: FAFSpacing.md) {
            SectionHeader(title: "Ingredients", systemIcon: "list.bullet")

            HStack(spacing: FAFSpacing.sm) {
                TextField("Qty", text: $newIngredientQuantity)
                    .font(FAFTypography.body)
                    .frame(width: 50)
                    .padding(FAFSpacing.sm)
                    .background(isEditingIngredient ? Color.fafCoral.opacity(0.1) : Color.fafInputBackground)
                    .cornerRadius(FAFRadius.sm)
                    .keyboardType(.decimalPad)

                TextField("Unit", text: $newIngredientUnit)
                    .font(FAFTypography.body)
                    .frame(width: 60)
                    .padding(FAFSpacing.sm)
                    .background(isEditingIngredient ? Color.fafCoral.opacity(0.1) : Color.fafInputBackground)
                    .cornerRadius(FAFRadius.sm)

                TextField("Ingredient", text: $newIngredientName)
                    .font(FAFTypography.body)
                    .padding(FAFSpacing.sm)
                    .background(isEditingIngredient ? Color.fafCoral.opacity(0.1) : Color.fafInputBackground)
                    .cornerRadius(FAFRadius.sm)

                if isEditingIngredient {
                    Button {
                        cancelEditingIngredient()
                    } label: {
                        FAFIcon(.close, size: 20, color: .fafGray)
                    }
                }

                Button {
                    if isEditingIngredient {
                        saveEditedIngredient()
                    } else {
                        addIngredient()
                    }
                } label: {
                    Image(systemName: isEditingIngredient ? "checkmark" : "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(newIngredientName.isEmpty || newIngredientQuantity.isEmpty ? .fafGrayLight : .fafCoral)
                }
                .disabled(newIngredientName.isEmpty || newIngredientQuantity.isEmpty)
            }

            if !ingredients.isEmpty {
                VStack(alignment: .leading, spacing: FAFSpacing.sm) {
                    ForEach(ingredients) { ingredient in
                        Button {
                            startEditingIngredient(ingredient)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(editingIngredientId == ingredient.id ? Color.fafSage : Color.fafCoral)
                                    .frame(width: 6, height: 6)

                                Text(ingredient.displayString)
                                    .font(FAFTypography.body)
                                    .foregroundColor(editingIngredientId == ingredient.id ? .fafGray : .fafTextPrimary)

                                Spacer()

                                if editingIngredientId == ingredient.id {
                                    Text("editing")
                                        .font(FAFTypography.caption)
                                        .foregroundColor(.fafSage)
                                } else {
                                    FAFIcon(.close, size: 16, color: .fafGray)
                                        .onTapGesture {
                                            removeIngredient(ingredient)
                                        }
                                }
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
                    .foregroundColor(.fafTextPrimary)
                Text("Share with the community")
                    .font(FAFTypography.caption)
                    .foregroundColor(.fafGray)
            }
            Spacer()
            Toggle("", isOn: $isPublic)
                .tint(.fafCoral)
        }
        .padding(FAFSpacing.md)
        .background(Color.fafCardBackground)
        .cornerRadius(FAFRadius.md)
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                Text("Delete Recipe")
                    .font(FAFTypography.button)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(FAFSpacing.md)
            .background(Color.red.opacity(0.1))
            .cornerRadius(FAFRadius.md)
        }
    }

    // MARK: - Helper Methods

    private var isFormValid: Bool {
        if effectiveVariationMode {
            // Variation mode: just need steps
            return !steps.isEmpty && steps.allSatisfy { !$0.instruction.isEmpty }
        } else {
            // Normal mode: need title and steps
            return !title.isEmpty && !steps.isEmpty && steps.allSatisfy { !$0.instruction.isEmpty }
        }
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

    private func startEditingIngredient(_ ingredient: Ingredient) {
        editingIngredientId = ingredient.id
        newIngredientName = ingredient.name
        newIngredientQuantity = ingredient.quantity
        newIngredientUnit = ingredient.unit ?? ""
    }

    private func saveEditedIngredient() {
        guard let editingId = editingIngredientId,
              let index = ingredients.firstIndex(where: { $0.id == editingId }) else { return }

        // Keep the same ID so step references remain valid
        ingredients[index].name = newIngredientName
        ingredients[index].quantity = newIngredientQuantity
        ingredients[index].unit = newIngredientUnit.isEmpty ? nil : newIngredientUnit

        cancelEditingIngredient()
    }

    private func cancelEditingIngredient() {
        editingIngredientId = nil
        newIngredientName = ""
        newIngredientQuantity = ""
        newIngredientUnit = ""
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

        do {
            // Handle editing existing variation
            if isEditingVariation, let existingVariation = variationToEdit, let recipeId = existingVariation.recipeId as String? {
                var updatedVariation = existingVariation
                updatedVariation.ingredients = ingredients
                updatedVariation.steps = steps
                updatedVariation.notes = variationNotes
                try await recipeService.updateVariation(updatedVariation, recipeId: recipeId)
                onVariationUpdated?()
                dismiss()
                return
            }

            // Handle creating new variation
            if effectiveVariationMode, let baseRecipe = effectiveBaseRecipe, let recipeId = baseRecipe.id {
                let variation = RecipeVariation(
                    recipeId: recipeId,
                    authorId: user.id ?? "",
                    ingredients: ingredients,
                    steps: steps,
                    notes: variationNotes,
                    authorUsername: user.username,
                    authorProfileImageURL: user.profileImageURL
                )
                try await recipeService.createVariation(for: recipeId, variation: variation, author: user)
                dismiss()
                return
            }

            let parsedTags = tags.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }

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
                // Check for duplicate before creating
                if let existingRecipe = try await recipeService.recipeExists(title: title) {
                    duplicateRecipe = existingRecipe
                    showDuplicatePrompt = true
                    return
                }

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

    private func deleteRecipe() async {
        guard let recipe = recipeToEdit else { return }

        isLoading = true
        do {
            try await recipeService.deleteRecipe(recipe)
            dismiss()
            onDelete?()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
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
                .foregroundColor(.fafTextPrimary)
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
                .background(Color.fafInputBackground)
                .cornerRadius(FAFRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.md)
                        .stroke(Color.fafDivider, lineWidth: 1)
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
                .background(Color.fafBackground)
                .cornerRadius(FAFRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: FAFRadius.sm)
                        .stroke(Color.fafDivider, lineWidth: 1)
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
        .background(Color.fafCardBackground)
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
                            .foregroundColor(.fafTextPrimary)
                        Spacer()
                    }
                    .padding(.vertical, FAFSpacing.xxs)
                }
            }
        }
        .padding(FAFSpacing.sm)
        .background(Color.fafBackgroundTertiary)
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
                .foregroundColor(.fafTextPrimary)
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
