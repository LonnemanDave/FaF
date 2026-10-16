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
                VStack(alignment: .leading, spacing: Theme.spacingXL) {
                    PlateHeader(title: navigationTitle, subtitle: byline)

                    // Variation header
                    if effectiveVariationMode, let baseRecipe = effectiveBaseRecipe {
                        variationHeader(for: baseRecipe)
                    }

                    if !effectiveVariationMode {
                        basicInfoSection
                    }

                    ingredientsSection

                    stepsSection

                    if effectiveVariationMode {
                        notesSection
                    } else {
                        visibilitySection
                    }

                    VStack(spacing: Theme.spacingMD) {
                        Button {
                            Task { await saveRecipe() }
                        } label: {
                            if isLoading {
                                ProgressView().tint(Theme.paper)
                            } else {
                                Text(effectiveVariationMode ? "Save your version" : "Save the recipe")
                            }
                        }
                        .buttonStyle(.press)
                        .disabled(!isFormValid || isLoading)

                        if !isFormValid {
                            Text(effectiveVariationMode
                                 ? "Write at least one step to save."
                                 : "A title and at least one step, and it can be saved.")
                                .font(.setting(12).italic())
                                .foregroundColor(Theme.ink3)
                        }

                        if isEditing {
                            deleteSection
                                .padding(.top, Theme.spacingSM)
                        }
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
                ToolbarItem(placement: .topBarTrailing) {
                    MarginButton("Save") { Task { await saveRecipe() } }
                        .disabled(!isFormValid || isLoading)
                        .opacity(isFormValid ? 1 : 0.35)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete this recipe?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deleteRecipe() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It's taken out of your box for good. This can't be undone.")
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

    /// Under the title: whose hand it's written in.
    private var byline: String {
        guard let username = userService.currentUser?.username else { return "In your journal" }
        return "In the hand of @\(username)"
    }

    private var navigationTitle: String {
        if isEditingVariation {
            return "Your version"
        } else if effectiveVariationMode {
            return "Your version"
        } else if isEditing {
            return "Editing"
        } else if isAIDraft {
            return "From the AI"
        } else {
            return "A new recipe"
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Your take on".uppercased())
                .smallCaps(10, weight: .semibold, tracking: 1.4)
                .foregroundColor(Theme.ink2)
            Text(recipe.title)
                .font(.plate(22))
                .foregroundColor(Theme.ink)
            if let author = recipe.authorUsername {
                Text("From the kitchen of @\(author)")
                    .font(.setting(13).italic())
                    .foregroundColor(Theme.ink3)
            }
        }
        .padding(.leading, Theme.spacingMD)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.herb).frame(width: 2)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Your note")
            FieldLine(
                label: "What you changed",
                text: $variationNotes,
                prompt: "More garlic, a splash of vinegar at the end…",
                multiline: true
            )
        }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            FieldLine(label: "Title", text: $title, prompt: "What it's called")
            FieldLine(label: "A line about it", text: $description, prompt: "Why you make it, what it's like", multiline: true)

            HStack(alignment: .top, spacing: Theme.spacingLG) {
                FieldLine(label: "Serves", text: $servings, prompt: "4")
                    .keyboardType(.numberPad)
                FieldLine(label: "Prep", text: $prepTime, prompt: "15", note: "min")
                    .keyboardType(.numberPad)
                FieldLine(label: "Cook", text: $cookTime, prompt: "30", note: "min")
                    .keyboardType(.numberPad)
            }

            FieldLine(label: "Tags", text: $tags, prompt: "dinner, stew, make-ahead", note: "commas between")
                .textInputAutocapitalization(.never)
        }
    }

    // MARK: - Ingredients Section

    private var isEditingIngredient: Bool {
        editingIngredientId != nil
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Ingredients", figure: ingredients.isEmpty ? nil : "\(ingredients.count)")

            // What's written so far — tap one to change it.
            ForEach(ingredients) { ingredient in
                let editing = editingIngredientId == ingredient.id
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
                    Button {
                        startEditingIngredient(ingredient)
                    } label: {
                        IngredientLine(ingredient, struck: false)
                            .opacity(editing ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)

                    if editing {
                        Text("Editing".uppercased())
                            .smallCaps(9, weight: .semibold, tracking: 1.2)
                            .foregroundColor(Theme.herb)
                    } else {
                        Button {
                            removeIngredient(ingredient)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.ink3)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(ingredient.name)")
                    }
                }
            }

            // The line to write the next one on.
            HStack(alignment: .bottom, spacing: Theme.spacingMD) {
                FieldLine(label: "Amount", text: $newIngredientQuantity, prompt: "2")
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 64)
                FieldLine(label: "Unit", text: $newIngredientUnit, prompt: "cups")
                    .textInputAutocapitalization(.never)
                    .frame(width: 72)
                FieldLine(label: "Ingredient", text: $newIngredientName, prompt: "onions, chopped")
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit {
                        guard !newIngredientName.isEmpty, !newIngredientQuantity.isEmpty else { return }
                        isEditingIngredient ? saveEditedIngredient() : addIngredient()
                    }
            }
            .padding(.top, ingredients.isEmpty ? 0 : Theme.spacingSM)

            HStack {
                if isEditingIngredient {
                    MarginButton("Cancel") { cancelEditingIngredient() }
                }
                Spacer()
                MarginButton(isEditingIngredient ? "Save ingredient" : "Add ingredient") {
                    isEditingIngredient ? saveEditedIngredient() : addIngredient()
                }
                .disabled(newIngredientName.isEmpty || newIngredientQuantity.isEmpty)
                .opacity(newIngredientName.isEmpty || newIngredientQuantity.isEmpty ? 0.35 : 1)
            }
        }
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            SectionHead(title: "Method", figure: steps.isEmpty ? nil : "\(steps.count) \(steps.count == 1 ? "step" : "steps")")

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                StepEditorCard(
                    stepNumber: index + 1,
                    step: $steps[index],
                    availableIngredients: ingredients,
                    onDelete: { removeStep(at: index) },
                    onMoveUp: index > 0 ? { moveStep(from: index, to: index - 1) } : nil,
                    onMoveDown: index < steps.count - 1 ? { moveStep(from: index, to: index + 1) } : nil
                )
                if index < steps.count - 1 {
                    DashedDivider()
                }
            }

            Button(steps.isEmpty ? "Write the first step" : "Add a step") {
                addStep()
            }
            .buttonStyle(.pressOutline)
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
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SectionHead(title: "Who sees it")
            IndexSelector(
                options: [(value: false, label: "Friends"), (value: true, label: "Everyone")],
                selection: $isPublic
            )
            Text(isPublic
                 ? "Anyone using Food & Friends can find it under Everyone."
                 : "Only your friends see it, at their table and in their recipes.")
                .font(.setting(12).italic())
                .foregroundColor(Theme.ink3)
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        MarginButton("Delete this recipe", destructive: true) {
            showDeleteConfirmation = true
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

// MARK: - Step Editor

/// One step of the method being written: the serif numeral in the margin,
/// a line to write on, and the ingredients this step uses — ticked from the
/// ones written above.
struct StepEditorCard: View {
    let stepNumber: Int
    @Binding var step: RecipeStep
    let availableIngredients: [Ingredient]
    let onDelete: () -> Void
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    @State private var showIngredientPicker = false
    @FocusState private var writing: Bool

    private var selectedIngredients: [Ingredient] {
        availableIngredients.filter { step.ingredientIds.contains($0.id) }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacingMD) {
            Text("\(stepNumber)")
                .font(.plate(22))
                .foregroundColor(Theme.accent)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                TextField(
                    text: $step.instruction,
                    prompt: Text("What to do").foregroundColor(Theme.ink3),
                    axis: .vertical
                ) { Text("Step \(stepNumber)") }
                    .font(.setting(16))
                    .foregroundColor(Theme.ink)
                    .tint(Theme.accent)
                    .lineLimit(2...10)
                    .focused($writing)

                Rule(weight: writing ? 1.5 : 1, color: writing ? Theme.ink : Theme.rule)

                if !selectedIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(selectedIngredients) { ingredient in
                            IngredientLine(ingredient, compact: true)
                        }
                    }
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.rule).frame(width: 1)
                    }
                }

                if showIngredientPicker {
                    FlowLayout(spacing: 6) {
                        ForEach(availableIngredients) { ingredient in
                            let chosen = step.ingredientIds.contains(ingredient.id)
                            Button {
                                if chosen {
                                    step.ingredientIds.removeAll { $0 == ingredient.id }
                                } else {
                                    step.ingredientIds.append(ingredient.id)
                                }
                            } label: {
                                Text(ShoppingMath.shoppingName(ingredient.name))
                                    .font(.setting(13))
                                    .foregroundColor(chosen ? Theme.paper : Theme.ink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(chosen ? Theme.ink : Color.clear)
                                    .overlay(Rectangle().stroke(chosen ? Theme.ink : Theme.rule, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // The step's own marks: what it uses, and where it goes.
                HStack(spacing: Theme.spacingMD) {
                    if !availableIngredients.isEmpty {
                        MarginButton(showIngredientPicker ? "Done" : "Ingredients") {
                            withAnimation(.easeOut(duration: 0.15)) { showIngredientPicker.toggle() }
                        }
                    }
                    Spacer()
                    if let onMoveUp {
                        MarginButton("Up", action: onMoveUp)
                    }
                    if let onMoveDown {
                        MarginButton("Down", action: onMoveDown)
                    }
                    MarginButton("Remove", action: onDelete)
                }
            }
        }
        .padding(.vertical, Theme.spacingSM)
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
